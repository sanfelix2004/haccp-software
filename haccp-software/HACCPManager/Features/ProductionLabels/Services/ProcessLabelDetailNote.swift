import Foundation

/// Codifica Ti / Tf / durata nel campo `temperatureNote` delle etichette di processo.
enum ProcessLabelDetailNote {
    static func encode(initial: Double?, final: Double?, durationText: String?) -> String {
        var parts: [String] = []
        if let initial {
            parts.append(String(format: "Ti %.0f", initial))
        }
        if let final {
            parts.append(String(format: "Tf %.0f", final))
        }
        if let durationText {
            let trimmed = durationText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed != "—" {
                parts.append("Dur \(compactDuration(trimmed))")
            }
        }
        return parts.joined(separator: " · ")
    }

    /// Frammenti da stampare su righe separate (Ti+Tf insieme, poi Dur).
    static func printFragments(from note: String?) -> [String] {
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else {
            return []
        }

        let tokens = note
            .components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if tokens.isEmpty {
            return [note]
        }

        var temps: [String] = []
        var duration: String?
        var other: [String] = []

        for token in tokens {
            let upper = token.uppercased()
            if upper.hasPrefix("TI") || upper.hasPrefix("TF") {
                temps.append(token.replacingOccurrences(of: "°", with: ""))
            } else if upper.hasPrefix("DUR") {
                duration = token
            } else {
                other.append(token)
            }
        }

        var lines: [String] = []
        if !temps.isEmpty {
            lines.append(temps.joined(separator: " "))
        }
        if let duration {
            lines.append(duration)
        }
        lines.append(contentsOf: other)
        return lines
    }

    private static func compactDuration(_ text: String) -> String {
        text
            .replacingOccurrences(of: " min", with: "m")
            .replacingOccurrences(of: " sec", with: "s")
            .replacingOccurrences(of: " ", with: "")
    }
}
