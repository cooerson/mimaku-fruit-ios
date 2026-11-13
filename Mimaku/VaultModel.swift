import Foundation
import Security

/// 把当前登录的果篮 id 放进钥匙串，下次打开 App 直接回到果篮里。
enum Keychain {
    private static let service = "org.mimaku.fruit"
    private static let account = "session"

    static func save(_ value: String) {
        clear()
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
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
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
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
    @Published private(set) var userID: String?
    @Published private(set) var entries: [Entry] = []
    @Published private(set) var busy = false
    @Published private(set) var loadingList = false
    @Published var banner: String?
    @Published var loginError: String?
    @Published var loadError: String?
    @Published var query = ""
    @Published var selectedID: String?

    private let store = Store()
    private var generation = 0
    private var bannerTask: Task<Void, Never>?

    var isLocked: Bool { userID == nil }

    var filteredEntries: [Entry] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return entries }
        return entries.filter {
            ($0.title + " " + $0.username + " " + $0.url).lowercased().contains(keyword)
        }
    }

    init() {
        do {
            try store.open()
        } catch {
            loadError = error.localizedDescription
        }
        Task { await restoreSession() }
    }

    // MARK: - 登录与退出

    func login(password: String) async {
        loginError = nil
        busy = true
        defer { busy = false }
        do {
            let result = try await offload { try $0.login(password: password) }
            userID = result.userID
            Keychain.save(result.userID)
            selectedID = nil
            query = ""
            await loadEntries()
            showBanner(result.created ? "已注册并进入果篮" : "已登录")
        } catch {
            loginError = error.localizedDescription
        }
    }

    func lock(silent: Bool = false) {
        Keychain.clear()
        userID = nil
        entries = []
        selectedID = nil
        query = ""
        loadError = nil
        if !silent { showBanner("已退出") }
    }

    private func restoreSession() async {
        guard loadError == nil, let saved = Keychain.load() else { return }
        let exists = (try? await offload { $0.userExists(id: saved) }) ?? false
        guard exists else {
            Keychain.clear()
            return
        }
        userID = saved
        await loadEntries()
    }

    // MARK: - 条目

    func reload() async {
        await loadEntries()
    }

    @discardableResult
    func createEmpty() async -> Entry? {
        guard let userID else { return nil }
        do {
            let created = try await offload {
                try $0.create(Entry(title: "新条目"), userID: userID)
            }
            entries.insert(created, at: 0)
            selectedID = created.id
            showBanner("已新建")
            return created
        } catch {
            showBanner(error.localizedDescription)
            return nil
        }
    }

    @discardableResult
    func save(_ entry: Entry) async -> Bool {
        guard let userID, !entry.id.isEmpty else { return false }
        do {
            let saved = try await offload {
                try $0.update(id: entry.id, userID: userID, with: entry)
            }
            if let index = entries.firstIndex(where: { $0.id == saved.id }) {
                entries[index] = saved
            }
            showBanner("已保存")
            return true
        } catch {
            showBanner(error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func delete(id: String) async -> Bool {
        guard let userID else { return false }
        do {
            try await offload { try $0.delete(id: id, userID: userID) }
            entries.removeAll { $0.id == id }
            if selectedID == id { selectedID = entries.first?.id }
            showBanner("已删除")
            return true
        } catch {
            showBanner(error.localizedDescription)
            return false
        }
    }

    func changePassword(old: String, new: String) async -> String? {
        guard let userID else { return "请先登录" }
        do {
            try await offload {
                try $0.changePassword(userID: userID, old: old, new: new)
            }
            showBanner("主密码已修改")
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - 导入导出

    func importPack(_ data: Data) async -> String {
        guard let userID else { return "请先登录" }
        do {
            let list = try Self.decodeImport(data)
            let result = try await offload {
                try $0.importEntries(list, userID: userID)
            }
            await loadEntries()
            return result.skipped > 0
                ? "已导入 \(result.imported) 条，跳过 \(result.skipped) 条重复"
                : "已导入 \(result.imported) 条"
        } catch {
            return error.localizedDescription
        }
    }

    func exportFile() throws -> URL {
        let data = try JSONEncoder.pretty.encode(ExportPack(entries: entries))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vault-v2-backup.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - 提示条

    func showBanner(_ text: String) {
        banner = text
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            self?.banner = nil
        }
    }

    // MARK: - 内部

    private func loadEntries() async {
        guard let userID else { return }
        generation += 1
        let current = generation
        loadingList = true
        defer { if current == generation { loadingList = false } }
        do {
            let list = try await offload { try $0.entries(userID: userID) }
            guard current == generation else { return }
            entries = list
            if let selectedID, !list.contains(where: { $0.id == selectedID }) {
                self.selectedID = nil
            }
            loadError = nil
        } catch {
            guard current == generation else { return }
            loadError = error.localizedDescription
        }
    }

    /// 所有 SQLite 读写都放到后台线程，避免阻塞主线程导致界面卡顿。
    private func offload<T: Sendable>(_ work: @escaping @Sendable (Store) throws -> T) async throws -> T {
        let store = self.store
        return try await Task.detached(priority: .userInitiated) { try work(store) }.value
    }

    nonisolated private static func decodeImport(_ data: Data) throws -> [Entry] {
        let decoder = JSONDecoder()
        if let pack = try? decoder.decode(ExportPack.self, from: data) {
            return pack.entries
        }
        if let list = try? decoder.decode([Entry].self, from: data) {
            return list
        }
        throw StoreError.message("文件格式不对")
    }
}

private struct ExportPack: Codable {
    var entries: [Entry]
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
