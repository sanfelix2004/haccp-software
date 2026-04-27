import LocalAuthentication
import Foundation

class BiometricAuthManager {
    static let shared = BiometricAuthManager()
    
    private init() {}
    
    enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID
    }
    
    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        
        // We must check if biometrics are available AND if the device is capable
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        switch context.biometryType {
        case .touchID: return .touchID
        case .faceID: return .faceID
        case .opticID: return .opticID
        case .none: return .none
        @unknown default: return .none
        }
    }
    
    func authenticate(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    completion(success, authError)
                }
            }
        } else {
            completion(false, error)
        }
    }
}
