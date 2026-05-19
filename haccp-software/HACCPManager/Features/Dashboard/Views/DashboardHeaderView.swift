import SwiftUI

struct DashboardHeaderView: View {
    let user: LocalUser?
    let restaurant: Restaurant?
    let dateTimeText: String
    let systemStateMessage: String
    var compliancePercent: Int = 94

    @Environment(\.theme) private var theme

    var body: some View {
        GlassCard(elevated: true) {
            VStack(alignment: .leading, spacing: theme.spacing.xl) {
                HStack(alignment: .top, spacing: theme.spacing.xl) {
                    avatar
                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        Text("Bentornato")
                            .font(theme.typography.caption.weight(.semibold))
                            .foregroundStyle(theme.colorTextSecondary)
                            .textCase(.uppercase)
                            .tracking(1)
                        Text(user?.name ?? "Operatore")
                            .font(theme.typography.display)
                            .foregroundStyle(theme.colorTextPrimary)
                            .lineLimit(2)
                        Text("\(user?.role.rawValue ?? "UTENTE") · \(restaurant?.name ?? "Ristorante")")
                            .font(theme.typography.subheadline)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: theme.spacing.sm) {
                        Text(dateTimeText)
                            .font(theme.typography.caption.weight(.semibold))
                            .foregroundStyle(theme.colorTextSecondary)
                            .multilineTextAlignment(.trailing)
                        if user?.role == .master {
                            masterBadge
                        }
                    }
                }

                HStack(spacing: theme.spacing.md) {
                    HACCPBadge(title: "Sistema operativo", style: .conforme, showIcon: true)
                    Text(systemStateMessage)
                        .font(theme.typography.subheadline)
                        .foregroundStyle(theme.colorTextPrimary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var avatar: some View {
        Group {
            if let data = user?.profileImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.colorPrimary, theme.colorPrimary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(user?.name.prefix(1).uppercased() ?? "U")
                        .font(theme.typography.title2)
                        .foregroundStyle(theme.colorTextOnPrimary)
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(Circle().stroke(theme.colorDivider, lineWidth: 1))
        .shadow(color: theme.shadows.subtle.color, radius: theme.shadows.subtle.radius, y: theme.shadows.subtle.y)
    }

    private var masterBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
            Text("MASTER")
                .fontWeight(.black)
                .tracking(1)
        }
        .font(theme.typography.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [theme.colorAccent.opacity(0.9), theme.colorWarning.opacity(0.85)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .foregroundStyle(theme.isDark ? theme.colorTextPrimary : Color(hex: "#1A1D21"))
        .clipShape(Capsule())
    }
}
