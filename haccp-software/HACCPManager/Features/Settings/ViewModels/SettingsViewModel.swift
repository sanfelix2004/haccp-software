import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
class SettingsViewModel {
    var selectedSection: SettingsSection? = nil
    var pendingSection: SettingsSection? = nil
    var showMasterAuth = false
    var masterOperation: MasterAuthorizationService.Operation = .accessSettings

    private let storage = SettingsStorageService.shared

    func sectionTapped(_ section: SettingsSection, permissions: UserPermissions) {
        if section.isOperatorAccessible {
            selectedSection = section
            return
        }
        switch permissions.resolve(section.requiredPermission) {
        case .allowed:
            selectedSection = section
        case .requiresMaster(let operation):
            pendingSection = section
            masterOperation = operation
            showMasterAuth = true
        }
    }

    func handleMasterAuthorized() {
        if let section = pendingSection {
            PrivilegedSession.shared.elevate(section.requiredPermission)
            selectedSection = section
            pendingSection = nil
        }
        showMasterAuth = false
    }

    func handleMasterCancelled() {
        pendingSection = nil
        showMasterAuth = false
    }
}
