import SwiftUI

struct GoodsReceiptMomentSection: View {
    @Binding var receivedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Momento")
                .font(.headline)
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
            DatePicker("Data e ora ricezione", selection: $receivedAt)
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
        }
    }
}
