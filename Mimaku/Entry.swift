import Foundation

/// 果篮里的一条记录，字段与 web 版的 entry 一一对应。
struct Entry: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var url: String
    var username: String
    var password: String
    var notes: String
    var updatedAt: String

    init(
        id: String = "",
        title: String = "",
        url: String = "",
        username: String = "",
        password: String = "",
        notes: String = "",
        updatedAt: String = ""
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.username = username
        self.password = password
        self.notes = notes
        self.updatedAt = updatedAt
    }

    /// 导入旧备份时字段可能缺失，缺什么补什么。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}

/// 存储层抛出的错误，`errorDescription` 直接就是可以展示给用户的中文文案。
enum StoreError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}
