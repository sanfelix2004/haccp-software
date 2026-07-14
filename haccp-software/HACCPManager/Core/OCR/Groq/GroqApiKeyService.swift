import Foundation

/// Risoluzione chiavi Groq: preferenza utente → chiave di riserva nel bundle.
enum GroqApiKeyService {

    /// Chiave impostata in Impostazioni → HACCP.
    static func userKey() -> String {
        SettingsStorageService.shared.haccp.groqApiKey?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Chiave organizzazione in `GroqSecrets.plist` (gitignored).
    static func bundledFallbackKey() -> String? {
        GroqSecrets.bundledApiKey
    }

    /// Coppia primary/fallback per le chiamate API (evita duplicati).
    static func resolvedKeys() -> (primary: String, fallback: String?) {
        let user = userKey()
        let bundled = bundledFallbackKey()

        if user.isEmpty {
            return (bundled ?? "", nil)
        }
        if let bundled, bundled != user {
            return (user, bundled)
        }
        return (user, nil)
    }

    static func hasAnyKey() -> Bool {
        let keys = resolvedKeys()
        return !keys.primary.isEmpty || !(keys.fallback ?? "").isEmpty
    }

    /// Precarica l'elenco modelli vision Groq (evita attesa al primo scatto).
    static func prefetchVisionModels() {
        let keys = resolvedKeys()
        guard !keys.primary.isEmpty else { return }
        Task.detached(priority: .utility) {
            _ = await GroqVisionModelResolver.visionModels(apiKey: keys.primary)
        }
    }

    static func isAuthError(statusCode: Int, detail: String) -> Bool {
        if statusCode == 401 || statusCode == 403 { return true }
        let lower = detail.lowercased()
        return lower.contains("invalid api key")
            || lower.contains("invalid_api_key")
            || lower.contains("incorrect api key")
            || lower.contains("authentication")
            || lower.contains("unauthorized")
    }

    static func isModelNotFoundError(statusCode: Int, detail: String) -> Bool {
        guard statusCode == 404 else { return false }
        let lower = detail.lowercased()
        return lower.contains("model_not_found")
            || lower.contains("does not exist")
            || lower.contains("do not have access")
    }

    /// Messaggio operatore quando entrambe le chiavi falliscono.
    static func authFailureMessage(statusCode: Int) -> String {
        """
        Chiave Groq non valida o revocata (\(statusCode)). \
        Aggiorna la chiave in Impostazioni → HACCP oppure chiedi all'amministratore di aggiornare GroqSecrets.plist. \
        Le chiavi si creano su console.groq.com (l'app non può generarle da sola).
        """
    }
}
