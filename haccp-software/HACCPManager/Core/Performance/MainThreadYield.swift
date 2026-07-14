//
//  MainThreadYield.swift
//  Cede il run loop UI tra fasi di lavoro SwiftData (evita gesture gate timeout).
//

import Foundation

enum MainThreadYield {

    /// Dopo tap sidebar / push navigation (~2–3 frame @ 60fps).
    static func afterNavigation() async {
        try? await Task.sleep(nanoseconds: 48_000_000)
        await Task.yield()
    }

    /// Tra due fetch SwiftData consecutivi sul ModelContext principale.
    static func betweenFetchPhases() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 8_000_000)
    }

    /// Prima di lavoro pesante in background sul MainActor (utility).
    static func beforeHeavyWork() async {
        await Task.yield()
        await Task.yield()
    }

    /// Attende che la sidebar smetta di cambiare (tap rapidi consecutivi).
    static func awaitNavigationSettled(
        getGeneration: @MainActor () -> Int,
        stableDurationNanoseconds: UInt64 = 100_000_000,
        maxWaitNanoseconds: UInt64 = 280_000_000
    ) async {
        let step: UInt64 = 40_000_000
        var waited: UInt64 = 0
        var lastGeneration = await MainActor.run { getGeneration() }
        var stableFor: UInt64 = 0

        while waited < maxWaitNanoseconds {
            if Task.isCancelled { return }
            let currentGeneration = await MainActor.run { getGeneration() }
            if currentGeneration != lastGeneration {
                lastGeneration = currentGeneration
                stableFor = 0
            } else {
                stableFor += step
                if stableFor >= stableDurationNanoseconds { return }
            }
            try? await Task.sleep(nanoseconds: step)
            waited += step
        }
    }
}
