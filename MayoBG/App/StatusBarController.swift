import AppKit
import OSLog
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class StatusBarController: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private let settings = AppSettings.shared
    private let unsplash = UnsplashService()
    private let history = HistoryManager()
    private let timerService = TimerService()
    private var channels: [Channel] = Channel.defaultChannels

    private var activeChannel: Channel {
        didSet { persistChannels() }
    }

    private var nextUpdateDate: Date?
    private var isLoading = false
    private var currentImageData: Data?
    private var prefetchedWallpaper: (photo: UnsplashPhoto, imageData: Data, localURL: URL)?
    private var settingsWindow: NSWindow?
    private var channelManagerWindow: NSWindow?
    private var aboutWindow: NSWindow?

    // MARK: - Setup

    override init() {
        self.activeChannel = channels.first ?? Channel.defaultChannels[0]
        super.init()
        loadChannels()
        setupStatusItem()
        setupTimer()
        observeAPIKeyChanges()
        observeSettingsChanges()
        setupHotkey()
        applyLaunchAtLogin()
    }

    private func applyLaunchAtLogin() {
        do {
            if settings.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            os_log(.error, "SMAppService failed: \(error.localizedDescription)")
        }
    }

    private func setupHotkey() {
        HotkeyService.shared.onHotkey = { [weak self] in
            Task { await self?.fetchAndApply() }
        }
        HotkeyService.shared.register()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle",
                                   accessibilityDescription: "MayoBG")
        }
        buildMenu()
    }

    private func observeAPIKeyChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(apiKeyDidChange),
            name: .APIKeyDidChange,
            object: nil
        )
    }

    @objc private func apiKeyDidChange() {
        prefetchedWallpaper = nil
        Task { await fetchAndApply() }
    }

    private func observeSettingsChanges() {
        withObservationTracking {
            _ = settings.updateInterval
            _ = settings.randomize
            _ = settings.launchAtLogin
            _ = settings.language
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.timerService.restart(with: self.settings.updateInterval)
                self.nextUpdateDate = Date().addingTimeInterval(self.settings.updateInterval)
                self.applyLaunchAtLogin()
                self.rebuildItems()
                self.observeSettingsChanges()
            }
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        statusItem.menu = menu
        rebuildItems()
    }

    private func rebuildItems() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        let nextItem = NSMenuItem(title: nextUpdateTitle, action: nil, keyEquivalent: "")
        nextItem.isEnabled = false
        menu.addItem(nextItem)

        menu.addItem(buildAboutPhotoSubmenu())
        menu.addItem(.separator())

        menu.addItem(menuItem("menu.change_wallpaper".localized, #selector(changeCurrentWallpaper), "W", [.command, .shift]))
        menu.addItem(menuItem("menu.change_all_wallpapers".localized, #selector(changeAllWallpapers), "M", [.command, .option]))

        if history.canGoBack {
            menu.addItem(menuItem("menu.previous_wallpaper".localized, #selector(loadPrevious), "Z", [.command, .option]))
        }
        if history.canGoBack {
            menu.addItem(menuItem("menu.first_in_channel".localized, #selector(firstInChannel), "R", [.command, .option]))
        }

        menu.addItem(menuItem("menu.download_current".localized, #selector(downloadCurrent), "S", [.command, .option]))
        menu.addItem(.separator())

        menu.addItem(buildChannelSubmenu())
        menu.addItem(menuItem("menu.manage_channels".localized, #selector(openChannelManager), "", []))

        menu.addItem(buildUpdateIntervalSubmenu())

        let randomItem = menuItem("menu.randomize".localized, #selector(toggleRandomize), "", [])
        randomItem.state = settings.randomize ? .on : .off
        menu.addItem(randomItem)

        menu.addItem(.separator())

        menu.addItem(menuItem("menu.settings".localized, #selector(openSettings), ",", [.command]))
        menu.addItem(menuItem("menu.about".localized, #selector(showAbout), "", []))
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "menu.quit".localized,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
    }

    private func menuItem(_ title: String, _ action: Selector, _ keyEquivalent: String, _ modifiers: NSEvent.ModifierFlags) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        return item
    }

    // MARK: - Submenu builders

    private func buildAboutPhotoSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "menu.about_photo".localized, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        if let photo = history.currentPhoto {
            let desc = photo.description ?? "menu.untitled".localized
            let descItem = NSMenuItem(title: desc, action: nil, keyEquivalent: "")
            descItem.isEnabled = false
            submenu.addItem(descItem)

            let photogItem = NSMenuItem(title: String(format: "menu.by_photographer".localized, photo.user.name), action: #selector(openLink(_:)), keyEquivalent: "")
            photogItem.target = self
            photogItem.representedObject = UnsplashService.photographerURL(for: photo)
            submenu.addItem(photogItem)

            submenu.addItem(.separator())

            let linkItem = NSMenuItem(title: "menu.view_on_unsplash".localized, action: #selector(openLink(_:)), keyEquivalent: "")
            linkItem.target = self
            linkItem.representedObject = photo.links.html
            submenu.addItem(linkItem)
        } else {
            let noPhoto = NSMenuItem(title: "menu.no_photo".localized, action: nil, keyEquivalent: "")
            noPhoto.isEnabled = false
            submenu.addItem(noPhoto)
        }

        item.submenu = submenu
        return item
    }

    private func buildChannelSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "menu.channel".localized, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for channel in channels {
            let menuItem = NSMenuItem(title: channel.name, action: #selector(selectChannel(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.state = (channel.id == activeChannel.id) ? .on : .off
            menuItem.representedObject = channel
            submenu.addItem(menuItem)
        }

        item.submenu = submenu
        return item
    }

    private func buildUpdateIntervalSubmenu() -> NSMenuItem {
        let intervals: [(String, TimeInterval)] = [
            ("interval.10min".localized, 600),
            ("interval.15min".localized, 900),
            ("interval.30min".localized, 1800),
            ("interval.1hour".localized, 3600),
            ("interval.3hours".localized, 10800),
            ("interval.12hours".localized, 43200),
            ("interval.24hours".localized, 86400),
            ("interval.1week".localized, 604800),
            ("interval.2weeks".localized, 1209600),
        ]

        let item = NSMenuItem(title: "menu.update_interval".localized, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for (label, interval) in intervals {
            let menuItem = NSMenuItem(title: label, action: #selector(setUpdateInterval(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.state = (interval == settings.updateInterval) ? .on : .off
            menuItem.representedObject = interval
            submenu.addItem(menuItem)
        }

        item.submenu = submenu
        return item
    }

    private var nextUpdateTitle: String {
        if let date = nextUpdateDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return String(format: "menu.next_update".localized, formatter.string(from: date))
        }
        return "menu.next_update_empty".localized
    }

    // MARK: - Timer

    private func setupTimer() {
        timerService.onTick = { [weak self] in
            await self?.fetchAndApply()
        }
        timerService.start(interval: settings.updateInterval)
    }

    // MARK: - Photo fetching

    private func fetchRandomPhoto(from channel: Channel) async throws -> UnsplashPhoto {
        switch channel.kind {
        case .search(let query):
            let count = settings.randomize ? 15 : 1
            let results = try await unsplash.fetchRandom(query: query, count: count)
            guard let picked = settings.randomize ? results.randomElement() : results.first else {
                throw FetchError.noPhotos
            }
            return picked
        case .collection(let id, _):
            let count = settings.randomize ? 15 : 1
            let results = try await unsplash.fetchRandom(collections: [id], count: count)
            guard let picked = settings.randomize ? results.randomElement() : results.first else {
                throw FetchError.noPhotos
            }
            return picked
        case .user(let username, _):
            let results = try await unsplash.fetchRandom(username: username, count: 1)
            guard let picked = results.first else {
                throw FetchError.noPhotos
            }
            return picked
        }
    }

    private enum FetchError: LocalizedError {
        case noPhotos
        var errorDescription: String? { "No photos returned from Unsplash" }
    }

    // MARK: - fetchAndApply

    private func fetchAndApply() async {
        guard !isLoading else {
            os_log(.info, "fetchAndApply skipped — already loading")
            return
        }
        let hasKey = await APIKeyStore.shared.hasKey()
        guard hasKey else { return }
        isLoading = true
        defer { isLoading = false }

        os_log(.info, "fetchAndApply: fetching from channel \(self.activeChannel.name), randomize=\(self.settings.randomize)")

        do {
            if let prefetched = prefetchedWallpaper {
                prefetchedWallpaper = nil
                guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
                os_log(.info, "fetchAndApply: using prefetched photo \(prefetched.photo.id)")
                try WallpaperService.shared.setWithCrossfade(url: prefetched.localURL, for: screen)
                try await unsplash.trackDownload(for: prefetched.photo)
                history.push(prefetched.photo)
                currentImageData = prefetched.imageData
                nextUpdateDate = Date().addingTimeInterval(settings.updateInterval)
                rebuildItems()
                os_log(.info, "fetchAndApply: done (prefetched) — wallpaper set to photo \(prefetched.photo.id)")
                prefetchNext()
                return
            }

            let photo = try await fetchRandomPhoto(from: activeChannel)

            guard let screen = NSScreen.main ?? NSScreen.screens.first else {
                os_log(.error, "fetchAndApply: no screens found")
                return
            }

            os_log(.info, "fetchAndApply: got photo \(photo.id) by \(photo.user.name), downloading...")
            let screenWidth = Int((screen.frame.width * screen.backingScaleFactor).rounded(.up))
            let wallpaperURL = unsplash.wallpaperURL(from: photo, screenWidth: screenWidth)
            let imageData = try await unsplash.downloadImage(from: wallpaperURL)
            os_log(.info, "fetchAndApply: downloaded \(imageData.count) bytes")

            let localURL = saveTempImage(imageData)
            os_log(.info, "fetchAndApply: setting wallpaper from \(localURL.path)")
            try WallpaperService.shared.setWithCrossfade(url: localURL, for: screen)

            let currentURL = NSWorkspace.shared.desktopImageURL(for: screen)
            os_log(.info, "fetchAndApply: desktopImageURL after set = \(currentURL?.path ?? "nil")")
            try await unsplash.trackDownload(for: photo)
            history.push(photo)
            currentImageData = imageData

            prefetchNext()
            nextUpdateDate = Date().addingTimeInterval(settings.updateInterval)
            rebuildItems()
            os_log(.info, "fetchAndApply: done — wallpaper set to photo \(photo.id)")
        } catch {
            os_log(.error, "fetchAndApply failed: \(error.localizedDescription)")
        }
    }

    private func prefetchNext() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let photo = try await self.fetchRandomPhoto(from: self.activeChannel)

                guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
                let screenWidth = Int((screen.frame.width * screen.backingScaleFactor).rounded(.up))
                let wallpaperURL = self.unsplash.wallpaperURL(from: photo, screenWidth: screenWidth)
                let imageData = try await self.unsplash.downloadImage(from: wallpaperURL)
                let localURL = self.saveTempImage(imageData)

                self.prefetchedWallpaper = (photo, imageData, localURL)
                os_log(.info, "prefetchNext: prefetched photo \(photo.id)")
            } catch {
                os_log(.error, "prefetchNext failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveTempImage(_ data: Data) -> URL {
        let dir = URL(fileURLWithPath: "/var/tmp/MayoBG")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("wallpaper_\(UUID().uuidString).jpg")
        do {
            try data.write(to: file, options: .atomic)
        } catch {
            os_log(.error, "saveTempImage: write failed — \(error.localizedDescription)")
        }
        cleanOldWallpapers(in: dir, keep: 5)
        return file
    }

    private func cleanOldWallpapers(in directory: URL, keep: Int) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let sorted = files.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return date1 > date2
        }
        for file in sorted.dropFirst(keep) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Actions

    @objc private func changeCurrentWallpaper() {
        Task { await fetchAndApply() }
    }

    @objc private func changeAllWallpapers() {
        Task {
            guard !isLoading else { return }
            isLoading = true
            defer { isLoading = false }
            do {
                let photo: UnsplashPhoto
                switch activeChannel.kind {
                case .search(let query):
                    let result = try await unsplash.search(query: query, perPage: 1)
                    guard let first = result.results.first else { return }
                    photo = first
                case .collection(let id, _):
                    let results = try await unsplash.fetchCollectionPhotos(collectionID: id, perPage: 1)
                    guard let first = results.first else { return }
                    photo = first
                case .user(let username, _):
                    let results = try await unsplash.fetchRandom(username: username, count: 1)
                    guard let first = results.first else { return }
                    photo = first
                }
                let screenWidth = NSScreen.screens
                    .map { Int(($0.frame.width * $0.backingScaleFactor).rounded(.up)) }
                    .max() ?? 2560
                let imageData = try await unsplash.downloadImage(from: unsplash.wallpaperURL(from: photo, screenWidth: screenWidth))
                let localURL = saveTempImage(imageData)
                WallpaperService.shared.setAllWithCrossfade(url: localURL)
                try await unsplash.trackDownload(for: photo)
                history.push(photo)
                currentImageData = imageData
                rebuildItems()
            } catch {
                os_log(.error, "Failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func loadPrevious() {
        guard let photo = history.previous() else { return }
        apply(photo)
    }

    @objc private func firstInChannel() {
        guard let photo = history.resetToFirst() else { return }
        apply(photo)
    }

    @objc private func downloadCurrent() {
        guard let data = currentImageData,
              let photo = history.currentPhoto else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.jpeg]
        panel.nameFieldStringValue = "\(photo.id).jpg"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            Task {
                do {
                    try data.write(to: url)
                    try await self.unsplash.trackDownload(for: photo)
                    os_log(.info, "Saved to \(url.path)")
                } catch {
                    os_log(.error, "Download failed: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func toggleRandomize() {
        settings.randomize.toggle()
        rebuildItems()
    }

    @objc private func setUpdateInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? TimeInterval else { return }
        settings.updateInterval = interval
        nextUpdateDate = Date().addingTimeInterval(interval)
        rebuildItems()
    }

    @objc private func selectChannel(_ sender: NSMenuItem) {
        guard let channel = sender.representedObject as? Channel else { return }
        activeChannel = channel
        prefetchedWallpaper = nil
        if let photo = history.resetToFirst() {
            apply(photo)
        }
        rebuildItems()
    }

    @objc private func openLink(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openSettings() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "window.settings".localized
        win.contentView = NSHostingView(rootView: SettingsView())
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        settingsWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openChannelManager() {
        if let existing = channelManagerWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let binding = Binding<[Channel]>(
            get: { [weak self] in self?.channels ?? [] },
            set: { [weak self] in self?.channels = $0 }
        )
        let view = ChannelManagerView(channels: binding) { [weak self] in
            self?.persistChannels()
            self?.rebuildItems()
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "window.manage_channels".localized
        win.contentView = NSHostingView(rootView: view)
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        channelManagerWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        if let existing = aboutWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "window.about".localized
        win.contentView = NSHostingView(rootView: AboutView())
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        aboutWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow { settingsWindow = nil }
        if window === channelManagerWindow { channelManagerWindow = nil }
        if window === aboutWindow { aboutWindow = nil }
    }

    // MARK: - Helpers

    private func apply(_ photo: UnsplashPhoto) {
        Task {
            do {
                guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
                let screenWidth = Int((screen.frame.width * screen.backingScaleFactor).rounded(.up))
                let imageData = try await unsplash.downloadImage(from: unsplash.wallpaperURL(from: photo, screenWidth: screenWidth))
                let localURL = saveTempImage(imageData)
                try WallpaperService.shared.setWithCrossfade(url: localURL, for: screen)
                try await unsplash.trackDownload(for: photo)
                currentImageData = imageData
                nextUpdateDate = Date().addingTimeInterval(settings.updateInterval)
                rebuildItems()
            } catch {
                os_log(.error, "Apply failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Persistence

    private func persistChannels() {
        if let data = try? JSONEncoder().encode(channels) {
            UserDefaults.standard.set(data, forKey: "channels")
        }
        UserDefaults.standard.set(activeChannel.id.uuidString, forKey: "activeChannelID")
    }

    private func loadChannels() {
        guard let data = UserDefaults.standard.data(forKey: "channels"),
              let loaded = try? JSONDecoder().decode([Channel].self, from: data),
              !loaded.isEmpty else {
            channels = Channel.defaultChannels
            return
        }
        channels = loaded
        if let savedID = UserDefaults.standard.string(forKey: "activeChannelID"),
           let channel = channels.first(where: { $0.id.uuidString == savedID }) {
            activeChannel = channel
        } else {
            activeChannel = channels[0]
        }
    }
}
