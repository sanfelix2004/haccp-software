import Foundation
import SwiftData

/// Creazione cartelle archivio documenti (struttura HACCP professionale).
struct DocumentsService {
    private struct FolderTemplate {
        let name: String
        let type: DocumentFolderType
        let order: Int
        let parentName: String?
    }

    private var folderTemplates: [FolderTemplate] {
        var list: [FolderTemplate] = []
        let moduleNames = ["Ricezione merci", "Tracciabilità", "HACCP combinato"]
        for (rootName, order) in [("Giornalieri", 10), ("Settimanali", 15), ("Mensili", 20)] {
            list.append(FolderTemplate(name: rootName, type: .period, order: order, parentName: nil))
            for (idx, m) in moduleNames.enumerated() {
                list.append(FolderTemplate(name: m, type: .module, order: order + 1 + idx, parentName: rootName))
            }
        }
        list.append(FolderTemplate(name: "Annuali", type: .period, order: 30, parentName: nil))
        list.append(FolderTemplate(name: "HACCP combinato", type: .module, order: 31, parentName: "Annuali"))
        list.append(FolderTemplate(name: "Non conformità", type: .nonConformity, order: 40, parentName: nil))
        return list
    }

    func ensureDefaultFolders(
        restaurantId: UUID,
        user: LocalUser,
        existingFolders: [DocumentFolder],
        existingItems: [DocumentItem],
        modelContext: ModelContext
    ) {
        let templates = folderTemplates
        var indexByKey: [String: DocumentFolder] = [:]
        for folder in existingFolders {
            let key = folderKey(name: folder.name, parentId: folder.parentId)
            indexByKey[key] = folder
        }

        for root in templates.filter({ $0.parentName == nil }) {
            let key = folderKey(name: root.name, parentId: nil)
            if indexByKey[key] != nil { continue }
            let folder = DocumentFolder(
                restaurantId: restaurantId,
                name: root.name,
                type: root.type,
                parentId: nil,
                orderIndex: root.order,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
            modelContext.insert(folder)
            indexByKey[key] = folder
        }

        for child in templates.filter({ $0.parentName != nil }) {
            guard let parentName = child.parentName else { continue }
            let parent = indexByKey[folderKey(name: parentName, parentId: nil)]
            let parentId = parent?.id
            let key = folderKey(name: child.name, parentId: parentId)
            if indexByKey[key] != nil { continue }
            let folder = DocumentFolder(
                restaurantId: restaurantId,
                name: child.name,
                type: child.type,
                parentId: parentId,
                orderIndex: child.order,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
            modelContext.insert(folder)
            indexByKey[key] = folder
        }

        cleanupLegacyTopLevelFolders(
            existingFolders: existingFolders,
            existingItems: existingItems,
            modelContext: modelContext
        )

        try? modelContext.save()
    }

    private func folderKey(name: String, parentId: UUID?) -> String {
        "\(parentId?.uuidString ?? "root")::\(name.lowercased())"
    }

    private func cleanupLegacyTopLevelFolders(
        existingFolders: [DocumentFolder],
        existingItems: [DocumentItem],
        modelContext: ModelContext
    ) {
        let allowedRoots = Set(folderTemplates.filter { $0.parentName == nil }.map(\.name))
        let legacyRoots = existingFolders.filter {
            $0.parentId == nil && !allowedRoots.contains($0.name)
        }

        for legacy in legacyRoots {
            let hasChildren = existingFolders.contains(where: { $0.parentId == legacy.id })
            let hasItems = existingItems.contains(where: { $0.folderId == legacy.id })
            if !hasChildren && !hasItems {
                modelContext.delete(legacy)
            }
        }
    }
}
