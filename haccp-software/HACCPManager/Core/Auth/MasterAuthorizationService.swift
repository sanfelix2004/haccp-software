import Foundation
import Combine

final class MasterAuthorizationService {
    static let shared = MasterAuthorizationService()

    enum Operation: String {
        case masterLogin
        case createUser
        case editUser
        case changeRole
        case deleteUser
        case resetDatabase
        case privilegedAction
        case accessSettings
        case editRestaurantInfo
        case manageTemperatureDevices
        case manageChecklistTemplates

        var localizedReason: String {
            switch self {
            case .masterLogin:
                return "Autorizza l'accesso come MASTER"
            case .createUser:
                return "Autorizza la creazione di un nuovo collaboratore"
            case .editUser:
                return "Autorizza la modifica di un collaboratore"
            case .changeRole:
                return "Autorizza il cambio ruolo di un collaboratore"
            case .deleteUser:
                return "Autorizza la cancellazione di un collaboratore"
            case .resetDatabase:
                return "Autorizza il reset completo del sistema"
            case .privilegedAction:
                return "Autorizza questa operazione riservata al MASTER"
            case .accessSettings:
                return "Autorizza l'accesso alle impostazioni riservate"
            case .editRestaurantInfo:
                return "Autorizza la modifica dei dati del ristorante"
            case .manageTemperatureDevices:
                return "Autorizza la gestione dei dispositivi temperatura"
            case .manageChecklistTemplates:
                return "Autorizza la gestione critica delle checklist"
            }
        }
    }

    private init() {}

    var biometricType: BiometricAuthManager.BiometricType {
        BiometricAuthManager.shared.biometricType
    }

    var isBiometricAvailable: Bool {
        biometricType != .none
    }

    var biometricLabel: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometria"
        }
    }

    var biometricSymbolName: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock"
        }
    }

    func authenticateBiometrically(
        for operation: Operation,
        completion: @escaping (Bool) -> Void
    ) {
        BiometricAuthManager.shared.authenticate(reason: operation.localizedReason) { success, _ in
            completion(success)
        }
    }
}
