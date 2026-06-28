import Foundation

// MARK: - Collaboratori esterni (non MASTER)
//
// Cucina, sala, operatore HACCP: lavoro operativo completo senza PIN per ogni azione.
// Riservato a MASTER / titolare (e in parte manager): documenti PDF, utenti, sicurezza,
// backup dati, cambio ristorante, cancellazione storico pulizie.
//
// ┌─────────────────────────┬──────────────────────────────────┬────────────────────────────────────────┐
// │ Funzionalità            │ Collaboratore PUÒ                │ Solo MASTER / titolare (o PIN)         │
// ├─────────────────────────┼──────────────────────────────────┼────────────────────────────────────────┤
// │ Tutti i moduli HACCP    │ Usare e configurare (cataloghi,  │ —                                      │
// │                         │ checklist, fornitori, frighi…)     │                                        │
// │ Registrazioni           │ Creare, aggiornare, eliminare    │ —                                      │
// │ Dashboard / Avvisi      │ Consultare e risolvere             │ —                                      │
// │ Storia / Grafici        │ Consultare                         │ —                                      │
// │ Impostazioni            │ Profilo, aspetto, notifiche      │ Sicurezza, ristorante, backup,       │
// │                         │                                  │ parametri HACCP, stampanti             │
// │ Documenti PDF           │ —                                │ Archivio mensile e export              │
// │ Utenti                  │ —                                │ Solo MASTER                            │
// └─────────────────────────┴──────────────────────────────────┴────────────────────────────────────────┘
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
        !isMaster && !isViewer && role != .boss && role != .manager
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

        case .manageTemperatureDevices, .manageChecklistTemplates,
             .manageCleaningConfiguration, .manageSuppliers, .manageProductionLibrary,
             .manageIncomingFoodCatalog, .manageOilControlPoints,
             .deleteOperationalRecords, .deleteTraceabilityRecords:
            return role != .viewer

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
        case .traceability, .goodsReceiving, .expiryControl,
             .fridges, .cleaningControl, .blastChilling, .productionCatalog,
             .incomingFoodCatalog, .defrost, .oilControl, .productionLabels, .checklist:
            return role != .viewer
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
    func resolve(_ permission: AppPermission) -> PermissionAuthorization {
        if isMaster { return .allowed }
        if PrivilegedSession.shared.isElevated(permission) { return .allowed }

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

    /// Sezioni impostazioni personali sempre visibili; le altre con lucchetto o nascoste.
    func isSettingsSectionVisible(_ section: SettingsSection) -> Bool {
        switch section {
        case .profile, .appearance, .notifications, .info:
            return true
        case .security, .restaurant, .haccp, .data, .printer:
            return canAccessSettingsSection(section)
        }
    }
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
