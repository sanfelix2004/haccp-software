import SwiftUI

struct TemperatureDevicePicker: View {
    let devices: [TemperatureDevice]
    @Binding var selectedDeviceId: UUID?

    var body: some View {
        Menu {
            Button("Tutti i dispositivi") {
                selectedDeviceId = nil
            }
            ForEach(devices) { device in
                Button(device.name) {
                    selectedDeviceId = device.id
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "thermometer")
                Text(selectedTitle)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
        }
    }

    private var selectedTitle: String {
        if let selectedDeviceId, let name = devices.first(where: { $0.id == selectedDeviceId })?.name {
            return name
        }
        return "Tutti i dispositivi"
    }
}
