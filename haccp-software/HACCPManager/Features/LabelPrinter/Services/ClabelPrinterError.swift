import Foundation

enum ClabelPrinterError: LocalizedError {
    case bluetoothUnavailable
    case bluetoothUnauthorized
    case notConnected
    case characteristicNotFound
    case writeFailed
    case printTimeout

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable: return "Bluetooth non disponibile. Accendilo in Impostazioni."
        case .bluetoothUnauthorized: return "Permesso Bluetooth negato. Abilitalo per HACCP Manager."
        case .notConnected: return "Stampante non connessa. Collegala da Impostazioni → Stampanti."
        case .characteristicNotFound: return "Stampante non compatibile o servizio Bluetooth non trovato."
        case .writeFailed: return "Errore durante l'invio dati alla stampante."
        case .printTimeout: return "Timeout stampa. Verifica carta e accensione stampante."
        }
    }
}
