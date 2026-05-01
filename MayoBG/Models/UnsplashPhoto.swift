import Foundation

struct UnsplashPhoto: Codable, Identifiable, Equatable {
    let id: String
    let width: Int
    let height: Int
    let color: String?
    let blurHash: String?
    let description: String?
    let urls: PhotoURLs
    let links: PhotoLinks
    let user: UnsplashUser

    enum CodingKeys: String, CodingKey {
        case id, width, height, color
        case blurHash = "blur_hash"
        case description
        case urls, links, user
    }

    static func == (lhs: UnsplashPhoto, rhs: UnsplashPhoto) -> Bool {
        lhs.id == rhs.id
    }
}

struct PhotoURLs: Codable {
    let raw: URL
    let full: URL
    let regular: URL
    let small: URL
    let thumb: URL
}

struct PhotoLinks: Codable {
    let html: URL
    let download: URL?
    let downloadLocation: URL?

    enum CodingKeys: String, CodingKey {
        case html, download
        case downloadLocation = "download_location"
    }
}

struct UnsplashUser: Codable {
    let username: String
    let name: String
    let links: UserLinks
}

struct UserLinks: Codable {
    let html: URL
}

struct SearchResults: Codable {
    let total: Int
    let totalPages: Int
    let results: [UnsplashPhoto]

    enum CodingKeys: String, CodingKey {
        case total
        case totalPages = "total_pages"
        case results
    }
}
