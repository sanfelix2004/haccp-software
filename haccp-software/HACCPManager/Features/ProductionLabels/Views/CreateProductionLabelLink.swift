import SwiftUI

/// Azione opzionale per creare un'etichetta con QR da un record HACCP.
struct CreateProductionLabelLink: View {
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Label("Crea etichetta", systemImage: "tag.fill")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorPrimary)
        }
        .buttonStyle(.plain)
    }
}
