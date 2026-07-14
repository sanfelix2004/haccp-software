//
//  HACCPSafeParse.swift
//  Parsing numerico e accesso array sicuri per registri HACCP.
//

import Foundation

enum HACCPSafeParse {

    /// Converte testo temperatura/quantità (virgola o punto) senza crash.
    static func decimal(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    /// Accesso sicuro a un indice di array; ritorna `nil` se fuori range.
    static func element<T>(at index: Int, in array: [T]) -> T? {
        guard index >= 0, index < array.count else { return nil }
        return array[index]
    }

    /// Dizionario da coppie chiave-valore senza crash su chiavi duplicate.
    static func dictionary<Key: Hashable, Value>(
        _ pairs: [(Key, Value)],
        uniquingKeysWith combine: (Value, Value) -> Value = { first, _ in first }
    ) -> [Key: Value] {
        Dictionary(pairs, uniquingKeysWith: combine)
    }

    /// Testo non vuoto per export PDF/CSV.
    static func nonEmptyText(_ value: String?) -> String {
        guard let value else { return "-" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }
}
