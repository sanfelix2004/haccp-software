//
//  MainActorDataLoad.swift
//  Coordinamento reload async su MainActor — evita isLoading bloccato dopo cancel.
//

import Foundation

@MainActor
enum MainActorDataLoad {

    /// Incrementa la generazione di reload; ritorna il token da usare nel Task.
    static func begin(generation: inout Int) -> Int {
        generation += 1
        return generation
    }

    static func isCurrent(generation: Int, activeGeneration: Int) -> Bool {
        generation == activeGeneration
    }
}
