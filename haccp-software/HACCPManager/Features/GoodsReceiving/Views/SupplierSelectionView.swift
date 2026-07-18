import SwiftUI

// MARK: - SupplierSelectionView
// Griglia di selezione fornitore. Componente puramente presentazionale:
// non conosce il database, comunica solo tramite callback.

struct SupplierSelectionView: View {
    let suppliers: [Supplier]
    let selectedSupplierId: UUID?
    let canAddSupplier: Bool
    let canEditSupplier: Bool
    let onSelect: (Supplier) -> Void
    let onAdd: () -> Void
    let onEdit: () -> Void

    // BUG FIX: sostituito `Color.red` con il colore semantico dal ThemeManager.
    // Il rosso fisso non si adattava al tema scuro/chiaro e sembrava un errore UI.
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scelta del fornitore")
                .font(.title3.bold())
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)

            if suppliers.isEmpty {
                emptyState
            } else {
                supplierGrid
            }

            actionBar
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nessun fornitore configurato")
                .font(.subheadline)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            Text("Aggiungi un fornitore per poter salvare la ricezione.")
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary.opacity(0.8))
        }
        // Animazione di comparsa quando viene aggiunto il primo fornitore.
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
    }

    private var supplierGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
            spacing: 12
        ) {
            ForEach(suppliers) { supplier in
                supplierCard(supplier)
            }
        }
        // Animazione per l'inserimento di nuovi fornitori nel grid (optimistic update visivo).
        .animation(.easeOut(duration: 0.25), value: suppliers.map(\.id))
    }

    private func supplierCard(_ supplier: Supplier) -> some View {
        let isSelected = selectedSupplierId == supplier.id
        return Button {
            onSelect(supplier)
        } label: {
            Text(supplier.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    isSelected
                    ? theme.colorPrimary
                    : ThemeManager.shared.colorTextPrimary
                )
                .frame(maxWidth: .infinity, minHeight: 72)
                .padding(8)
                .background(
                    isSelected
                    ? theme.colorPrimary.opacity(0.15)
                    : ThemeManager.shared.colorSurfaceElevated
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? theme.colorPrimary : ThemeManager.shared.colorDivider,
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .cornerRadius(12)
                // Micro-animazione feedback alla selezione.
                .scaleEffect(isSelected ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        // Accessibilità: indica se la card è selezionata ai screen reader.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("Fornitore: \(supplier.name)\(isSelected ? ", selezionato" : "")")
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(action: onAdd) {
                Label("Aggiungi", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .disabled(!canAddSupplier)
            .opacity(canAddSupplier ? 1 : 0.4)

            Button(action: onEdit) {
                Label("Modifica", systemImage: "pencil")
            }
            .buttonStyle(.bordered)
            .disabled(!canEditSupplier || selectedSupplierId == nil)
            .opacity((canEditSupplier && selectedSupplierId != nil) ? 1 : 0.4)
        }
        .tint(ThemeManager.shared.colorPrimary)
    }
}
