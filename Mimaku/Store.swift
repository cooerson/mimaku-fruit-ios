import CommonCrypto
import Foundation
import Security
import SQLite3

final class Store: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    func open() throws {
        try lock.perform {
            if db != nil { return }
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let path = dir.appendingPathComponent("mimaku.sqlite").path
            var handle: OpaquePointer?
            guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
                throw APIError.message("打不开这台手机上的果篮")
            }
            db = handle
            try exec("PRAGMA foreign_keys = ON")
            try exec("""
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS entries (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                title TEXT NOT NULL,
                url TEXT NOT NULL DEFAULT '',
                username TEXT NOT NULL DEFAULT '',
                password TEXT NOT NULL DEFAULT '',
                notes TEXT NOT NULL DEFAULT '',
                updated_at TEXT NOT NULL,
                seq INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS entries_user_seq ON entries(user_id, seq DESC);
            """)
        }
    }

    func userExists(_ id: String) -> Bool {
        (try? lock.perform { try scalar("SELECT 1 FROM users WHERE id = ?", [id]) != nil }) ?? false
    }

    func login(password: String) throws -> (userID: String, created: Bool) {
        guard Self.validFruitPassword(password) else {
            throw APIError.message("请按顺序点选 6–16 种不重复的水果")
        }
        return try lock.perform {
            if let id = try matchUser(password) {
                return (id, false)
            }
            let id = UUID().uuidString
            let hash = try Self.hashPassword(password)
            try exec("INSERT INTO users (id, password_hash, created_at) VALUES (?, ?, ?)", [id, hash, Self.now()])
            return (id, true)
        }
    }

    func entries(userID: String) throws -> [Entry] {
        try lock.perform {
            try rows("SELECT id, title, url, username, password, notes, updated_at FROM entries WHERE user_id = ? ORDER BY seq DESC", [userID]) { stmt in
                Entry(
                    id: text(stmt, 0),
                    title: text(stmt, 1),
                    url: text(stmt, 2),
                    username: text(stmt, 3),
                    password: text(stmt, 4),
                    notes: text(stmt, 5),
                    updatedAt: text(stmt, 6)
                )
            }
        }
    }

    func create(_ entry: Entry, userID: String) throws -> Entry {
        try lock.perform {
            var saved = entry
            if saved.id.isEmpty { saved.id = Self.newID() }
            if saved.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { saved.title = "新条目" }
            saved.updatedAt = Self.now()
            let seq = (try scalar("SELECT COALESCE(MAX(seq), 0) + 1 FROM entries WHERE user_id = ?", [userID]) as? Int64) ?? 1
            try exec(
                "INSERT INTO entries (id, user_id, title, url, username, password, notes, updated_at, seq) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [saved.id, userID, saved.title, saved.url, saved.username, saved.password, saved.notes, saved.updatedAt ?? "", String(seq)]
            )
            return saved
        }
    }

    func update(_ entry: Entry, userID: String) throws -> Entry {
        try lock.perform {
            var saved = entry
            if saved.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { saved.title = "新条目" }
            saved.updatedAt = Self.now()
            try exec(
                "UPDATE entries SET title = ?, url = ?, username = ?, password = ?, notes = ?, updated_at = ? WHERE id = ? AND user_id = ?",
                [saved.title, saved.url, saved.username, saved.password, saved.notes, saved.updatedAt ?? "", saved.id, userID]
            )
            if sqlite3_changes(db) == 0 {
                throw APIError.message("这条已经不在果篮里")
            }
            return saved
        }
    }

    func delete(id: String, userID: String) throws {
        try lock.perform {
            try exec("DELETE FROM entries WHERE id = ? AND user_id = ?", [id, userID])
            if sqlite3_changes(db) == 0 {
                throw APIError.message("这条已经不在果篮里")
            }
        }
    }

    func importEntries(_ incoming: [Entry], userID: String) throws -> (imported: Int, skipped: Int) {
        try lock.perform {
            let existing: [Entry] = try rows("SELECT id, title, url, username, password, notes, updated_at FROM entries WHERE user_id = ?", [userID]) { stmt in
                Entry(id: text(stmt, 0), title: text(stmt, 1), url: text(stmt, 2), username: text(stmt, 3), password: text(stmt, 4), notes: text(stmt, 5), updatedAt: text(stmt, 6))
            }
            var seenID = Set(existing.map(\.id))
            var seenKey = Set(existing.map(Self.fingerprint))
            var imported = 0
            var skipped = 0
            var seq = (try scalar("SELECT COALESCE(MAX(seq), 0) FROM entries WHERE user_id = ?", [userID]) as? Int64) ?? 0
            try exec("BEGIN IMMEDIATE")
            do {
                for var entry in incoming {
                    let key = Self.fingerprint(entry)
                    if seenID.contains(entry.id) || seenKey.contains(key) {
                        skipped += 1
                        continue
                    }
                    if entry.id.isEmpty || seenID.contains(entry.id) {
                        entry.id = Self.newID()
                    }
                    if try scalar("SELECT 1 FROM entries WHERE id = ?", [entry.id]) != nil {
                        entry.id = Self.newID()
                    }
                    if entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { entry.title = "新条目" }
                    if entry.updatedAt?.isEmpty != false { entry.updatedAt = Self.now() }
                    seq += 1
                    try exec(
                        "INSERT INTO entries (id, user_id, title, url, username, password, notes, updated_at, seq) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        [entry.id, userID, entry.title, entry.url, entry.username, entry.password, entry.notes, entry.updatedAt ?? "", String(seq)]
                    )
                    seenID.insert(entry.id)
                    seenKey.insert(key)
                    imported += 1
                }
                try exec("COMMIT")
            } catch {
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                throw error
            }
            return (imported, skipped)
        }
    }

    func changePassword(userID: String, old: String, new: String) throws {
        guard Self.validFruitPassword(new) else {
            throw APIError.message("请按顺序点选 6–16 种不重复的水果")
        }
        if old == new {
            throw APIError.message("新的水果密码不能和现在相同")
        }
        try lock.perform {
            guard let hash = try scalar("SELECT password_hash FROM users WHERE id = ?", [userID]) as? String else {
                throw APIError.message("找不到这个果篮")
            }
            guard Self.checkPassword(hash, old) else {
                throw APIError.message("当前水果密码不正确")
            }
            if let other = try matchUser(new), other != userID {
                throw APIError.message("这组水果密码已经在这台手机上")
            }
            let next = try Self.hashPassword(new)
            try exec("UPDATE users SET password_hash = ? WHERE id = ?", [next, userID])
        }
    }

    private func matchUser(_ password: String) throws -> String? {
        let users: [(String, String)] = try rows("SELECT id, password_hash FROM users") { stmt in
            (text(stmt, 0), text(stmt, 1))
        }
        return users.first { Self.checkPassword($0.1, password) }?.0
    }

    private func exec(_ sql: String, _ values: [String] = []) throws {
        if values.isEmpty {
            var error: UnsafeMutablePointer<CChar>?
            let code = sqlite3_exec(db, sql, nil, nil, &error)
            if code != SQLITE_OK {
                sqlite3_free(error)
                throw APIError.message("没能保存，请再试一次")
            }
            return
        }
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (offset, value) in values.enumerated() {
            bind(stmt, Int32(offset + 1), value)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw APIError.message("没能保存，请再试一次")
        }
    }

    private func scalar(_ sql: String, _ values: [String] = []) throws -> Any? {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (offset, value) in values.enumerated() {
            bind(stmt, Int32(offset + 1), value)
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        switch sqlite3_column_type(stmt, 0) {
        case SQLITE_INTEGER:
            return sqlite3_column_int64(stmt, 0)
        case SQLITE_TEXT:
            return text(stmt, 0)
        default:
            return nil
        }
    }

    private func rows<T>(_ sql: String, _ values: [String] = [], _ map: (OpaquePointer?) -> T) throws -> [T] {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (offset, value) in values.enumerated() {
            bind(stmt, Int32(offset + 1), value)
        }
        var list: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            list.append(map(stmt))
        }
        return list
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw APIError.message("没能保存，请再试一次")
        }
        return stmt
    }

    private func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String) {
        value.withCString { ptr in
            sqlite3_bind_text(stmt, index, ptr, -1, transient)
        }
    }

    private func text(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        guard let raw = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: raw)
    }

    private static func validFruitPassword(_ value: String) -> Bool {
        let alphabet = Set("ABOGSWPIMKLCEURN")
        let chars = Array(value)
        guard (6...16).contains(chars.count) else { return false }
        return Set(chars).count == chars.count && chars.allSatisfy { alphabet.contains($0) }
    }

    private static func fingerprint(_ entry: Entry) -> String {
        entry.title.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            + entry.url.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            + entry.username.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            + entry.password
    }

    private static func newID() -> String {
        "e_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private static func now() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }

    private static func hashPassword(_ password: String) throws -> String {
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { throw APIError.message("没能建立果篮") }
        let derived = try derive(password, salt: salt)
        return b64(salt) + ":" + b64(derived)
    }

    private static func checkPassword(_ stored: String, _ password: String) -> Bool {
        let parts = stored.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let salt = b64decode(parts[0]), let want = b64decode(parts[1]) else { return false }
        guard let derived = try? derive(password, salt: salt) else { return false }
        guard derived.count == want.count else { return false }
        return derived.withUnsafeBytes { left in
            want.withUnsafeBytes { right in
                memcmp(left.baseAddress, right.baseAddress, derived.count) == 0
            }
        }
    }

    private static func derive(_ password: String, salt: Data) throws -> Data {
        let passwordData = Data(password.utf8)
        var derived = Data(count: 32)
        let status: CCCryptorStatus = passwordData.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                derived.withUnsafeMutableBytes { derivedBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        120_000,
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        32
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw APIError.message("没能核对水果密码") }
        return derived
    }

    private static func b64(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "=", with: "")
    }

    private static func b64decode(_ value: String) -> Data? {
        var text = value
        let pad = (4 - text.count % 4) % 4
        if pad < 4 { text += String(repeating: "=", count: pad) }
        return Data(base64Encoded: text)
    }
}

private extension NSLock {
    func perform<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
