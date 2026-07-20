import Foundation

// MARK: - Collaboratori (non MASTER)
//
// Ruoli operativi differenziati:
// • Cucina — moduli cucina (temp, pulizie, abbattimento, defrost, olio, etichette, catalogo, checklist, tracciabilità, scadenze)
// • Sala — ricezione, alimenti in ingresso, scadenze, checklist (+ lettura dashboard/avvisi/storia/grafici)
// • Operatore HACCP — tutti i moduli operativi
//
// Riservato a MASTER / titolare (e in parte manager): documenti PDF, utenti, sicurezza,
// backup dati, cambio ristorante, cancellazione storico pulizie.
//
// VIEWER: sola lettura (nessuna registrazione senza PIN MASTER).

/// Operazioni e ambiti controllati per ruolo collaboratore.
enum AppPermission: Hashable {
    case executeRecords
    case manageUsers
    case manageRestaurantSettings
    case manageHACCPParameters
    case manageSecuritySettings
    case manageDataAndBackup
    case managePrinters
    case manageTemperatureDevices
    case manageChecklistTemplates
    case manageCleaningConfiguration
    case manageOilControlPoints
    case manageSuppliers
    case manageProductionLibrary
    case manageIncomingFoodCatalog
    case deleteOperationalRecords
    case deleteTraceabilityRecords
    /// MASTER: nasconde/corregge voci nello storico operativo (Documenti restano intatti).
    case manageHistory
    case manageDocuments
    case clearCleaningHistory
    case switchRestaurant
    case accessModule(SidebarItem)
}

/// Matrice autorizzazioni — unica fonte di verità per tutta l'app.
struct UserPermissions: Equatable {
    let role: UserRole

    var isMaster: Bool { role == .master }
    var isViewer: Bool { role == .viewer }
    var isOperator: Bool { role == .haccpOperator }
    var isManagement: Bool { role == .master || role == .boss || role == .manager }
    /// Collaboratore operativo in cucina/sala (non titolare, non sola lettura).
    var isExternalCollaborator: Bool {
        role == .cucina || role == .cameriere || role == .haccpOperator
    }

    // MARK: - Capacità dirette (senza PIN MASTER)

    func can(_ permission: AppPermission) -> Bool {
        switch permission {
        case .executeRecords:
            return role != .viewer

        case .manageUsers:
            return role == .master

        case .manageRestaurantSettings, .manageDataAndBackup:
            return role == .master || role == .boss

        case .manageHACCPParameters, .managePrinters:
            return role == .master || role == .boss || role == .manager

        case .manageSecuritySettings:
            return role == .master

        case .manageTemperatureDevices:
            return canConfigureKitchenInfrastructure

        case .manageChecklistTemplates:
            return canConfigureChecklists

        case .manageCleaningConfiguration:
            return canConfigureKitchenInfrastructure

        case .manageOilControlPoints:
            return canConfigureKitchenInfrastructure

        case .manageSuppliers:
            return canManageGoodsSide

        case .manageProductionLibrary:
            return canConfigureKitchenInfrastructure

        case .manageIncomingFoodCatalog:
            return canManageGoodsSide

        case .deleteOperationalRecords, .deleteTraceabilityRecords:
            return role != .viewer

        case .manageHistory:
            return role == .master || role == .boss

        case .manageDocuments:
            return role == .master || role == .boss

        case .clearCleaningHistory:
            return role == .master || role == .boss

        case .switchRestaurant:
            return role == .master || role == .boss

        case .accessModule(let item):
            return canAccessModule(item)
        }
    }

    func canAccessModule(_ item: SidebarItem) -> Bool {
        if isMaster { return true }
        switch item {
        case .dashboard, .history, .alerts, .settings, .analytics:
            return true
        case .documents:
            return role == .master || role == .boss
        case .users:
            return false
        case .traceability, .fridges, .cleaningControl, .blastChilling,
             .expiryControl, .defrost, .oilControl, .productionLabels,
             .goodsReceiving, .checklist, .productionCatalog, .incomingFoodCatalog:
            return operationalModules.contains(item)
        }
    }

    func canAccessSettingsSection(_ section: SettingsSection) -> Bool {
        switch section {
        case .profile, .appearance, .notifications, .info:
            return true
        case .security:
            return can(.manageSecuritySettings)
        case .restaurant:
            return can(.manageRestaurantSettings)
        case .haccp:
            return can(.manageHACCPParameters)
        case .data:
            return can(.manageDataAndBackup)
        case .printer:
            return can(.managePrinters)
        }
    }

    // MARK: - Risoluzione azione (diretta vs PIN MASTER)

    /// MASTER → sempre diretto. Senza permesso → PIN MASTER (sessione temporanea).
    /// Con «Protezione MASTER» attiva, le eliminazioni richiedono PIN anche ai collaboratori.
    func resolve(_ permission: AppPermission) -> PermissionAuthorization {
        if isMaster { return .allowed }
        if PrivilegedSession.shared.isElevated(permission) { return .allowed }

        if requiresMasterPinForCriticalAction(permission) {
            return .requiresMaster(permission.masterOperation)
        }

        guard can(permission) else {
            return .requiresMaster(permission.masterOperation)
        }
        return .allowed
    }

