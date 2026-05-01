import Foundation
import OSLog

actor APIKeyStore {
    static let shared = APIKeyStore()

    private let defaultsKey = "unsplash_api_key"

    private init() {}

    func hasKey() -> Bool {
        (try? retrieve()) != nil
    }

    func retrieve() throws -> String {
        guard let key = UserDefaults.standard.string(forKey: defaultsKey), !key.isEmpty else {
            throw APIKeyStoreError.notFound
        }
        return key
    }

    func store(_ key: String) {
        UserDefaults.standard.set(key, forKey: defaultsKey)
    }

    func delete() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

enum APIKeyStoreError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: "No API key found"
        }
    }
}
