import AppKit
import OSLog

final class HistoryManager {
    private(set) var history: [UnsplashPhoto] = []
    private var currentIndex: Int = -1
    let maxSize = 20

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < history.count - 1 }
    var currentPhoto: UnsplashPhoto? {
        guard currentIndex >= 0, currentIndex < history.count else { return nil }
        return history[currentIndex]
    }

    func push(_ photo: UnsplashPhoto) {
        // Trim forward history if we're not at the end
        if currentIndex < history.count - 1 {
            history = Array(history.prefix(currentIndex + 1))
        }
        // Avoid consecutive duplicates
        if let last = history.last, last.id == photo.id { return }
        history.append(photo)
        history = Array(history.suffix(maxSize))
        currentIndex = history.count - 1
    }

    func previous() -> UnsplashPhoto? {
        guard canGoBack else { return nil }
        currentIndex -= 1
        return history[currentIndex]
    }

    func next() -> UnsplashPhoto? {
        guard canGoForward else { return nil }
        currentIndex += 1
        return history[currentIndex]
    }

    func resetToFirst() -> UnsplashPhoto? {
        guard !history.isEmpty else { return nil }
        currentIndex = 0
        return history[0]
    }
}
