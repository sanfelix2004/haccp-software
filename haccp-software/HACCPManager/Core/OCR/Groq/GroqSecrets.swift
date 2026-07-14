import Foundation

/// Chiave Groq di riserva (non scade se creata senza scadenza su console.groq.com).
/// Copia `GroqSecrets.plist.example` → `GroqSecrets.plist` e incolla la chiave organizzazione.
enum GroqSecrets {
    static var bundledApiKey: String? {
        guard let url = Bundle.main.url(forResource: "GroqSecrets", withExtension: "plist"),
              let plist = NSDictionary(contentsOf: url),
              let raw = plist["GROQ_API_KEY"] as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("YOUR_"),
              !trimmed.lowercased().contains("incolla") else {
            return nil
        }
        return trimmed
    }
}
