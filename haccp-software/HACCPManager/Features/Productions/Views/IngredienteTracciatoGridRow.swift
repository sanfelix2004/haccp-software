import SwiftUI

/// Riga: foto, lotto modificabile, alimento in ingresso.
struct IngredienteTracciatoGridRow: View {
    let ingredient: IngredienteTracciato
    let imageData: Data?
    let incomingFoodOptions: [RecipeIngredientOption]
    let onAssignIngredient: (RecipeIngredientOption) -> Void
    let onConfirmLot: (String) -> Void

    @Environment(\.theme) private var theme
    @State private var lotDraft: String = ""

    private var assignedFood: String? {
        ingredient.ingredientNameAssigned?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                photoThumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text("Etichetta #\(ingredient.sequenceIndex + 1)")
                        .font(theme.typography.subheadline.weight(.semibold))
                    if let food = assignedFood {
                        Text(food)
                            .font(theme.typography.caption.weight(.medium))
                            .foregroundStyle(theme.colorSuccess)
                    }
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Lotto")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                HStack(spacing: 10) {
                    TextField("Codice lotto", text: $lotDraft)
                        .font(theme.typography.body.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(theme.colorSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("Salva") { onConfirmLot(lotDraft) }
                        .buttonStyle(.borderedProminent)
                        .disabled(lotDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if assignedFood == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alimento in ingresso")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                    if incomingFoodOptions.isEmpty {
                        Text("Aggiungi alimenti in ingresso dal catalogo.")
                            .font(theme.typography.caption2)
                            .foregroundStyle(theme.colorTextSecondary)
                    } else {
                        RecipeIngredientQuickPicker(
                            options: incomingFoodOptions,
                            style: .chips,
                            onSelect: onAssignIngredient
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(theme.colorSurfaceElevated.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { syncLotDraft() }
        .onChange(of: ingredient.lotCodeExtracted) { _, _ in syncLotDraft() }
    }

    private func syncLotDraft() {
        lotDraft = ingredient.lotCodeExtracted ?? ""
    }

    private var photoThumbnail: some View {
        Group {
            if let data = imageData,
               let thumb = HACCPZoomablePhotoThumbnail(data: data, size: 64, zoomTitle: "Etichetta") {
                thumb
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.colorSurfaceElevated)
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "photo").foregroundStyle(theme.colorTextSecondary))
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
