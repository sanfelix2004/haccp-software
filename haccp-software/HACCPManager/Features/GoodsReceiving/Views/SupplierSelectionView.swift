import SwiftUI

struct SupplierSelectionView: View {
    let suppliers: [Supplier]
    let selectedSupplierId: UUID?
    let canAddSupplier: Bool
    let canEditSupplier: Bool
    let onSelect: (Supplier) -> Void
    let onAdd: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scelta del fornitore")
                .font(.title3.bold())
                .foregroundColor(.white)
            if suppliers.isEmpty {
                Text("Nessun fornitore configurato")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Aggiungi un fornitore per poter salvare la ricezione. Puoi comunque scegliere il prodotto dall’elenco sotto.")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.9))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(suppliers) { supplier in
                    Button {
                        onSelect(supplier)
                    } label: {
                        Text(supplier.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 82)
                            .padding(8)
                            .background(selectedSupplierId == supplier.id ? Color.red.opacity(0.25) : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedSupplierId == supplier.id ? Color.red : Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                Button("+ Aggiungere", action: onAdd)
                    .buttonStyle(.bordered)
                    .disabled(!canAddSupplier)
                    .opacity(canAddSupplier ? 1 : 0.4)
                Button("Modifica", action: onEdit)
                    .buttonStyle(.bordered)
                    .disabled(!canEditSupplier || selectedSupplierId == nil)
                    .opacity((canEditSupplier && selectedSupplierId != nil) ? 1 : 0.4)
            }
            .tint(.white)
        }
    }
}
