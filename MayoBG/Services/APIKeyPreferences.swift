import Foundation
import OSLog

final class APIKeyPreferences {
    static let shared = APIKeyPreferences()

    private let defaultsKey = "unsplash_api_key"

    private init() {}

    func hasKey() -> Bool {
        if let key = retrieve(), !key.isEmpty {
            return true
        }
        return false
    }

    func retrieve() -> String? {
        UserDefaults.standard.string(forKey: defaultsKey)
    }

    func store(_ key: String) {
        UserDefaults.standard.set(key, forKey: defaultsKey)
    }
}
