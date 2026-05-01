import Foundation

struct Channel: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var kind: ChannelKind

    static func == (lhs: Channel, rhs: Channel) -> Bool {
        lhs.id == rhs.id
    }
}

enum ChannelKind: Codable, Equatable {
    case collection(id: String, title: String)
    case search(query: String)
    case user(username: String, name: String)

    var displayName: String {
        switch self {
        case .collection(_, let title): "Collection: \(title)"
        case .search(let query): "Search: \(query)"
        case .user(_, let name): "User: \(name)"
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type, collectionID, collectionTitle, searchQuery, username, userName
    }

    enum KindType: String, Codable {
        case collection, search, user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(KindType.self, forKey: .type)
        switch type {
        case .collection:
            let id = try container.decode(String.self, forKey: .collectionID)
            let title = try container.decode(String.self, forKey: .collectionTitle)
            self = .collection(id: id, title: title)
        case .search:
            let query = try container.decode(String.self, forKey: .searchQuery)
            self = .search(query: query)
        case .user:
            let username = try container.decode(String.self, forKey: .username)
            let name = try container.decode(String.self, forKey: .userName)
            self = .user(username: username, name: name)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .collection(let id, let title):
            try container.encode(KindType.collection, forKey: .type)
            try container.encode(id, forKey: .collectionID)
            try container.encode(title, forKey: .collectionTitle)
        case .search(let query):
            try container.encode(KindType.search, forKey: .type)
            try container.encode(query, forKey: .searchQuery)
        case .user(let username, let name):
            try container.encode(KindType.user, forKey: .type)
            try container.encode(username, forKey: .username)
            try container.encode(name, forKey: .userName)
        }
    }
}

extension Channel {
    static let defaultChannels: [Channel] = [
        Channel(id: UUID(), name: "Wallpapers", kind: .search(query: "wallpaper")),
        Channel(id: UUID(), name: "Nature", kind: .search(query: "nature")),
        Channel(id: UUID(), name: "Minimal", kind: .search(query: "minimal")),
    ]
}
