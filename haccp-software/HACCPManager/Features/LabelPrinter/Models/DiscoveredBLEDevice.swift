import Foundation

struct DiscoveredBLEDevice: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let rssi: Int

    var signalDescription: String {
        switch rssi {
        case -50...0: return "Ottimo"
        case -70 ..< -50: return "Buono"
        case -85 ..< -70: return "Medio"
        default: return "Debole"
        }
    }
}
