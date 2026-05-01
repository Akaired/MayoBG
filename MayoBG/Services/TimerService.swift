import Foundation
import OSLog

final class TimerService {
    private var task: Task<Void, Never>?

    var onTick: (@MainActor () async -> Void)?

    func start(interval: TimeInterval, fireImmediately: Bool = true) {
        stop()
        task = Task { [weak self] in
            if fireImmediately {
                guard let onTick = self?.onTick else { return }
                await onTick()
            }
            while !Task.isCancelled {
                guard let self else { break }
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, let onTick = self.onTick else { break }
                await onTick()
            }
        }
    }

    func restart(with interval: TimeInterval) {
        start(interval: interval, fireImmediately: false)
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    deinit {
        stop()
    }
}
