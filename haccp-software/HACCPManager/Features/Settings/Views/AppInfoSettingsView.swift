import SwiftUI

struct AppInfoSettingsView: View {
    var body: some View {
        VStack(spacing: 32) {
            
            VStack(spacing: 16) {
                Image("AppIconPlaceholder") // Replacement if no icon
                    .resizable()
                    .frame(width: 80, height: 80)
                    .background(Color.red)
                    .cornerRadius(18)
                
                VStack(spacing: 4) {
                    Text(AppVersionService.appName)
                        .font(.title2)
                        .fontWeight(.black)
                    Text(AppVersionService.currentVersion)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 20) {
                InfoLinkRow(title: "Termini di Servizio", icon: "doc.text.fill")
                InfoLinkRow(title: "Privacy Policy", icon: "lock.doc.fill")
                InfoLinkRow(title: "Licenze Open Source", icon: "shippingbox.fill")
                InfoLinkRow(title: "Supporto Tecnico", icon: "lifepreserver.fill")
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("FILOSOFIA")
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(.red)
                
                Text("Dati Locali & Privacy")
                    .font(.headline)
                
                Text("HACCP Manager salva tutti i dati critici esclusivamente nella memoria sicura del tuo iPad. Non inviamo log o temperature a server esterni per garantire la massima riservatezza del tuo locale.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineSpacing(4)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

struct InfoLinkRow: View {
    let title: String
    let icon: String
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 24)
                Text(title)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}
