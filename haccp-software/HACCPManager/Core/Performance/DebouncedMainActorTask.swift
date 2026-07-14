//
//  DebouncedMainActorTask.swift
//  Coalescing di operazioni ripetute (es. salvataggio impostazioni).
//

import Foundation

@MainActor
final class DebouncedMainActorTask {
    private var task: Task<Void, Never>?
    private let delayNanoseconds: UInt64

    init(milliseconds: UInt64 = 400) {
        delayNanoseconds = milliseconds * 1_000_000
    }

    func schedule(_ operation: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            operation()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
