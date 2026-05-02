import Foundation
import OSLog

final class UnsplashService: @unchecked Sendable {
    private let baseURL = "https://api.unsplash.com"
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    enum UnsplashError: LocalizedError {
        case invalidResponse
        case httpError(Int)
        case downloadTrackingFailed
        case rateLimited
        case noAPIKey

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Invalid response from Unsplash"
            case .httpError(let code): "HTTP \(code)"
            case .downloadTrackingFailed: "Failed to track download"
            case .rateLimited: "Rate limit exceeded"
            case .noAPIKey: "No API key configured"
            }
        }
    }

    func fetchRandom(
        query: String? = nil,
        collections: [String] = [],
        username: String? = nil,
        orientation: String? = "landscape",
        count: Int = 1
    ) async throws -> [UnsplashPhoto] {
        let apiKey = try apiKey()
        var components = URLComponents(string: "\(baseURL)/photos/random")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "content_filter", value: "high"),
            URLQueryItem(name: "count", value: "\(count)"),
        ]
        if let query { queryItems.append(URLQueryItem(name: "query", value: query)) }
        if let username { queryItems.append(URLQueryItem(name: "username", value: username)) }
        if let orientation { queryItems.append(URLQueryItem(name: "orientation", value: orientation)) }
        if !collections.isEmpty { queryItems.append(URLQueryItem(name: "collections", value: collections.joined(separator: ","))) }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Client-ID \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode([UnsplashPhoto].self, from: data)
    }

    func search(
        query: String,
        page: Int = 1,
        perPage: Int = 10,
        orientation: String? = "landscape"
    ) async throws -> SearchResults {
        let apiKey = try apiKey()
        var components = URLComponents(string: "\(baseURL)/search/photos")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
        ]
        if let orientation { queryItems.append(URLQueryItem(name: "orientation", value: orientation)) }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Client-ID \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(SearchResults.self, from: data)
    }

    func fetchCollectionPhotos(
        collectionID: String,
        page: Int = 1,
        perPage: Int = 10
    ) async throws -> [UnsplashPhoto] {
        let apiKey = try apiKey()
        var components = URLComponents(string: "\(baseURL)/collections/\(collectionID)/photos")!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Client-ID \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode([UnsplashPhoto].self, from: data)
    }

    func trackDownload(for photo: UnsplashPhoto) async throws {
        let apiKey = try apiKey()
        guard let location = photo.links.downloadLocation else { return }
        var request = URLRequest(url: location)
        request.setValue("Client-ID \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UnsplashError.downloadTrackingFailed
        }
    }

    func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return data
    }

    func wallpaperURL(from photo: UnsplashPhoto, screenWidth: Int = 2560) -> URL {
        let base = photo.urls.raw.absoluteString
        guard let url = URL(string: "\(base)&q=85&w=\(screenWidth)&fit=max") else {
            return photo.urls.raw
        }
        return url
    }

    // MARK: - Attribution helpers

    static func attributionText(for photo: UnsplashPhoto) -> String {
        "Photo by \(photo.user.name) on Unsplash"
    }

    static func photographerURL(for photo: UnsplashPhoto) -> URL? {
        URL(string: "\(photo.user.links.html.absoluteString)?utm_source=MayoBG&utm_medium=referral")
    }

    static func unsplashURL() -> URL? {
        URL(string: "https://unsplash.com/?utm_source=MayoBG&utm_medium=referral")
    }

    // MARK: - Private

    private func apiKey() throws -> String {
        guard let key = APIKeyPreferences.shared.retrieve() else {
            throw UnsplashError.noAPIKey
        }
        return key
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw UnsplashError.invalidResponse
        }
        if http.statusCode == 429 {
            throw UnsplashError.rateLimited
        }
        guard (200...299).contains(http.statusCode) else {
            throw UnsplashError.httpError(http.statusCode)
        }
    }
}
