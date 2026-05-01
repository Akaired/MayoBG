import Foundation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var updateInterval: TimeInterval {
        didSet { UserDefaults.standard.set(updateInterval, forKey: Key.updateInterval) }
    }

    var randomize: Bool {
        didSet { UserDefaults.standard.set(randomize, forKey: Key.randomize) }
    }

    var notifyWallpaperChange: Bool {
        didSet { UserDefaults.standard.set(notifyWallpaperChange, forKey: Key.notifyWallpaperChange) }
    }

    var notifyDownload: Bool {
        didSet { UserDefaults.standard.set(notifyDownload, forKey: Key.notifyDownload) }
    }

    var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "appLanguage")
            LocaleManager.shared.language = language
            LocaleManager.shared.reloadBundle()
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.updateInterval = defaults.double(forKey: Key.updateInterval) > 0
            ? defaults.double(forKey: Key.updateInterval) : 3600
        self.randomize = defaults.object(forKey: Key.randomize) != nil
            ? defaults.bool(forKey: Key.randomize) : true
        self.notifyWallpaperChange = defaults.object(forKey: Key.notifyWallpaperChange) != nil
            ? defaults.bool(forKey: Key.notifyWallpaperChange) : false
        self.notifyDownload = defaults.object(forKey: Key.notifyDownload) != nil
            ? defaults.bool(forKey: Key.notifyDownload) : true
        self.launchAtLogin = defaults.object(forKey: Key.launchAtLogin) != nil
            ? defaults.bool(forKey: Key.launchAtLogin) : true
        self.language = defaults.string(forKey: "appLanguage") ?? "en"
    }

    private enum Key {
        static let updateInterval = "updateInterval"
        static let randomize = "randomize"
        static let notifyWallpaperChange = "notifyWallpaperChange"
        static let notifyDownload = "notifyDownload"
        static let launchAtLogin = "launchAtLogin"
    }
}
