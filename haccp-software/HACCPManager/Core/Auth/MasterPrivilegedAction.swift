import SwiftUI

/// Sessione temporanea dopo PIN MASTER valido (es. operatore autorizzato ad aggiungere un frigo).
@MainActor
final class PrivilegedSession {
    static let shared = PrivilegedSession()

    private var elevations: [AppPermission: Date] = [:]
  private let duration: TimeInterval = 600

    private init() {}

    func elevate(_ permission: AppPermission) {
        elevations[permission] = Date().addingTimeInterval(duration)
    }

    func isElevated(_ permission: AppPermission) -> Bool {
        purgeExpired()
        guard let expiry = elevations[permission] else { return false }
        return expiry > Date()
    }

    func clear(_ permission: AppPermission) {
        elevations.removeValue(forKey: permission)
    }

    func clearAll() {
        elevations.removeAll()
    }

    private func purgeExpired() {
        let now = Date()
        elevations = elevations.filter { $0.value > now }
    }
}

/// Esito della verifica permesso: esecuzione diretta oppure richiesta PIN MASTER.
enum PermissionAuthorization: Equatable {
    case allowed
    case requiresMaster(MasterAuthorizationService.Operation)
}

/// Coordina la richiesta PIN MASTER prima di eseguire azioni riservate.
@Observable
@MainActor
final class MasterAuthCoordinator {
    var isPresented = false
    var operation: MasterAuthorizationService.Operation = .privilegedAction
    private var pendingAction: (() -> Void)?
    private var pendingPermission: AppPermission?

    func request(
        permission: AppPermission,
        permissions: UserPermissions,
        action: @escaping () -> Void
    ) {
        switch permissions.resolve(permission) {
        case .allowed:
            action()
        case .requiresMaster(let op):
            operation = op
            pendingPermission = permission
            pendingAction = action
            isPresented = true
        }
    }

    func requestModuleAccess(
        module: SidebarItem,
        permissions: UserPermissions,
        action: @escaping () -> Void
    ) {
        let permission = AppPermission.accessModule(module)
        switch permissions.resolveModuleAccess(module) {
        case .allowed:
            action()
        case .requiresMaster(let op):
            operation = op
            pendingPermission = permission
            pendingAction = action
            isPresented = true
        }
    }

    func authorized() {
        if let pendingPermission {
            PrivilegedSession.shared.elevate(pendingPermission)
        }
        isPresented = false
        pendingAction?()
        pendingAction = nil
        pendingPermission = nil
    }

    func cancel() {
        isPresented = false
        pendingAction = nil
        pendingPermission = nil
    }
}

extension UserPermissions {
    /// Può eseguire ora (ruolo diretto, MASTER, o PIN MASTER recente).
    func canPerform(_ permission: AppPermission) -> Bool {
        if case .allowed = resolve(permission) { return true }
        return false
    }
}

extension View {
    func masterAuthCover(coordinator: MasterAuthCoordinator, master: LocalUser?) -> some View {
        fullScreenCover(isPresented: Binding(
            get: { coordinator.isPresented },
            set: { if !$0 { coordinator.cancel() } }
        )) {
            if let master {
                MasterAuthOverlay(
                    master: master,
                    operation: coordinator.operation,
                    onAuthorized: { coordinator.authorized() },
                    onCancel: { coordinator.cancel() }
                ) { EmptyView() }
            }
        }
    }
}

/// Contenuto visibile solo dopo autorizzazione MASTER (o se l'utente è già MASTER).
struct MasterGatedContent<Content: View>: View {
    let permission: AppPermission
    let permissions: UserPermissions
    let master: LocalUser?
    let title: String
    let message: String
    @ViewBuilder let content: () -> Content

    @State private var masterAuth = MasterAuthCoordinator()
    @State private var unlocked = false

    var body: some View {
        Group {
            if permissions.isMaster || unlocked {
                content()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(ThemeManager.shared.colorWarning)
                    Text(title)
                        .font(.title3.bold())
                    Text(message)
                        .font(.body)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Autorizza con PIN MASTER") {
                        masterAuth.request(permission: permission, permissions: permissions) {
                            unlocked = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .masterAuthCover(coordinator: masterAuth, master: master)
    }
}

extension AppPermission {
    var masterOperation: MasterAuthorizationService.Operation {
        switch self {
        case .executeRecords:
            return .privilegedAction
        case .manageUsers:
            return .createUser
        case .manageRestaurantSettings:
            return .editRestaurantInfo
        case .manageHACCPParameters:
            return .accessSettings
        case .manageSecuritySettings:
            return .accessSettings
        case .manageDataAndBackup:
            return .resetDatabase
        case .managePrinters:
            return .accessSettings
        case .manageTemperatureDevices:
            return .manageTemperatureDevices
        case .manageChecklistTemplates:
            return .manageChecklistTemplates
        case .manageCleaningConfiguration:
            return .manageCleaningTasks
        case .manageOilControlPoints:
            return .privilegedAction
        case .manageSuppliers:
            return .editRestaurantInfo
        case .manageProductionLibrary, .manageIncomingFoodCatalog:
            return .privilegedAction
        case .deleteOperationalRecords:
            return .privilegedAction
        case .deleteTraceabilityRecords:
            return .deleteTraceabilityEntry
        case .manageDocuments:
            return .privilegedAction
        case .clearCleaningHistory:
            return .clearCleaningHistory
        case .switchRestaurant:
            return .privilegedAction
        case .accessModule:
            return .privilegedAction
        }
    }
}

extension SettingsSection {
    var requiredPermission: AppPermission {
        switch self {
        case .profile, .appearance, .notifications, .info:
            return .executeRecords
        case .security:
            return .manageSecuritySettings
        case .restaurant:
            return .manageRestaurantSettings
        case .haccp:
            return .manageHACCPParameters
        case .data:
            return .manageDataAndBackup
        case .printer:
            return .managePrinters
        }
    }

    func needsMasterAuth(for permissions: UserPermissions) -> Bool {
        if case .requiresMaster = permissions.resolve(requiredPermission) {
            return true
        }
        return false
    }
}
