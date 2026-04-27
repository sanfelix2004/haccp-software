import Foundation
import Combine
import Observation
import SwiftUI

@Observable
public class SecurityService {
    public static let shared = SecurityService()
    
    public var failedAttempts: Int = 0
    public var isLocked: Bool = false
    public var lockEndDate: Date? = nil
    
    private var inactivityTimer: AnyCancellable?
    private let settings = SettingsStorageService.shared
    
    public init() {}
    
    func reportFailedAttempt() {
        failedAttempts += 1
        if settings.security.lockAppAfterRetries && failedAttempts >= settings.security.maxPinRetries {
            lockApp()
        }
    }
    
    func reportSuccessfulLogin() {
        failedAttempts = 0
        isLocked = false
        lockEndDate = nil
    }
    
    private func lockApp() {
        isLocked = true
        // Lock for 1 minute for now, scalable
        lockEndDate = Date().addingTimeInterval(60)
        
        // Reset after 1 minute
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            self.isLocked = false
            self.failedAttempts = 0
        }
    }
    
    func checkInactivity(lastActivity: Date, onTimeout: @escaping () -> Void) {
        guard settings.security.requirePinOnInactivity else { return }
        
        let timeoutInterval = TimeInterval(settings.security.sessionTimeoutMinutes * 60)
        if Date().timeIntervalSince(lastActivity) > timeoutInterval {
            onTimeout()
        }
    }
}
