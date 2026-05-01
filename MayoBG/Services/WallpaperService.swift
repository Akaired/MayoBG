import AppKit
import OSLog
import QuartzCore

final class WallpaperService {
    static let shared = WallpaperService()

    private let fileManager = FileManager.default
    // Must live outside the sandbox container so the Dock process can read it.
    private let tempDir = URL(fileURLWithPath: "/var/tmp/MayoBG")
    // Strong references kept until each crossfade animation completes.
    private var overlayWindows: [NSWindow] = []

    private init() {
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    // MARK: - Set wallpaper

    func set(url: URL, for screen: NSScreen) throws {
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue),
            .allowClipping: true,
        ]
        try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
    }

    func setAll(url: URL) {
        for screen in NSScreen.screens {
            do { try set(url: url, for: screen) }
            catch { os_log(.error, "Failed to set wallpaper for screen: \(error.localizedDescription)") }
        }
    }

    // MARK: - Crossfade

    func setWithCrossfade(url newURL: URL, for screen: NSScreen, duration: TimeInterval = 2.5) throws {
        let currentURL = currentWallpaperURL(for: screen)
        let overlay = buildOverlayWindow(screen: screen, imagePath: currentURL)
        overlay.orderFrontRegardless()

        try set(url: newURL, for: screen)

        overlayWindows.append(overlay)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            overlay.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            overlay.close()
            self?.overlayWindows.removeAll { $0 === overlay }
        }
    }

    func setAllWithCrossfade(url newURL: URL, duration: TimeInterval = 2.5) {
        for screen in NSScreen.screens {
            try? setWithCrossfade(url: newURL, for: screen, duration: duration)
        }
    }

    // MARK: - Current wallpaper

    func currentWallpaperURL(for screen: NSScreen) -> URL? {
        NSWorkspace.shared.desktopImageURL(for: screen)
    }

    // MARK: - Private

    private func buildOverlayWindow(screen: NSScreen, imagePath: URL?) -> NSWindow {
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        // Level -1 is below normal app windows but above the desktop.
        win.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        win.isReleasedWhenClosed = false

        let rootView = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        rootView.wantsLayer = true
        win.contentView = rootView

        if let imagePath,
           let image = NSImage(contentsOf: imagePath),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            rootView.layer?.contents = cgImage
            rootView.layer?.contentsGravity = .resizeAspectFill
        }

        return win
    }
}
