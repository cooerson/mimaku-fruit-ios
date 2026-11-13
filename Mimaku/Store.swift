import CommonCrypto
import Foundation
import SQLite3

/// 登录结果：`created` 为 true 表示这次新注册了一个果篮。
struct LoginResult: Sendable {
    let userID: String
    let created: Bool
}

struct ImportResult: Sendable {
    let imported: Int
    let skipped: Int
}

/// 离线果篮的存储层：SQLite + PBKDF2。
///
/// 规则与 web 版保持一致：
/// - 主密码是 6–16 个不重复的水果字母（字母表 `ABOGSWPIMKLCEURN`）
/// - 口令用 PBKDF2-SHA256 派生，120000 轮、16 字节盐、32 字节密钥，存成 `salt:hash`
/// - 账号名就是水果密码本身，首次登录即注册
final class Store: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: - 打开数据库

    func open() throws {
        try lock.perform {
            guard db == nil else { return }
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let path = directory.appendingPathComponent("mimaku.sqlite").path

            var handle: OpaquePointer?
            let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX
            guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
                throw StoreError.message("打不开这台手机上的果篮")
            }
            db = handle

            try exec("PRAGMA journal_mode = WAL")
            try exec("PRAGMA synchronous = NORMAL")
            try exec("PRAGMA foreign_keys = ON")
            try exec("""
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                username TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE UNIQUE INDEX IF NOT EXISTS users_username_idx ON users (username);

            CREATE TABLE IF NOT EXISTS entries (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                title TEXT NOT NULL,
                url TEXT NOT NULL DEFAULT '',
                username TEXT NOT NULL DEFAULT '',
                password TEXT NOT NULL DEFAULT '',
                notes TEXT NOT NULL DEFAULT '',
                updated_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS entries_user_idx ON entries (user_id);
            """)
        }
    }

    // MARK: - 账号

    func userExists(id: String) -> Bool {
        (try? lock.perform { try scalar("SELECT COUNT(*) FROM users WHERE id = ?", [id]) > 0 }) ?? false
    }

    /// 等价于 web 版的 handleEnter：有账号就登录，没有就用这组水果注册。
    func login(password: String) throws -> LoginResult {
        try lock.perform {
            guard FruitPassword.isValid(password) else {
                throw StoreError.message("请按顺序点选 6–16 种不重复的水果")
            }
            if let existing = try findUser(username: password) {
                guard checkPassword(stored: existing.hash, password: password) else {
                    throw StoreError.message("水果密码不正确")
                }
                return LoginResult(userID: existing.id, created: false)
            }
            let id = Store.newID(prefix: "u_")
            try run(
                "INSERT INTO users (id, username, password_hash, created_at) VALUES (?, ?, ?, ?)",
                [id, password, hashPassword(password), now()]
            )
            return LoginResult(userID: id, created: true)
        }
    }

    func changePassword(userID: String, old: String, new: String) throws {
        try lock.perform {
            guard FruitPassword.isValid(new) else {
                throw StoreError.message("请按顺序点选 6–16 种不重复的水果")
            }
            guard let hash = try scalarText("SELECT password_hash FROM users WHERE id = ?", [userID]) else {
                throw StoreError.message("账号不存在")
            }
            guard checkPassword(stored: hash, password: old) else {
                throw StoreError.message("当前水果密码不正确")
            }
            let taken = try scalar("SELECT COUNT(*) FROM users WHERE username = ? AND id <> ?", [new, userID])
            guard taken == 0 else {
                throw StoreError.message("这组水果顺序已被注册")
            }
            try run(
                "UPDATE users SET username = ?, password_hash = ? WHERE id = ?",
                [new, hashPassword(new), userID]
            )
        }
    }

    // MARK: - 条目

    func entries(userID: String) throws -> [Entry] {
        try lock.perform {
            let statement = try prepare("""
            SELECT id, title, url, username, password, notes, updated_at
            FROM entries WHERE user_id = ? ORDER BY rowid DESC
            """)
            defer { sqlite3_finalize(statement) }
            bind(statement, [userID])

            var list: [Entry] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                list.append(
                    Entry(
                        id: text(statement, 0),
                        title: text(statement, 1),
                        url: text(statement, 2),
                        username: text(statement, 3),
                        password: text(statement, 4),
                        notes: text(statement, 5),
                        updatedAt: text(statement, 6)
                    )
                )
            }
            return list
        }
    }

    func create(_ entry: Entry, userID: String) throws -> Entry {
        try lock.perform {
            var created = entry
            if created.id.isEmpty { created.id = Store.newID(prefix: "e_") }
            let trimmed = created.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { created.title = "新条目" }
            created.updatedAt = now()
            try run("""
            INSERT INTO entries (id, user_id, title, url, username, password, notes, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, [
                created.id, userID, created.title, created.url,
                created.username, created.password, created.notes, created.updatedAt
            ])
            return created
        }
    }

    func update(id: String, userID: String, with input: Entry) throws -> Entry {
        try lock.perform {
            let trimmed = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = trimmed.isEmpty ? "新条目" : trimmed
            let updated = now()
            try run("""
            UPDATE entries SET title = ?, url = ?, username = ?, password = ?, notes = ?, updated_at = ?
            WHERE id = ? AND user_id = ?
            """, [title, input.url, input.username, input.password, input.notes, updated, id, userID])
            guard sqlite3_changes(db) > 0 else {
                throw StoreError.message("条目不存在")
            }
            return Entry(
                id: id,
                title: title,
                url: input.url,
                username: input.username,
                password: input.password,
                notes: input.notes,
                updatedAt: updated
            )
        }
    }

    func delete(id: String, userID: String) throws {
        try lock.perform {
            try run("DELETE FROM entries WHERE id = ? AND user_id = ?", [id, userID])
            guard sqlite3_changes(db) > 0 else {
                throw StoreError.message("条目不存在")
            }
        }
    }

    /// 按 id 与指纹去重，与 web 版 importEntries 的判定一致。
    func importEntries(_ incoming: [Entry], userID: String) throws -> ImportResult {
        try lock.perform {
            var seenID = Set<String>()
            var seenKey = Set<String>()

            let statement = try prepare("SELECT id, title, url, username, password FROM entries WHERE user_id = ?")
            do {
                bind(statement, [userID])
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = text(statement, 0)
                    if !id.isEmpty { seenID.insert(id) }
                    seenKey.insert(fingerprint(
                        title: text(statement, 1),
                        url: text(statement, 2),
                        username: text(statement, 3),
                        password: text(statement, 4)
                    ))
                }
            }
            sqlite3_finalize(statement)

            try exec("BEGIN IMMEDIATE")
            var imported = 0
            var skipped = 0
            do {
                for var entry in incoming {
                    let key = fingerprint(
                        title: entry.title,
                        url: entry.url,
                        username: entry.username,
                        password: entry.password
                    )
                    if (!entry.id.isEmpty && seenID.contains(entry.id)) || seenKey.contains(key) {
                        skipped += 1
                        continue
                    }
                    if entry.id.isEmpty {
                        entry.id = Store.newID(prefix: "e_")
                    } else if try scalar("SELECT COUNT(*) FROM entries WHERE id = ?", [entry.id]) > 0 {
                        entry.id = Store.newID(prefix: "e_")
                    }
                    let updated = entry.updatedAt.isEmpty ? now() : entry.updatedAt
                    try run("""
                    INSERT INTO entries (id, user_id, title, url, username, password, notes, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, [
                        entry.id, userID, entry.title, entry.url,
                        entry.username, entry.password, entry.notes, updated
                    ])
                    seenID.insert(entry.id)
                    seenKey.insert(key)
                    imported += 1
                }
                try exec("COMMIT")
            } catch {
                try? exec("ROLLBACK")
                throw error
            }
            return ImportResult(imported: imported, skipped: skipped)
        }
    }

    // MARK: - SQLite 基础操作

    private func exec(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "数据库错误"
            sqlite3_free(error)
            throw StoreError.message(message)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw StoreError.message(lastError())
        }
        return statement
    }

    private func run(_ sql: String, _ values: [String] = []) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(statement, values)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.message(lastError())
        }
    }

    private func bind(_ statement: OpaquePointer, _ values: [String]) {
        for (offset, value) in values.enumerated() {
            sqlite3_bind_text(statement, Int32(offset + 1), value, -1, transient)
        }
    }

    private func scalar(_ sql: String, _ values: [String] = []) throws -> Int {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(statement, values)
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func scalarText(_ sql: String, _ values: [String]) throws -> String? {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(statement, values)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return text(statement, 0)
    }

    private func text(_ statement: OpaquePointer, _ column: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: pointer)
    }

    private func lastError() -> String {
        guard let db, let message = sqlite3_errmsg(db) else { return "数据库错误" }
        return String(cString: message)
    }

    private func findUser(username: String) throws -> (id: String, hash: String)? {
        let statement = try prepare("SELECT id, password_hash FROM users WHERE username = ? LIMIT 1")
        defer { sqlite3_finalize(statement) }
        bind(statement, [username])
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return (text(statement, 0), text(statement, 1))
    }

    // MARK: - 口令与工具

    private func fingerprint(title: String, url: String, username: String, password: String) -> String {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return [trim(title), trim(url), trim(username), password].joined(separator: "\n")
    }

    private func now() -> String {
        Store.timestamp.string(from: Date())
    }

    private static let timestamp: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func newID(prefix: String) -> String {
        prefix + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private func hashPassword(_ password: String) -> String {
        var salt = Data(count: 16)
        salt.withUnsafeMutableBytes { buffer in
            _ = SecRandomCopyBytes(kSecRandomDefault, 16, buffer.baseAddress!)
        }
        return base64(salt) + ":" + base64(derive(password: password, salt: salt))
    }

    private func checkPassword(stored: String, password: String) -> Bool {
        let parts = stored.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let salt = base64Decode(String(parts[0])),
              let expected = base64Decode(String(parts[1]))
        else { return false }
        return constantTimeEquals(derive(password: password, salt: salt), expected)
    }

    /// PBKDF2-SHA256，120000 轮，16 字节盐，32 字节密钥。
    private func derive(password: String, salt: Data) -> Data {
        var derived = Data(count: 32)
        let passwordLength = password.utf8.count
        let saltCount = salt.count
        let status = derived.withUnsafeMutableBytes { output in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password,
                    passwordLength,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    saltCount,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    120_000,
                    output.bindMemory(to: UInt8.self).baseAddress,
                    32
                )
            }
        }
        guard status == kCCSuccess else { return Data(count: 32) }
        return derived
    }

    private func base64(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "=", with: "")
    }

    private func base64Decode(_ value: String) -> Data? {
        var padded = value
        while padded.count % 4 != 0 { padded += "=" }
        return Data(base64Encoded: padded)
    }

    private func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }
}

private extension NSLock {
    func perform<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
