import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var showKey = false
    @State private var keySaved = false

    var body: some View {
        TabView {
            GeneralTab(settings: AppSettings.shared)
                .tabItem { Label("settings.general".localized, systemImage: "gearshape") }

            APITab(apiKey: $apiKey, showKey: $showKey, keySaved: $keySaved)
                .tabItem { Label("settings.api".localized, systemImage: "key") }

            AboutTab()
                .tabItem { Label("settings.about".localized, systemImage: "info.circle") }
        }
        .frame(width: 450, height: 360)
        .task { await loadAPIKey() }
        .onChange(of: apiKey) { _, _ in keySaved = false }
    }

    private func loadAPIKey() async {
        if let key = try? await APIKeyStore.shared.retrieve() {
            apiKey = key
        }
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("settings.update_interval".localized, selection: $settings.updateInterval) {
                    Text("interval.10min".localized).tag(600.0)
                    Text("interval.30min".localized).tag(1800.0)
                    Text("interval.1hour".localized).tag(3600.0)
                    Text("interval.3hours".localized).tag(10800.0)
                    Text("interval.12hours".localized).tag(43200.0)
                    Text("interval.24hours".localized).tag(86400.0)
                    Text("interval.1week".localized).tag(604800.0)
                    Text("interval.2weeks".localized).tag(1209600.0)
                }

                Toggle("settings.randomize".localized, isOn: $settings.randomize)
                Toggle("settings.launch_at_login".localized, isOn: $settings.launchAtLogin)
            }

            Section("settings.notifications".localized) {
                Toggle("settings.wallpaper_change".localized, isOn: $settings.notifyWallpaperChange)
                Toggle("settings.download_complete".localized, isOn: $settings.notifyDownload)
            }

            Section("settings.language".localized) {
                Picker("settings.language".localized, selection: $settings.language) {
                    Text("language.english".localized).tag("en")
                    Text("language.italian".localized).tag("it")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - API Tab

struct APITab: View {
    @Binding var apiKey: String
    @Binding var showKey: Bool
    @Binding var keySaved: Bool

    var body: some View {
        Form {
            Section {
                HStack {
                    if showKey {
                        TextField("settings.api_key_field".localized, text: $apiKey)
                    } else {
                        SecureField("settings.api_key_field".localized, text: $apiKey)
                    }

                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }

                Button("settings.save".localized) {
                    Task { await saveAPIKey() }
                }
                .disabled(apiKey.isEmpty)

                if keySaved {
                    Label("settings.saved".localized, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } header: {
                Text("settings.client_id".localized)
            } footer: {
                Text("settings.api_footer".localized)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func saveAPIKey() async {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        await APIKeyStore.shared.store(key)
        keySaved = true
        NotificationCenter.default.post(name: .APIKeyDidChange, object: nil)
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("MayoBG")
                .font(.title)

            Text("settings.version".localized)
                .foregroundStyle(.secondary)

            Text("settings.copyright".localized)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("settings.description".localized)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let url = URL(string: "https://unsplash.com/documentation") {
                Link("settings.api_guidelines".localized, destination: url)
                    .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
}
