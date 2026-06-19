import Foundation

/// Indice percorso cartelle archivio — evita duplicazione di `refreshedPath` / lookup.
struct DocumentFolderPathIndex {
    private let folderById: [UUID: DocumentFolder]
    private let folders: [DocumentFolder]

    init(folders: [DocumentFolder]) {
        self.folders = folders
        self.folderById = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
    }

    func path(for folder: DocumentFolder) -> String {
        var parts = [folder.name]
        var parentId = folder.parentId
        while let id = parentId, let parent = folderById[id] {
            parts.insert(parent.name, at: 0)
            parentId = parent.parentId
        }
        return parts.joined(separator: "/")
    }

    func folder(venueFolderName: String, monthlyPathSuffix: String) -> DocumentFolder? {
        let full = "\(venueFolderName)/\(DocumentArchiveLayout.monthlyPeriodName)/\(monthlyPathSuffix)"
        return folders.first { path(for: $0) == full }
    }

    mutating func rebuild(from folders: [DocumentFolder]) {
        self = DocumentFolderPathIndex(folders: folders)
    }
}
