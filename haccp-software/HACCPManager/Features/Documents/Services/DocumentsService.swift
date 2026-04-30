import Foundation
import SwiftData

struct DocumentsService {
    private let defaultFolders: [String] = [
        "Analisi microbiologiche",
        "Approvvigionamento acqua",
        "Diagnostica sorveglianza PMS",
        "Documenti ufficiali",
        "Schede tecniche prodotti di pulizia",
        "Pulizie quotidiane cucina",
        "Parametri soluzione",
        "Personale",
        "Piano lotta infestanti",
        "Piano pulizia e disinfezione"
    ]

    func ensureDefaultFolders(
        restaurantId: UUID,
        user: LocalUser,
        existingFolders: [DocumentFolder],
        modelContext: ModelContext
    ) {
        let existingNames = Set(existingFolders.map(\.name))
        for name in defaultFolders where !existingNames.contains(name) {
            modelContext.insert(
                DocumentFolder(
                    restaurantId: restaurantId,
                    name: name,
                    createdByUserId: user.id,
                    createdByNameSnapshot: user.name
                )
            )
        }
        try? modelContext.save()
    }
}
