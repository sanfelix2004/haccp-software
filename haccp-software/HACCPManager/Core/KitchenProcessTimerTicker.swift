//
//  KitchenProcessTimerTicker.swift
//  Timer 1s condiviso per bubble overlay cucina (decongelamento / abbattimento).
//

import Combine
import Foundation

enum KitchenProcessTimerTicker {
    private static let interval: TimeInterval = 1

    /// Avvia il tick se non già attivo. Ritorna `true` quando viene creato un nuovo timer.
    static func start(
        _ cancellable: inout AnyCancellable?,
        onTick: @escaping (Date) -> Void
    ) {
        guard cancellable == nil else { return }
        cancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink(receiveValue: onTick)
    }

    static func stop(_ cancellable: inout AnyCancellable?) {
        cancellable?.cancel()
        cancellable = nil
    }
}
