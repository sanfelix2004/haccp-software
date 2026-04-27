import SwiftUI

struct DashboardHeaderView: View {
    let user: LocalUser?
    let restaurant: Restaurant?
    let dateTimeText: String
    let systemStateMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 20) {
                        // Global Avatar Integration
                        ZStack {
                            if let data = user?.profileImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            } else {
                                Circle()
                                    .fill(Color(hex: user?.avatarColorHex ?? "#FF0000"))
                                    .frame(width: 60, height: 60)
                                Text(user?.name.prefix(1).uppercased() ?? "U")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                            }
                        }
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bentornato, \(user?.name ?? "Operatore")")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("\(user?.role.rawValue ?? "UTENTE")  •  \(restaurant?.name ?? "Nessun Ristorante")")
                                .font(.headline)
                                .foregroundColor(Color.white.opacity(0.78))
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    Text(dateTimeText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.85))
                    if user?.role == .master {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                            Text("MASTER")
                                .fontWeight(.black)
                                .tracking(1)
                            Image(systemName: "sparkle")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(LinearGradient(colors: [Color(hex: "#FFD700"), Color(hex: "#D4AF37")], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "#FFD700").opacity(0.35), radius: 8)
                    }
                }
            }

            HStack(spacing: 12) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .shadow(color: .green.opacity(0.5), radius: 4)
                Text(systemStateMessage)
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
