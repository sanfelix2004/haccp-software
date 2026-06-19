import Foundation

enum EmailValidator {
    static func isValid(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
