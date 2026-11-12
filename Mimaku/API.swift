import Foundation

struct Entry: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var url: String
    var username: String
    var password: String
    var notes: String
    var updatedAt: String?

    init(id: String = "", title: String = "", url: String = "", username: String = "", password: String = "", notes: String = "", updatedAt: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.username = username
        self.password = password
        self.notes = notes
        self.updatedAt = updatedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !id.isEmpty { try container.encode(id, forKey: .id) }
        try container.encode(title, forKey: .title)
        try container.encode(url, forKey: .url)
        try container.encode(username, forKey: .username)
        try container.encode(password, forKey: .password)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

enum APIError: LocalizedError {
    case message(String)
    case unauthorized(String)

    var errorDescription: String? {
        switch self {
        case .message(let text), .unauthorized(let text):
            return text
        }
    }
}
