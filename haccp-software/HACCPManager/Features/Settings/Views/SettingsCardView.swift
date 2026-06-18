import SwiftUI

struct SettingsCardView: View {
    let section: SettingsSection
    let locked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(ThemeManager.shared.colorPrimary.opacity(0.12))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: section.icon)
                            .font(.title2)
                            .foregroundColor(ThemeManager.shared.colorPrimary)
                    }
                    
                    Spacer()
                    
                    if locked {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.colorWarning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ThemeManager.shared.colorWarning.opacity(0.12))
                            .cornerRadius(4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.rawValue)
                        .font(.headline)
                        .foregroundColor(ThemeManager.shared.colorTextPrimary)
                    
                    Text(section.description)
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.colorTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ThemeManager.shared.colorDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
