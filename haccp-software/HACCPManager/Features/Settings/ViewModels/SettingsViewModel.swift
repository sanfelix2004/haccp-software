import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
class SettingsViewModel {
    var selectedSection: SettingsSection? = nil
    var showMasterAuth = false
    var pendingSection: SettingsSection? = nil
    
    private let storage = SettingsStorageService.shared
    
    func sectionTapped(_ section: SettingsSection, isMaster: Bool) {
        if section.requiresMaster && !isMaster {
            pendingSection = section
            showMasterAuth = true
        } else {
            selectedSection = section
        }
    }
    
    func handleMasterAuthorized() {
        if let section = pendingSection {
            selectedSection = section
            pendingSection = nil
        }
        showMasterAuth = false
    }
}
