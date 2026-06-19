import Foundation

// MARK: - Operatore HACCP — cosa può e non può fare
//
// L'OPERATORE HACCP (`haccpOperator`) è il collaboratore standard in cucina/sala.
// Il MASTER può sempre tutto senza richieste aggiuntive.
// Se l'operatore tenta un'azione non consentita → richiesta PIN MASTER.
//
// ┌─────────────────────────┬──────────────────────────────────┬────────────────────────────────────────┐
// │ Funzionalità            │ Operatore PUÒ                    │ Operatore NON PUÒ (serve PIN MASTER)   │
// ├─────────────────────────┼──────────────────────────────────┼────────────────────────────────────────┤
// │ Dashboard / Avvisi      │ Consultare, risolvere avvisi       │ —                                      │
// │ Storia / Grafici        │ Consultare                         │ —                                      │
// │ Tracciabilità           │ Creare e aggiornare schede         │ Eliminare schede                       │
// │ Frigoriferi             │ Registrare temperature             │ Aggiungere/modificare/eliminare frigo  │
// │ Controllo pulizia       │ Completare task e note             │ Gestire aree/task, pulire storico      │
// │ Abbattimento            │ Iniziare/terminare cicli           │ Gestire libreria produzioni            │
// │ Scadenze                │ Consultare e aggiornare stati      │ —                                      │
// │ Decongelamento          │ Avviare e completare               │ Annullare/eliminare record             │
// │ Controllo olio          │ Inserire controlli                 │ Gestire punti olio, eliminare storico  │
// │ Etichette produzione    │ Creare e stampare etichette        │ Gestire catalogo produzioni            │
// │ Ricezione merci         │ Registrare ricezioni               │ Gestire anagrafica fornitori           │
// │ Checklist               │ Eseguire checklist                 │ Creare/modificare/eliminare modelli    │
// │ Documenti               │ Aprire, condividere, export CSV    │ Rigenerare, eliminare, export archivio │
// │ Utenti                  │ —                                │ Qualsiasi operazione (solo MASTER)      │
// │ Impostazioni            │ Profilo, aspetto, notifiche, info  │ Sicurezza, ristorante, HACCP, dati,    │
// │                         │                                  │ stampanti                              │
// └─────────────────────────┴──────────────────────────────────┴────────────────────────────────────────┘
//
// Altri ruoli:
// - VIEWER: solo lettura; qualsiasi registrazione richiede PIN MASTER.
// - CUCINA: come operatore sui moduli cucina; moduli sala (tracciabilità, ricezione, scadenze) → PIN MASTER.
// - CAMERIERE: come operatore sui moduli sala; moduli cucina → PIN MASTER.
// - MANAGER / TITOLARE: configurazione diretta; eliminazioni e documenti critici → PIN MASTER.

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
             .manageIncomingFoodCatalog, .manageOilControlPoints:
            return isManagement

        case .deleteOperationalRecords, .deleteTraceabilityRecords:
            return isManagement

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
        case .dashboard, .history, .alerts, .settings, .documents, .analytics:
            return true
        case .users:
            return false
        case .traceability, .goodsReceiving, .expiryControl:
            return role != .cucina
        case .fridges, .cleaningControl, .blastChilling, .productionCatalog, .incomingFoodCatalog,
             .defrost, .oilControl, .productionLabels, .checklist:
            return role != .cameriere
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

    /// MASTER → sempre diretto. Altri ruoli → PIN MASTER se non autorizzati o per azioni critiche.
    func resolve(_ permission: AppPermission) -> PermissionAuthorization {
        if isMaster { return .allowed }
        if PrivilegedSession.shared.isElevated(permission) { return .allowed }

        guard can(permission) else {
            return .requiresMaster(permission.masterOperation)
        }

        switch permission {
        case .deleteOperationalRecords, .deleteTraceabilityRecords,
             .manageDocuments, .clearCleaningHistory, .manageUsers,
             .manageSecuritySettings, .manageDataAndBackup:
            return .requiresMaster(permission.masterOperation)
        default:
            return .allowed
        }
    }

    func resolveModuleAccess(_ module: SidebarItem) -> PermissionAuthorization {
        if isMaster { return .allowed }
        let permission = AppPermission.accessModule(module)
        if PrivilegedSession.shared.isElevated(permission) { return .allowed }
        if canAccessModule(module) { return .allowed }
        return .requiresMaster(.privilegedAction)
    }

    /// Tutte le sezioni impostazioni sono visibili; quelle riservate mostrano il lucchetto.
    func isSettingsSectionVisible(_ section: SettingsSection) -> Bool {
        true
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
