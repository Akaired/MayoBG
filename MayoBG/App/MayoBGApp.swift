import SwiftUI
import UserNotifications
import OSLog

extension Notification.Name {
    static let APIKeyDidChange = Notification.Name("APIKeyDidChange")
}

@main
struct MayoBGApp: App {
    let controller = StatusBarController()
    private let notificationDelegate = NotificationDelegate()

    init() {
        setupNotifications()
        checkAPIKey()
    }

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = notificationDelegate

        Task {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
    }

    private func checkAPIKey() {
        Task {
            let hasKey = await APIKeyStore.shared.hasKey()
            if !hasKey {
                await MainActor.run { showAPIKeyPrompt() }
            }
        }
    }

    private func showAPIKeyPrompt() {
        let alert = NSAlert()
        alert.messageText = "apikey.title".localized
        alert.informativeText = "apikey.message".localized
        alert.alertStyle = .informational
        alert.addButton(withTitle: "apikey.save".localized)
        alert.addButton(withTitle: "apikey.later".localized)

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "apikey.placeholder".localized
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let key = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            Task {
                await APIKeyStore.shared.store(key)
                os_log(.info, "API key saved")
                await MainActor.run {
                    NotificationCenter.default.post(name: .APIKeyDidChange, object: nil)
                }
            }
        }
    }
}
