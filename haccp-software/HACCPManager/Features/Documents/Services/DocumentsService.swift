import Foundation
import SwiftData

/// Creazione cartelle archivio: `{Ristorante} / Mensili / Singoli|Combinati / {Modulo}`.
struct DocumentsService {
    private static let legacyPeriodRootNames: Set<String> = [
        "Giornalieri", "Settimanali", "Annuali", "Non conformità", "Mensili"
    ]

    private struct FolderTemplate {
        let name: String
        let type: DocumentFolderType
        let order: Int
        let parentPath: String?
    }

    private func folderTemplates(venueName: String) -> [FolderTemplate] {
        var list: [FolderTemplate] = []
        let period = DocumentArchiveLayout.monthlyPeriodName
        var order = 0

        list.append(FolderTemplate(name: venueName, type: .root, order: order, parentPath: nil))
        order += 1
        list.append(FolderTemplate(name: period, type: .period, order: order, parentPath: venueName))
        order += 1
        list.append(FolderTemplate(
            name: DocumentArchiveLayout.singoliGroup,
            type: .module,
            order: order,
            parentPath: "\(venueName)/\(period)"
        ))
        order += 1
        list.append(FolderTemplate(
            name: DocumentArchiveLayout.combinatiGroup,
            type: .module,
            order: order,
            parentPath: "\(venueName)/\(period)"
        ))
        order += 1

        for title in DocumentArchiveLayout.singleModuleFolderTitles {
            list.append(FolderTemplate(
                name: title,
                type: .module,
                order: order,
                parentPath: "\(venueName)/\(period)/\(DocumentArchiveLayout.singoliGroup)"
            ))
            order += 1
        }

        for title in DocumentArchiveLayout.combinedModuleFolderTitles {
            list.append(FolderTemplate(
                name: title,
                type: .module,
                order: order,
                parentPath: "\(venueName)/\(period)/\(DocumentArchiveLayout.combinatiGroup)"
            ))
            order += 1
        }

        list.append(FolderTemplate(
            name: DocumentArchiveLayout.legacyReportsArchiveFolderName,
            type: .archive,
            order: order,
            parentPath: "\(venueName)/\(period)/\(DocumentArchiveLayout.combinatiGroup)"
        ))

        return list
    }

    func ensureDefaultFolders(
        restaurantId: UUID,
        restaurantDisplayName: String,
        user: LocalUser,
        existingFolders: [DocumentFolder],
        existingItems: [DocumentItem],
        modelContext: ModelContext
    ) {
        let venueName = LocalDocumentStorageService.sanitizeFolderName(restaurantDisplayName)
        let restaurantItems = existingItems.filter { $0.restaurantId == restaurantId }
        var restaurantFolders = existingFolders.filter { $0.restaurantId == restaurantId }

        // Migra prima il layout legacy, così non si crea un secondo «Mensili» sotto il ristorante.
        restaurantFolders = migrateArchiveLayout(
            restaurantId: restaurantId,
            venueFolderName: venueName,
            folders: restaurantFolders,
            items: restaurantItems,
            modelContext: modelContext,
            user: user
        )

        let templates = folderTemplates(venueName: venueName).sorted {
            if $0.parentPath == $1.parentPath { return $0.order < $1.order }
            return depth(of: $0.parentPath) < depth(of: $1.parentPath)
        }

        var indexByKey: [String: DocumentFolder] = [:]
        for folder in restaurantFolders {
            indexByKey[folderKey(name: folder.name, parentId: folder.parentId)] = folder
        }

        for template in templates {
            let parentId = resolveParentId(for: template.parentPath, indexByKey: indexByKey)
            let key = folderKey(name: template.name, parentId: parentId)
            if indexByKey[key] != nil { continue }
            let folder = DocumentFolder(
                restaurantId: restaurantId,
                name: template.name,
                type: template.type,
                parentId: parentId,
                orderIndex: template.order,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
            modelContext.insert(folder)
            indexByKey[key] = folder
            restaurantFolders.append(folder)
        }

        retireDeprecatedModuleFolders(
            venueFolderName: venueName,
            restaurantDisplayName: restaurantDisplayName,
            folders: &restaurantFolders,
            items: restaurantItems,
            modelContext: modelContext,
            user: user
        )

        deduplicateSiblingFolders(
            folders: &restaurantFolders,
            items: restaurantItems,
            modelContext: modelContext
        )

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Salvataggio cartelle archivio fallito: \(error.localizedDescription)")
        }
    }

