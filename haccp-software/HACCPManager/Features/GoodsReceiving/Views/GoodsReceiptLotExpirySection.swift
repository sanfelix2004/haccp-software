import SwiftUI

struct GoodsReceiptLotExpirySection: View {
    let requirement: GoodsReceiptRequirement
    @Binding var lotNumber: String
    @Binding var includeExpiryDate: Bool
    @Binding var expiryDate: Date
    @Binding var includeProductionDate: Bool
    @Binding var productionDate: Date
    @Binding var quantityText: String
    @Binding var unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("N lotto / scadenza").font(.headline).foregroundStyle(ThemeManager.shared.colorTextPrimary)

            TextField("Numero lotto", text: $lotNumber)
                .textFieldStyle(.roundedBorder)
            if requirement.requiresExpiryDate {
                Toggle("Data scadenza", isOn: $includeExpiryDate).tint(.red)
                if includeExpiryDate {
                    DatePicker("Scadenza", selection: $expiryDate, displayedComponents: .date)
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                }
            }

            if requirement.requiresProductionDate {
                Toggle("Data produzione", isOn: $includeProductionDate).tint(.red)
                if includeProductionDate {
                    DatePicker("Produzione", selection: $productionDate, displayedComponents: .date)
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                }
            }

            HStack {
                TextField("Quantita", text: $quantityText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                TextField("Unita", text: $unit)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}
