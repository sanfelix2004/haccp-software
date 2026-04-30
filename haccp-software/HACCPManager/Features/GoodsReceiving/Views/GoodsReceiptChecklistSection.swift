import SwiftUI

struct GoodsReceiptChecklistSection: View {
    @Binding var checklistResults: [GoodsReceiptChecklistResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lista di controllo").font(.headline).foregroundColor(.white)
            ForEach($checklistResults) { $item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.item.rawValue).foregroundColor(.white)
                    HStack {
                        pickerButton(title: "OK", value: .ok, item: $item)
                        pickerButton(title: "NON OK", value: .notOk, item: $item)
                        pickerButton(title: "N/A", value: .notApplicable, item: $item)
                    }
                    if item.value == .notOk {
                        TextField("Nota obbligatoria", text: Binding(get: { item.note ?? "" }, set: { item.note = $0 }))
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
            }
        }
    }

    private func pickerButton(title: String, value: GoodsChecklistResultValue, item: Binding<GoodsReceiptChecklistResult>) -> some View {
        Button {
            item.wrappedValue.value = value
        } label: {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(item.wrappedValue.value == value ? .white : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(item.wrappedValue.value == value ? Color.red.opacity(0.65) : Color.white.opacity(0.08))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
