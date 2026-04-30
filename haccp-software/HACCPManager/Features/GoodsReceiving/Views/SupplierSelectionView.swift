import SwiftUI

struct SupplierSelectionView: View {
    let suppliers: [Supplier]
    let selectedSupplierId: UUID?
    let canManageSuppliers: Bool
    let onSelect: (Supplier) -> Void
    let onAdd: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scelta del fornitore")
                .font(.title3.bold())
                .foregroundColor(.white)
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
                Button("+ Aggiungere", action: onAdd).buttonStyle(.bordered)
                Button("Modifica", action: onEdit).buttonStyle(.bordered)
            }
            .tint(.white)
            .opacity(canManageSuppliers ? 1 : 0.4)
            .disabled(!canManageSuppliers)
        }
    }
}
