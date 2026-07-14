import Foundation

/// Risolve i modelli vision disponibili sulla chiave Groq (evita ID obsoleti tipo Maverick).
enum GroqVisionModelResolver {
    private static let defaultModels = [
        "meta-llama/llama-4-scout-17b-16e-instruct",
        "qwen/qwen3.6-27b"
    ]

    private static let preferredSubstrings = [
        "llama-4-scout",
        "llama-4-maverick",
        "qwen3.6",
        "qwen/qwen3"
    ]

    private static var cachedByKeyPrefix: [String: [String]] = [:]
    private static let cacheLock = NSLock()

    static func visionModels(apiKey: String) async -> [String] {
        let cacheKey = String(apiKey.prefix(8))
        cacheLock.lock()
        if let cached = cachedByKeyPrefix[cacheKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let resolved = await fetchAvailableVisionModels(apiKey: apiKey)
        cacheLock.lock()
        cachedByKeyPrefix[cacheKey] = resolved
        cacheLock.unlock()
        return resolved
    }

    static func invalidateCache() {
        cacheLock.lock()
        cachedByKeyPrefix.removeAll()
        cacheLock.unlock()
    }

    private static func fetchAvailableVisionModels(apiKey: String) async -> [String] {
        guard !apiKey.isEmpty else { return defaultModels }

        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return defaultModels
            }

            struct ModelsResponse: Decodable {
                struct Model: Decodable { let id: String }
                let data: [Model]
            }

            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let ids = decoded.data.map(\.id)
            let ranked = rank(ids)
            return ranked.isEmpty ? defaultModels : ranked
        } catch {
            return defaultModels
        }
    }

    private static func rank(_ ids: [String]) -> [String] {
        var ordered: [String] = []
        for hint in preferredSubstrings {
            for id in ids where id.localizedCaseInsensitiveContains(hint) && !ordered.contains(id) {
                ordered.append(id)
            }
        }
        for id in ids where id.localizedCaseInsensitiveContains("llama-4") && !ordered.contains(id) {
            ordered.append(id)
        }
        for id in defaultModels where ids.contains(id) && !ordered.contains(id) {
            ordered.append(id)
        }
        return ordered
    }
}
