import Foundation

public struct SecuritySettings: Codable {
    var isBiometricsEnabled: Bool = true
    var sessionTimeoutMinutes: Int = 30
    var requirePinOnInactivity: Bool = true
    var requireMasterAuthForCriticalActions: Bool = true
    var maxPinRetries: Int = 5
    var lockAppAfterRetries: Bool = true
    var showLastAccess: Bool = true
}
