import SwiftUI

struct GoodsReceiptNotesSection: View {
    @Binding var notes: String
    @Binding var correctiveAction: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appunti").font(.headline).foregroundColor(.white)
            TextField("Note ricezione / anomalie", text: $notes, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.roundedBorder)
            TextField("Azione correttiva (se non conforme)", text: $correctiveAction, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }
    }
}
