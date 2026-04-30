import SwiftUI

struct GoodsReceiptMomentSection: View {
    @Binding var receivedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Momento")
                .font(.headline)
                .foregroundColor(.white)
            DatePicker("Data e ora ricezione", selection: $receivedAt)
                .foregroundColor(.white)
        }
    }
}
