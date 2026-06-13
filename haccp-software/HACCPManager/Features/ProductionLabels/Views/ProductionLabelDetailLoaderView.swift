import SwiftUI
import SwiftData

/// Carica l'etichetta per ID — evita schermata vuota dopo scansione QR.
struct ProductionLabelDetailLoaderView: View {
    let labelId: UUID
    let restaurantId: UUID?
    let restaurantName: String
    let user: LocalUser
    let onChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var label: ProductionLabelRecord?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let label {
                ProductionLabelDetailView(
                    label: label,
                    restaurantName: restaurantName,
                    user: user,
                    onChanged: onChanged
                )
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Etichetta non trovata", systemImage: "tag.slash")
                } description: {
                    Text(errorMessage)
                }
            } else {
                ProgressView("Caricamento etichetta…")
            }
        }
        .task(id: labelId) {
            await loadLabel()
        }
    }

    @MainActor
    private func loadLabel() async {
        errorMessage = nil
        label = nil
        do {
            guard let fetched = try ProductionLabelLookupService.fetchLabel(
                id: labelId,
                restaurantId: restaurantId,
                context: modelContext
            ) else {
                errorMessage = "Etichetta non trovata nel ristorante attivo."
                return
            }
            label = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
