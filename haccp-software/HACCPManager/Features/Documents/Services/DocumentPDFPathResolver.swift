import Foundation
import SwiftData

/// Risolve i PDF documenti anche se `filePath` assoluto è obsoleto (UUID container iOS).
enum DocumentPDFPathResolver {
    private static let fm = FileManager.default

    /// URL locale del PDF se presente; aggiorna `filePath` / `localFilePresent` quando ripristinato.
    @discardableResult
    static func resolveAndHeal(_ item: DocumentItem) -> URL? {
        if let url = existingURL(for: item) {
            healMetadata(item, resolvedURL: url)
            return url
        }
        item.localFilePresent = false
        return nil
    }

    static func fileExists(_ item: DocumentItem) -> Bool {
        resolveAndHeal(item) != nil
    }

    /// Cerca il file senza mutare il model (check leggero).
    static func existingURL(for item: DocumentItem) -> URL? {
        let candidates = candidateURLs(for: item)
        for url in candidates {
            if fm.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    static func candidateURLs(for item: DocumentItem) -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL) {
            let path = url.path
            guard !path.isEmpty, !seen.contains(path) else { return }
            seen.insert(path)
            urls.append(url)
        }

        let stored = item.filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty {
            append(URL(fileURLWithPath: stored))
        }

        let name = item.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty,
           let dir = try? LocalDocumentStorageService.shared.stablePDFDirectory(restaurantId: item.restaurantId) {
            append(dir.appendingPathComponent(name))

            // Fallback: stesso nome file in sottocartelle legacy.
            if let enumerator = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) {
                while let url = enumerator.nextObject() as? URL {
                    if url.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame {
                        append(url)
                        break
                    }
                }
            }
        }

        return urls
    }

    /// Ripara tutti i documenti del ristorante (path stale → path corrente).
    static func healAll(
        restaurantId: UUID,
        modelContext: ModelContext
    ) {
        let all = ((try? modelContext.fetch(FetchDescriptor<DocumentItem>())) ?? [])
            .filter { $0.restaurantId == restaurantId && $0.format == .pdf }
        var changed = false
        for item in all {
            let beforePath = item.filePath
            let beforePresent = item.localFilePresent
            _ = resolveAndHeal(item)
            if item.filePath != beforePath || item.localFilePresent != beforePresent {
                changed = true
            }
        }
        if changed {
            _ = modelContext.saveSafely(operation: "document-path-heal")
        }
    }

    private static func healMetadata(_ item: DocumentItem, resolvedURL: URL) {
        if item.filePath != resolvedURL.path {
            item.filePath = resolvedURL.path
        }
        if item.fileName != resolvedURL.lastPathComponent,
           !resolvedURL.lastPathComponent.isEmpty {
            item.fileName = resolvedURL.lastPathComponent
        }
        if !item.localFilePresent {
            item.localFilePresent = true
        }
        if item.sizeInBytes <= 0,
           let attrs = try? fm.attributesOfItem(atPath: resolvedURL.path),
           let size = attrs[.size] as? NSNumber {
            item.sizeInBytes = size.int64Value
        }
    }
}
