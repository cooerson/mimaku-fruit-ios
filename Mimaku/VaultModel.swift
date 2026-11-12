import Foundation
import Security

enum Keychain {
    private static let service = "org.mimaku.fruit"
    private static let account = "token"

    static func save(_ token: String) {
        clear()
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class VaultModel: ObservableObject {
    @Published var token: String?
    @Published var entries: [Entry] = []
    @Published var busy = false
    @Published var banner: String?
    @Published var loginError: String?
    @Published var loadError: String?
    @Published var accountIsNew = false
    @Published var loadingList = false

    private let store = Store()
    private var requestGeneration = 0

    init() {
        do {
            try store.open()
        } catch {
            loginError = error.localizedDescription
            return
        }
        if let saved = Keychain.load(), store.userExists(saved) {
            token = saved
            loadingList = true
            Task { await refresh(silent: true) }
        } else {
            Keychain.clear()
        }
    }

    func login(password: String) async {
        let generation = nextGeneration()
        loginError = nil
        loadingList = true
        await run(generation: generation) {
            let store = self.store
            let result = try await Task.detached {
                try store.login(password: password)
            }.value
            guard generation == self.requestGeneration else { return }
            let list = try store.entries(userID: result.userID)
            guard generation == self.requestGeneration else { return }
            Keychain.save(result.userID)
            self.entries = list
            self.accountIsNew = result.created
            self.loadError = nil
            self.loadingList = false
            self.token = result.userID
            if result.created {
                self.banner = "这组水果密码是新的，果篮只在这台手机上"
            } else {
                self.banner = "已进入果篮，共 \(list.count) 颗"
            }
        }
    }

    func refresh(silent: Bool = false) async {
        let generation = nextGeneration()
        if entries.isEmpty { loadingList = true }
        await run(generation: generation, silent: silent) {
            try await self.loadEntries(generation: generation)
        }
    }

    func createEmpty() async -> Entry? {
        var created: Entry?
        await run {
            guard let userID = self.token else { throw APIError.unauthorized("请先进入果篮") }
            created = try self.store.create(Entry(title: "新条目"), userID: userID)
            if let created {
                var list = self.entries
                list.insert(created, at: 0)
                self.entries = list
            }
            self.banner = "已新建"
        }
        return created
    }

    func save(_ entry: Entry) async -> Bool {
        var ok = false
        await run {
            guard let userID = self.token else { throw APIError.unauthorized("请先进入果篮") }
            let saved = try self.store.update(entry, userID: userID)
            if let index = self.entries.firstIndex(where: { $0.id == saved.id }) {
                var list = self.entries
                list[index] = saved
                self.entries = list
            }
            self.banner = "已放进果篮"
            ok = true
        }
        return ok
    }

    func delete(id: String) async -> Bool {
        var ok = false
        await run {
            guard let userID = self.token else { throw APIError.unauthorized("请先进入果篮") }
            try self.store.delete(id: id, userID: userID)
            self.entries = self.entries.filter { $0.id != id }
            self.banner = "已删除"
            ok = true
        }
        return ok
    }

    func changePassword(old: String, new: String) async -> Bool {
        var ok = false
        await run {
            guard let userID = self.token else { throw APIError.unauthorized("请先进入果篮") }
            let store = self.store
            try await Task.detached {
                try store.changePassword(userID: userID, old: old, new: new)
            }.value
            self.banner = "水果密码已更换"
            ok = true
        }
        return ok
    }

    func importPack(_ data: Data) async {
        await run {
            guard let userID = self.token else { throw APIError.unauthorized("请先进入果篮") }
            let entries = try Self.decodeImport(data)
            let result = try self.store.importEntries(entries, userID: userID)
            try await self.loadEntries(generation: self.requestGeneration)
            if result.skipped > 0 {
                self.banner = "已导入 \(result.imported) 颗，跳过 \(result.skipped) 颗重复"
            } else {
                self.banner = "已导入 \(result.imported) 颗"
            }
        }
    }

    func exportFile() throws -> URL {
        struct Pack: Encodable { var entries: [Entry] }
        let data = try JSONEncoder.pretty.encode(Pack(entries: entries))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vault-v2-backup.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    func lock() {
        requestGeneration += 1
        token = nil
        entries = []
        accountIsNew = false
        loadError = nil
        loadingList = false
        Keychain.clear()
        banner = "已退出"
    }

    private func nextGeneration() -> Int {
        requestGeneration += 1
        return requestGeneration
    }

    private func loadEntries(generation: Int) async throws {
        guard let userID = token else { throw APIError.unauthorized("请先进入果篮") }
        let list = try store.entries(userID: userID)
        guard generation == requestGeneration else { return }
        entries = list
        loadError = nil
        loadingList = false
    }

    private func run(generation: Int? = nil, silent: Bool = false, _ work: () async throws -> Void) async {
        let generation = generation ?? requestGeneration
        busy = true
        defer {
            if generation == requestGeneration {
                busy = false
                loadingList = false
            }
        }
        do {
            try await work()
        } catch let error as APIError {
            guard generation == requestGeneration else { return }
            if case .unauthorized = error {
                lock()
            }
            if token == nil {
                loginError = error.localizedDescription
            } else {
                loadError = error.localizedDescription
            }
            if !silent || !isUnauthorized(error) {
                banner = error.localizedDescription
            }
        } catch {
            guard generation == requestGeneration else { return }
            if token == nil {
                loginError = error.localizedDescription
            } else {
                loadError = error.localizedDescription
            }
            banner = error.localizedDescription
        }
    }

    private func isUnauthorized(_ error: APIError) -> Bool {
        if case .unauthorized = error { return true }
        return false
    }

    private static func decodeImport(_ data: Data) throws -> [Entry] {
        if let pack = try? JSONDecoder().decode(ImportPack.self, from: data) {
            return pack.entries
        }
        if let list = try? JSONDecoder().decode([Entry].self, from: data) {
            return list
        }
        throw APIError.message("这个文件不是水果密码的备份")
    }
}

private struct ImportPack: Decodable { var entries: [Entry] }

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
