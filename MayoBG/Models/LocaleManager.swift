import Foundation

@Observable
final class LocaleManager {
    static let shared = LocaleManager()

    var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "appLanguage") }
    }

    private var bundle: Bundle = .main

    private init() {
        let stored = UserDefaults.standard.string(forKey: "appLanguage")
        if let stored, ["en", "it"].contains(stored) {
            language = stored
        } else {
            language = "en"
        }
        reloadBundle()
    }

    func reloadBundle() {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            self.bundle = .main
            return
        }
        self.bundle = bundle
    }

    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

extension String {
    var localized: String {
        LocaleManager.shared.localized(self)
    }
}
