import SwiftUI

/// Campo giorni conservazione con tastierino numerico (solo catalogo piatti).
struct ShelfLifeDaysNumberField: View {
    @Binding var days: Int
    var label: String = "Durata"

    @State private var text: String

    init(days: Binding<Int>, label: String = "Durata") {
        _days = days
        _text = State(initialValue: String(days.wrappedValue))
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 80)
            Text("gg")
                .foregroundStyle(.secondary)
        }
        .onChange(of: text) { _, newValue in
            let digits = newValue.filter(\.isNumber)
            if digits != newValue {
                text = digits
            }
            guard let value = Int(digits), (1...365).contains(value) else { return }
            if days != value {
                days = value
            }
        }
        .onChange(of: days) { _, newValue in
            let normalized = String(newValue)
            if text != normalized {
                text = normalized
            }
        }
    }
}