    func resolveModuleAccess(_ module: SidebarItem) -> PermissionAuthorization {
        if isMaster { return .allowed }
        let permission = AppPermission.accessModule(module)
        if PrivilegedSession.shared.isElevated(permission) { return .allowed }
        if canAccessModule(module) { return .allowed }
        return .requiresMaster(.privilegedAction)
    }

    /// Sezioni: le personali sempre; le admin sempre visibili (lucchetto + PIN MASTER se serve).
    func isSettingsSectionVisible(_ section: SettingsSection) -> Bool {
        true
    }

    /// Voce sidebar: accessibile di ruolo, oppure elevabile con PIN MASTER.
    func isListedInSidebar(_ item: SidebarItem) -> Bool {
        if canAccessModule(item) { return true }
        switch item {
        case .documents, .users:
            return true
        case .dashboard, .history, .alerts, .settings, .analytics:
            return true
        case .traceability, .fridges, .cleaningControl, .blastChilling,
             .expiryControl, .defrost, .oilControl, .productionLabels,
             .goodsReceiving, .checklist, .productionCatalog, .incomingFoodCatalog:
            // Fuori ruolo (es. Cucina → ricezione): visibile con lucchetto.
            return true
        }
    }

    // MARK: - Profili operativi

    private var operationalModules: Set<SidebarItem> {
        switch role {
        case .master, .boss, .manager, .haccpOperator:
            return Self.fullOperationalModules
        case .cucina:
            return Self.kitchenModules
        case .cameriere:
            return Self.salaModules
        case .viewer:
            return []
        }
    }

    private var canConfigureKitchenInfrastructure: Bool {
        switch role {
        case .master, .boss, .manager, .haccpOperator, .cucina:
            return true
        case .cameriere, .viewer:
            return false
        }
    }

    private var canConfigureChecklists: Bool {
        switch role {
        case .master, .boss, .manager, .haccpOperator, .cucina, .cameriere:
            return true
        case .viewer:
            return false
        }
    }

    private var canManageGoodsSide: Bool {
        switch role {
        case .master, .boss, .manager, .haccpOperator, .cameriere:
            return true
        case .cucina, .viewer:
            return false
        }
    }

    private func requiresMasterPinForCriticalAction(_ permission: AppPermission) -> Bool {
        guard SettingsStorageService.shared.security.requireMasterAuthForCriticalActions else {
            return false
        }
        // Qualsiasi non-MASTER: azioni distruttive / archivio richiedono PIN.
        switch permission {
        case .deleteOperationalRecords,
             .deleteTraceabilityRecords,
             .manageHistory,
             .clearCleaningHistory,
             .manageDataAndBackup,
             .manageDocuments,
             .manageUsers,
             .manageSecuritySettings,
             .switchRestaurant:
            return true
        default:
            return false
        }
    }

    private static let fullOperationalModules: Set<SidebarItem> = [
        .traceability, .fridges, .cleaningControl, .blastChilling,
        .expiryControl, .defrost, .oilControl, .productionLabels,
        .goodsReceiving, .checklist, .productionCatalog, .incomingFoodCatalog
    ]

    private static let kitchenModules: Set<SidebarItem> = [
        .traceability, .fridges, .cleaningControl, .blastChilling,
        .expiryControl, .defrost, .oilControl, .productionLabels,
        .checklist, .productionCatalog
    ]

    private static let salaModules: Set<SidebarItem> = [
        .goodsReceiving, .incomingFoodCatalog, .expiryControl, .checklist
    ]
}

extension UserRole {
    var displayName: String {
        switch self {
        case .master: return "Responsabile (MASTER)"
        case .boss: return "Titolare"
        case .manager: return "Manager"
        case .cucina: return "Cucina"
        case .cameriere: return "Sala"
        case .haccpOperator: return "Operatore HACCP"
        case .viewer: return "Sola lettura"
        }
    }

    /// Descrizione breve per UI creazione/modifica collaboratore.
    var roleSummary: String {
        switch self {
        case .master: return "Accesso completo e gestione utenti"
        case .boss: return "Gestione attività, documenti e backup"
        case .manager: return "Parametri HACCP e stampanti"
        case .cucina: return "Moduli cucina: temperature, pulizie, processi"
        case .cameriere: return "Ricezione merci, scadenze e checklist"
        case .haccpOperator: return "Tutti i controlli operativi HACCP"
        case .viewer: return "Solo consultazione"
        }
    }

    var permissions: UserPermissions { UserPermissions(role: self) }
}

extension LocalUser {
    var permissions: UserPermissions { role.permissions }
}

extension Optional where Wrapped == LocalUser {
    var permissions: UserPermissions {
        self?.permissions ?? UserPermissions(role: .viewer)
    }
}

extension SidebarItem {
    func isAccessible(by permissions: UserPermissions) -> Bool {
        permissions.canAccessModule(self)
    }

    /// Visibile in sidebar/dashboard (anche con lucchetto se serve PIN MASTER).
    func isListedInSidebar(by permissions: UserPermissions) -> Bool {
        permissions.isListedInSidebar(self)
    }

    func needsMasterAuthToAccess(by permissions: UserPermissions) -> Bool {
        if case .requiresMaster = permissions.resolveModuleAccess(self) {
            return true
        }
        return false
    }

    static var allNavigable: [SidebarItem] {
        [.dashboard] + foodsInOrder + haccpModulesInOrder + toolsInOrder
    }
}
