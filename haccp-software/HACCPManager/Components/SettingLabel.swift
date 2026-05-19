import SwiftUI

/// Riga impostazioni con icona e testo leggibile su tema chiaro.
struct SettingLabel: View {
    let title: String
    let icon: String
    var description: String? = nil

    private var theme: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(theme.colorPrimary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                if let description, !description.isEmpty {
                    Text(description)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
        }
    }
}