    private func depth(of parentPath: String?) -> Int {
        guard let parentPath, !parentPath.isEmpty else { return 0 }
        return parentPath.split(separator: "/").count
    }

    private func resolveParentId(for parentPath: String?, indexByKey: [String: DocumentFolder]) -> UUID? {
        guard let parentPath, !parentPath.isEmpty else { return nil }
        let parts = parentPath.split(separator: "/").map(String.init)
        var currentParentId: UUID?
        for part in parts {
            let key = folderKey(name: part, parentId: currentParentId)
            guard let folder = indexByKey[key] else { return nil }
            currentParentId = folder.id
        }
        return currentParentId
    }

    private func folderKey(name: String, parentId: UUID?) -> String {
        "\(parentId?.uuidString ?? "root")::\(name.lowercased())"
    }

    @discardableResult
    private func migrateArchiveLayout(
        restaurantId: UUID,
        venueFolderName: String,
        folders: [DocumentFolder],
        items: [DocumentItem],
        modelContext: ModelContext,
        user: LocalUser
    ) -> [DocumentFolder] {
        var workingFolders = folders
        var folderById = Dictionary(uniqueKeysWithValues: workingFolders.map { ($0.id, $0) })

        func refreshFolderIndex() {
            folderById = Dictionary(uniqueKeysWithValues: workingFolders.map { ($0.id, $0) })
        }

        func refreshedPath(for folder: DocumentFolder) -> String {
            var parts = [folder.name]
            var parentId = folder.parentId
            while let id = parentId, let parent = folderById[id] {
                parts.insert(parent.name, at: 0)
                parentId = parent.parentId
            }
            return parts.joined(separator: "/")
        }

        func venueFolder() -> DocumentFolder {
            if let existing = workingFolders.first(where: {
                $0.restaurantId == restaurantId && $0.parentId == nil && $0.name == venueFolderName
            }) {
                return existing
            }
            let venue = DocumentFolder(
                restaurantId: restaurantId,
                name: venueFolderName,
                type: .root,
                parentId: nil,
                orderIndex: 0,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
            modelContext.insert(venue)
            workingFolders.append(venue)
            refreshFolderIndex()
            return venue
        }

        func mensiliUnderVenue(_ venueId: UUID, excluding: UUID? = nil) -> DocumentFolder? {
            workingFolders.first(where: {
                $0.restaurantId == restaurantId
                    && $0.parentId == venueId
                    && $0.name.caseInsensitiveCompare(DocumentArchiveLayout.monthlyPeriodName) == .orderedSame
                    && $0.id != excluding
            })
        }

        // «Mensili» ancora in root → sotto il ristorante (o merge se esiste già).
        if let mensiliAtRoot = workingFolders.first(where: {
            $0.restaurantId == restaurantId
                && $0.parentId == nil
                && $0.name.caseInsensitiveCompare(DocumentArchiveLayout.monthlyPeriodName) == .orderedSame
        }) {
            let venue = venueFolder()
            if let existingMensili = mensiliUnderVenue(venue.id, excluding: mensiliAtRoot.id) {
                mergeFolderContents(
                    from: mensiliAtRoot,
                    into: existingMensili,
                    folders: &workingFolders,
                    items: items,
                    modelContext: modelContext
                )
            } else {
                mensiliAtRoot.parentId = venue.id
            }
            refreshFolderIndex()
        }

        deduplicateSiblingFolders(
            folders: &workingFolders,
            items: items,
            modelContext: modelContext
        )
        refreshFolderIndex()

        var targetPathToId: [String: UUID] = [:]
        for folder in workingFolders {
            let path = refreshedPath(for: folder)
            if path.hasPrefix("\(venueFolderName)/\(DocumentArchiveLayout.monthlyPeriodName)") {
                targetPathToId[path] = folder.id
            }
        }

        let venueRootId = workingFolders.first(where: {
            $0.parentId == nil && $0.name == venueFolderName
        })?.id

        for item in items {
            guard let folder = folderById[item.folderId] else { continue }
            let path = refreshedPath(for: folder)
            if path.hasPrefix("\(venueFolderName)/") { continue }

            if let mapped = mappedTargetPath(path, venueFolderName: venueFolderName),
               let targetId = targetPathToId[mapped] {
                item.folderId = targetId
            } else if let venueRootId {
                item.folderId = venueRootId
            }

            switch item.type {
            case .giornaliero, .settimanale, .annuale, .nonConformita:
                item.type = .mensile
            default:
                break
            }
        }

        refreshFolderIndex()

        let legacyRoots = workingFolders.filter { folder in
            guard folder.parentId == nil else { return false }
            if folder.name == venueFolderName { return false }
            if folder.type == .archive { return false }
            return Self.legacyPeriodRootNames.contains(folder.name)
                || folder.name.caseInsensitiveCompare(DocumentArchiveLayout.monthlyPeriodName) == .orderedSame
        }

        for legacyRoot in legacyRoots {
            if let venueRootId,
               legacyRoot.name.caseInsensitiveCompare(DocumentArchiveLayout.monthlyPeriodName) == .orderedSame,
               let keeper = mensiliUnderVenue(venueRootId) {
                mergeFolderContents(
                    from: legacyRoot,
                    into: keeper,
                    folders: &workingFolders,
                    items: items,
                    modelContext: modelContext
                )
            } else {
                for folder in workingFolders where folder.parentId == legacyRoot.id {
                    folder.parentId = nil
                }
                modelContext.delete(legacyRoot)
                workingFolders.removeAll { $0.id == legacyRoot.id }
            }
        }

        deduplicateSiblingFolders(
            folders: &workingFolders,
            items: items,
            modelContext: modelContext
        )

        return workingFolders
    }

    /// Rimuove cartelle legacy (Ricezione merci, Tracciabilità, HACCP combinato) dall'archivio mensile.
    private func retireDeprecatedModuleFolders(
        venueFolderName: String,
        restaurantDisplayName: String,
        folders: inout [DocumentFolder],
        items: [DocumentItem],
        modelContext: ModelContext,
        user: LocalUser
    ) {
        var pathIndex = DocumentFolderPathIndex(folders: folders)
        let singoli = DocumentArchiveLayout.singoliGroup
        let combinati = DocumentArchiveLayout.combinatiGroup
        let ingressoTitle = DocumentArchiveLayout.ingressoTracciabilitaFolderTitle

        guard let ingressoTarget = pathIndex.folder(
            venueFolderName: venueFolderName,
            monthlyPathSuffix: "\(combinati)/\(ingressoTitle)"
        ) else {
            return
        }

        for title in DocumentArchiveLayout.retiredSingoliFolderTitles {
            guard let deprecated = pathIndex.folder(
                venueFolderName: venueFolderName,
                monthlyPathSuffix: "\(singoli)/\(title)"
            ) else { continue }
            mergeFolderContents(
                from: deprecated,
                into: ingressoTarget,
                folders: &folders,
                items: items,
                modelContext: modelContext
            )
            pathIndex.rebuild(from: folders)
            reassignRetiredICloudPaths(
                items: items,
                restaurantDisplayName: restaurantDisplayName,
                oldGroup: singoli,
                oldModuleFolder: title,
                newGroup: combinati,
                newModuleFolder: ingressoTitle
            )
        }

        guard let legacyArchiveTarget = ensureLegacyArchiveFolder(
            venueFolderName: venueFolderName,
            folders: &folders,
            pathIndex: &pathIndex,
            restaurantId: ingressoTarget.restaurantId,
            user: user,
            modelContext: modelContext
        ) else { return }

        for title in DocumentArchiveLayout.retiredCombinatiFolderTitles {
            guard let deprecated = pathIndex.folder(
                venueFolderName: venueFolderName,
                monthlyPathSuffix: "\(combinati)/\(title)"
            ) else { continue }
            mergeFolderContents(
                from: deprecated,
                into: legacyArchiveTarget,
                folders: &folders,
                items: items,
                modelContext: modelContext
            )
            pathIndex.rebuild(from: folders)
            reassignRetiredICloudPaths(
                items: items,
                restaurantDisplayName: restaurantDisplayName,
                oldGroup: combinati,
                oldModuleFolder: title,
                newGroup: combinati,
                newModuleFolder: DocumentArchiveLayout.legacyReportsArchiveFolderName
            )
        }
    }

    private func ensureLegacyArchiveFolder(
        venueFolderName: String,
        folders: inout [DocumentFolder],
        pathIndex: inout DocumentFolderPathIndex,
        restaurantId: UUID,
        user: LocalUser,
        modelContext: ModelContext
    ) -> DocumentFolder? {
        let combinati = DocumentArchiveLayout.combinatiGroup
        let archiveName = DocumentArchiveLayout.legacyReportsArchiveFolderName
        if let existing = pathIndex.folder(
            venueFolderName: venueFolderName,
            monthlyPathSuffix: "\(combinati)/\(archiveName)"
        ) {
            return existing
        }

        guard let combinatiParent = pathIndex.folder(
            venueFolderName: venueFolderName,
            monthlyPathSuffix: combinati
        ) else {
            return nil
        }

        let archive = DocumentFolder(
            restaurantId: restaurantId,
            name: archiveName,
            type: .archive,
            parentId: combinatiParent.id,
            orderIndex: 999,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(archive)
        folders.append(archive)
        pathIndex.rebuild(from: folders)
        return archive
    }

    private func reassignRetiredICloudPaths(
        items: [DocumentItem],
        restaurantDisplayName: String,
        oldGroup: String,
        oldModuleFolder: String,
        newGroup: String,
        newModuleFolder: String?
    ) {
        for item in items {
            guard let path = item.iCloudRelativePath,
                  let remapped = DocumentArchiveLayout.remappedICloudRelativePath(
                    path,
                    restaurantDisplayName: restaurantDisplayName,
                    oldGroup: oldGroup,
                    oldModuleFolder: oldModuleFolder,
                    newGroup: newGroup,
                    newModuleFolder: newModuleFolder
                  ) else { continue }
            item.iCloudRelativePath = remapped
            item.isSyncedToICloud = false
        }
    }

    private func mergeFolderContents(
        from source: DocumentFolder,
        into destination: DocumentFolder,
        folders: inout [DocumentFolder],
        items: [DocumentItem],
        modelContext: ModelContext
    ) {
        guard source.id != destination.id else { return }

        for folder in folders where folder.parentId == source.id {
            if let existingSibling = folders.first(where: {
                $0.parentId == destination.id
                    && $0.name.caseInsensitiveCompare(folder.name) == .orderedSame
                    && $0.id != folder.id
            }) {
                mergeFolderContents(
                    from: folder,
                    into: existingSibling,
                    folders: &folders,
                    items: items,
                    modelContext: modelContext
                )
            } else {
                folder.parentId = destination.id
            }
        }

        for item in items where item.folderId == source.id {
            item.folderId = destination.id
        }

        modelContext.delete(source)
        folders.removeAll { $0.id == source.id }
    }

    private func deduplicateSiblingFolders(
        folders: inout [DocumentFolder],
        items: [DocumentItem],
        modelContext: ModelContext
    ) {
        var didMerge = true
        while didMerge {
            didMerge = false
            var groups: [String: [DocumentFolder]] = [:]
            for folder in folders {
                let key = folderKey(name: folder.name, parentId: folder.parentId)
                groups[key, default: []].append(folder)
            }

            for siblings in groups.values where siblings.count > 1 {
                let keeper = siblings.min(by: { lhs, rhs in
                    if lhs.orderIndex != rhs.orderIndex { return lhs.orderIndex < rhs.orderIndex }
                    return lhs.createdAt < rhs.createdAt
                }) ?? siblings[0]

                for duplicate in siblings where duplicate.id != keeper.id {
                    mergeFolderContents(
                        from: duplicate,
                        into: keeper,
                        folders: &folders,
                        items: items,
                        modelContext: modelContext
                    )
                    didMerge = true
                }
            }
        }
    }

    private func mappedTargetPath(_ path: String, venueFolderName: String) -> String? {
        let parts = path.split(separator: "/").map(String.init)
        guard let first = parts.first else { return nil }
        if first == venueFolderName { return path }

        if first == "Non conformità" {
            return "\(venueFolderName)/\(DocumentArchiveLayout.monthlyPeriodName)/\(DocumentArchiveLayout.combinatiGroup)/Non conformità"
        }

        if first == DocumentArchiveLayout.monthlyPeriodName {
            return "\(venueFolderName)/\(path)"
        }

        if Self.legacyPeriodRootNames.contains(first) {
            var remapped = parts
            remapped[0] = DocumentArchiveLayout.monthlyPeriodName
            return "\(venueFolderName)/\(remapped.joined(separator: "/"))"
        }

        return nil
    }
}
