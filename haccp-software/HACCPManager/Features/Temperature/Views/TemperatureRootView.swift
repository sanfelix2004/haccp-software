import SwiftUI
import SwiftData

struct TemperatureRootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if let restaurantId = appState.activeRestaurantId {
                TemperatureRestaurantPanel(restaurantId: restaurantId)
            } else {
                DashboardEmptyStateView(state: .init(
                    title: "Seleziona un ristorante",
                    message: "I controlli temperatura sono legati al ristorante attivo.",
                    actionTitle: nil
                ))
                .padding(theme.spacing.screenPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Frigoriferi")
    }
}

private struct TemperatureRestaurantPanel: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    let restaurantId: UUID

    @Query private var users: [LocalUser]
    @Query private var devices: [TemperatureDevice]
    @Query private var records: [TemperatureRecord]
    @Query private var alerts: [TemperatureAlert]

    init(restaurantId: UUID) {
        self.restaurantId = restaurantId
        let rid = restaurantId
        _users = Query()
        _devices = Query(
            filter: #Predicate<TemperatureDevice> { $0.restaurantId == rid && $0.isActive },
            sort: [SortDescriptor(\TemperatureDevice.name)]
        )
        _records = Query(
            filter: #Predicate<TemperatureRecord> { $0.restaurantId == rid },
            sort: [SortDescriptor(\TemperatureRecord.measuredAt, order: .reverse)]
        )
        _alerts = Query(
            filter: #Predicate<TemperatureAlert> { $0.restaurantId == rid && $0.isActive },
            sort: [SortDescriptor(\TemperatureAlert.createdAt, order: .reverse)]
        )
    }

    @StateObject private var viewModel = TemperatureDashboardViewModel()
    @State private var masterAuth = MasterAuthCoordinator()
    @State private var showMasterAuthForDelete = false
    @State private var devicePendingDeletion: TemperatureDevice?
    @State private var deviceToEdit: TemperatureDevice?
    @State private var showEditDeviceSheet = false
    @State private var historyRange: TemperatureHistoryRange = .week
    @State private var operationError: String?

    @Environment(\.theme) private var theme

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var permissions: UserPermissions { currentUser.permissions }

    private func requestAddDevice() {
        masterAuth.request(permission: .manageTemperatureDevices, permissions: permissions) {
            viewModel.showAddDeviceSheet = true
        }
    }

    private func requestEditDevice(_ device: TemperatureDevice) {
        masterAuth.request(permission: .manageTemperatureDevices, permissions: permissions) {
            deviceToEdit = device
            showEditDeviceSheet = true
        }
    }

    private func requestDeleteDevice(_ device: TemperatureDevice) {
        masterAuth.request(permission: .manageTemperatureDevices, permissions: permissions) {
            devicePendingDeletion = device
            handleDeleteDeviceConfirmed()
        }
    }

    /// Record già ordinati per `measuredAt` desc — prima occorrenza per device = ultima misura.
    private var latestRecordsByDeviceId: [UUID: TemperatureRecord] {
        var result: [UUID: TemperatureRecord] = [:]
        result.reserveCapacity(devices.count)
        for record in records {
            if result[record.deviceId] == nil {
                result[record.deviceId] = record
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: theme.spacing.sectionSpacing) {
            ModuleScreenHeader(
                title: "Controlli temperatura",
                subtitle: "Registra le temperature e monitora le non conformità HACCP",
                systemImage: "thermometer.medium",
                help: ModuleHelpLibrary.sidebar(.fridges)
            )

            Picker("Sezione", selection: $viewModel.selectedTab) {
                ForEach(TemperatureTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Sezione frigoriferi")

            Group {
                switch viewModel.selectedTab {
                case .dashboard:
                    dashboardContent
                case .devices:
                    devicesContent
                case .history:
                    historyContent
                case .alerts:
                    alertsContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(theme.spring, value: viewModel.selectedTab)
        }
        .padding(theme.spacing.screenPadding)
        .background(theme.colorBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !devices.isEmpty {
                    Button {
                        masterAuth.request(permission: .executeRecords, permissions: permissions) {
                            presentNewMeasurement()
                        }
                    } label: {
                        Label("Misura", systemImage: "thermometer.medium")
                    }
                }
                Button {
                    masterAuth.request(permission: .manageTemperatureDevices, permissions: permissions) {
                        viewModel.showAddDeviceSheet = true
                    }
                } label: {
                    Label("Aggiungi frigo", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddDeviceSheet) {
            TemperatureDeviceEditView(
                restaurantId: restaurantId,
                user: currentUser,
                deviceToEdit: nil,
                onSaved: { device in
                    guard let device else { return }
                    if devices.count == 1 {
                        presentNewMeasurement(preselected: device)
                    }
                }
            )
        }
        .sheet(isPresented: $showEditDeviceSheet) {
            if let deviceToEdit {
                TemperatureDeviceEditView(
                    restaurantId: restaurantId,
                    user: currentUser,
                    deviceToEdit: deviceToEdit
                )
            }
        }
        .sheet(isPresented: $viewModel.showAddRecordSheet) {
            if let selectedDevice = viewModel.selectedDevice, let currentUser {
                AddTemperatureRecordView(
                    devices: devices,
                    initialDeviceId: selectedDevice.id,
                    user: currentUser,
                    restaurantId: restaurantId
                )
            }
        }
        .sheet(isPresented: $viewModel.showDevicePickerSheet) {
            TemperatureDevicePickerSheet(
                devices: devices,
                records: records,
                onSelect: { device in
                    viewModel.showDevicePickerSheet = false
                    viewModel.selectedDevice = device
                    viewModel.showAddRecordSheet = true
                },
                onCancel: {
                    viewModel.showDevicePickerSheet = false
                }
            )
        }
        .fullScreenCover(isPresented: $showMasterAuthForDelete) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .manageTemperatureDevices,
                    onAuthorized: {
                        showMasterAuthForDelete = false
                        handleDeleteDeviceConfirmed()
                    },
                    onCancel: {
                        showMasterAuthForDelete = false
                        devicePendingDeletion = nil
                    }
                ) { EmptyView() }
            }
        }
        .masterAuthCover(coordinator: masterAuth, master: users.first(where: { $0.role == .master }))
        .haccpControlTint()
        .alert("Frigoriferi", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(operationError ?? "")
        }
    }

    private var quickActionsCard: some View {
        DashboardCardView(title: "Azioni rapide", subtitle: "Operazioni frequenti in cucina") {
            VStack(spacing: 12) {
                PrimaryButton(title: "Nuova misurazione", icon: "thermometer.medium") {
                    masterAuth.request(permission: .executeRecords, permissions: permissions) {
                        presentNewMeasurement()
                    }
                }
                SecondaryButton(title: "Aggiungi frigo", icon: "plus.circle") {
                    requestAddDevice()
                }
            }
        }
    }

    private func presentNewMeasurement(preselected: TemperatureDevice? = nil) {
        if devices.isEmpty {
            requestAddDevice()
            return
        }
        if let preselected {
            viewModel.selectedDevice = preselected
            viewModel.showAddRecordSheet = true
            return
        }
        if devices.count == 1, let only = devices.first {
            viewModel.selectedDevice = only
            viewModel.showAddRecordSheet = true
            return
        }
        viewModel.showDevicePickerSheet = true
    }

    private func allowedRange(for device: TemperatureDevice) -> (min: Double, max: Double) {
        TemperatureValidationService().allowedRange(
            for: device,
            settings: SettingsStorageService.shared.haccp
        )
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                quickActionsCard

                if devices.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun frigorifero configurato",
                        message: "Aggiungi frigoriferi, freezer e abbattitori per iniziare i controlli HACCP.",
                        actionTitle: "Aggiungi frigo"
                    )) {
                        requestAddDevice()
                    }
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        StatCard(
                            title: "Frigoriferi",
                            value: "\(devices.count)",
                            subtitle: "Attivi",
                            icon: "thermometer.medium",
                            accent: theme.colorPrimary
                        )
                        StatCard(
                            title: "Avvisi",
                            value: "\(alerts.count)",
                            subtitle: alerts.isEmpty ? "Tutto ok" : "Da gestire",
                            icon: "exclamationmark.triangle.fill",
                            accent: alerts.isEmpty ? theme.colorSuccess : theme.colorError
                        )
                        StatCard(
                            title: "Oggi",
                            value: "\(todayRecordCount)",
                            subtitle: "Misurazioni",
                            icon: "clock.fill",
                            accent: theme.colorInfo
                        )
                    }

                    Text("Tocca un frigorifero per registrare una nuova temperatura")
                        .font(.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    let problemMap = viewModel.problematicDevices(records: records)
                    ForEach(devices) { device in
                        deviceDashboardCard(device: device, status: problemMap[device.id])
                    }
                }

                if !alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Avvisi recenti")
                                .font(.headline)
                                .foregroundStyle(theme.colorTextPrimary)
                            Spacer()
                            Button("Vedi tutti") {
                                viewModel.selectedTab = .alerts
                            }
                            .font(.caption.weight(.semibold))
                        }
                        ForEach(alerts.prefix(3)) { alert in
                            alertRow(alert)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func deviceDashboardCard(device: TemperatureDevice, status: TemperatureStatus?) -> some View {
        Button {
            presentNewMeasurement(preselected: device)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: device.type.icon)
                    .font(.title2)
                    .foregroundStyle(theme.colorPrimary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 6) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                    Text(device.type.label)
                        .font(.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                    let range = allowedRange(for: device)
                    Text("Range \(range.min, specifier: "%.0f") – \(range.max, specifier: "%.0f") °C")
                        .font(.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                    if let latest = latestRecordsByDeviceId[device.id] {
                        Text("Ultima: \(latest.measuredAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                }
                Spacer()
                if let latest = latestRecordsByDeviceId[device.id] {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("\(latest.value, specifier: "%.1f")°")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.colorTextPrimary)
                        HACCPBadge(title: latest.status.label, style: latest.status.badgeStyle)
                    }
                } else if let status {
                    HACCPBadge(title: status.label, style: status.badgeStyle)
                } else {
                    HACCPBadge(title: "Da misurare", style: .neutral)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colorTextSecondary)
            }
            .padding(14)
            .background(theme.colorSurface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke((status ?? .ok).borderColor.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
    }

    private var todayRecordCount: Int {
        let start = Calendar.current.startOfDay(for: Date())
        return records.filter { $0.measuredAt >= start }.count
    }

    private var devicesContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                PrimaryButton(title: "Aggiungi frigo", icon: "plus.circle.fill") {
                    requestAddDevice()
                }

                if devices.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun frigorifero",
                        message: "Aggiungi frigoriferi, freezer e abbattitori da monitorare ogni giorno.",
                        actionTitle: "Aggiungi frigo"
                    )) {
                        requestAddDevice()
                    }
                } else {
                    DashboardCardView(
                        title: "Frigoriferi configurati",
                        subtitle: "\(devices.count) dispositivi attivi"
                    ) {
                        VStack(spacing: 10) {
                            ForEach(devices) { device in
                                deviceManagementRow(device)
                            }
                        }
                    }
                }
            }
        }
    }

    private func deviceManagementRow(_ device: TemperatureDevice) -> some View {
        let latest = latestRecordsByDeviceId[device.id]
        let range = allowedRange(for: device)

        return VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: device.type.icon)
                    .font(.title3)
                    .foregroundStyle(theme.colorPrimary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                    Text("\(device.type.label) · Range \(range.min, specifier: "%.0f")–\(range.max, specifier: "%.0f") °C")
                        .font(.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                    if let latest {
                        HStack(spacing: 6) {
                            Text("Ultima: \(latest.value, specifier: "%.1f") °C")
                            HACCPBadge(title: latest.status.label, style: latest.status.badgeStyle, showIcon: false)
                        }
                        .font(.caption2)
                    } else {
                        Text("Nessuna misurazione registrata")
                            .font(.caption2)
                            .foregroundStyle(theme.colorWarning)
                    }
                }
                Spacer()
                NavigationLink {
                    TemperatureDeviceDetailView(device: device)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.colorInfo)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    masterAuth.request(permission: .executeRecords, permissions: permissions) {
                        presentNewMeasurement(preselected: device)
                    }
                } label: {
                    Label("Misura ora", systemImage: "thermometer.medium")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.colorPrimary)

                Button {
                    requestEditDevice(device)
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 44, height: 40)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    requestDeleteDevice(device)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 40)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(theme.colorSurfaceElevated)
        .cornerRadius(12)
    }

    private var historyContent: some View {
        VStack(spacing: 12) {
            Picker("Periodo", selection: $historyRange) {
                ForEach(TemperatureHistoryRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            let filtered = viewModel.records(records, matching: historyRange)

            if filtered.isEmpty {
                DashboardEmptyStateView(state: .init(
                    title: "Nessuna misurazione",
                    message: historyRange == .all
                        ? "Registra la prima temperatura dalla panoramica."
                        : "Nessun dato nel periodo selezionato. Prova un intervallo più ampio.",
                    actionTitle: devices.isEmpty ? "Aggiungi frigo" : "Nuova misurazione"
                )) {
                    if devices.isEmpty {
                        requestAddDevice()
                    } else {
                        masterAuth.request(permission: .executeRecords, permissions: permissions) {
                            presentNewMeasurement()
                        }
                    }
                }
            } else {
                HStack {
                    Text("\(filtered.count) misurazioni")
                        .font(.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                    Spacer()
                }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered.prefix(80)) { record in
                            historyRow(record)
                        }
                        if filtered.count > 80 {
                            Text("Mostrate le ultime 80 misurazioni. Usa Documenti per l'archivio completo.")
                                .font(.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)
                        }
                    }
                }
            }
        }
    }

    private func historyRow(_ record: TemperatureRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.deviceName)
                    .font(.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Spacer()
                Text("\(record.value, specifier: "%.1f") °C")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
                HACCPBadge(title: record.status.label, style: record.status.badgeStyle, showIcon: false)
            }
            Text("\(record.measuredByName) · \(record.measuredAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(theme.colorTextSecondary)
            if let corrective = record.correctiveAction, !corrective.isEmpty {
                Label(corrective, systemImage: "wrench.and.screwdriver.fill")
                    .font(.caption)
                    .foregroundStyle(theme.colorWarning)
            }
        }
        .padding(12)
        .background(theme.colorSurface)
        .cornerRadius(12)
    }

    private var alertsContent: some View {
        Group {
            if alerts.isEmpty {
                DashboardEmptyStateView(state: .init(
                    title: "Nessun avviso attivo",
                    message: "Tutte le temperature sono nei limiti HACCP. Gli avvisi compaiono automaticamente in caso di non conformità.",
                    actionTitle: nil
                )) {}
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(alerts) { alert in
                            alertRow(alert, showResolve: true)
                        }
                    }
                }
            }
        }
    }

    private func alertRow(_ alert: TemperatureAlert, showResolve: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.colorError)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(alert.deviceName)
                    .font(.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Text(alert.message)
                    .font(.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                Text(alert.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(theme.colorTextSecondary.opacity(0.8))
            }
            Spacer()
            if showResolve {
                Button("Risolvi") {
                    resolve(alert: alert)
                }
                .buttonStyle(.bordered)
                .tint(theme.colorPrimary)
            }
        }
        .padding(12)
        .background(theme.colorError.opacity(0.1))
        .cornerRadius(12)
    }

    private func resolve(alert: TemperatureAlert) {
        guard let currentUser else { return }
        do {
            try viewModel.moduleService.resolveAlert(
                alert,
                user: currentUser,
                restaurantId: restaurantId,
                modelContext: modelContext
            )
        } catch {
            operationError = "Impossibile risolvere l'avviso."
        }
    }

    private func handleDeleteDeviceConfirmed() {
        guard let device = devicePendingDeletion, let currentUser else { return }
        do {
            try viewModel.moduleService.deleteDevice(
                device,
                user: currentUser,
                restaurantId: restaurantId,
                modelContext: modelContext
            )
            devicePendingDeletion = nil
        } catch {
            operationError = "Impossibile eliminare il dispositivo."
        }
    }
}

struct TemperatureDeviceDetailView: View {
    let device: TemperatureDevice
    @Query private var records: [TemperatureRecord]

    private let theme = ThemeManager.shared

    var body: some View {
        let scoped = records.filter { $0.deviceId == device.id }.sorted(by: { $0.measuredAt > $1.measuredAt })
        let latest = scoped.first
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(device.name)
                            .font(.largeTitle.bold())
                            .foregroundStyle(theme.colorTextPrimary)
                        Text(device.type.label)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    Spacer()
                    if let latest {
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("\(latest.value, specifier: "%.1f") °C")
                                .font(.title.weight(.bold))
                            HACCPBadge(title: latest.status.label, style: latest.status.badgeStyle)
                        }
                    }
                }
                Divider().overlay(theme.colorDivider)
                if scoped.isEmpty {
                    Text("Nessuna misurazione registrata")
                        .foregroundStyle(theme.colorTextSecondary)
                } else {
                    Text("Storico misurazioni")
                        .font(.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                    ForEach(scoped.prefix(100)) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.measuredAt.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(theme.colorTextSecondary)
                                    .font(.caption)
                                if let notes = record.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption2)
                                        .foregroundStyle(theme.colorTextSecondary)
                                }
                            }
                            Spacer()
                            Text("\(record.value, specifier: "%.1f") °C")
                                .foregroundStyle(theme.colorTextPrimary)
                                .font(.subheadline.weight(.semibold))
                            HACCPBadge(title: record.status.label, style: record.status.badgeStyle, showIcon: false)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(20)
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TemperatureDeviceEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    let restaurantId: UUID?
    let user: LocalUser?
    let deviceToEdit: TemperatureDevice?
    var onSaved: ((TemperatureDevice?) -> Void)? = nil

    @State private var name = ""
    @State private var type: TemperatureDeviceType = .fridge
    @State private var customMin = ""
    @State private var customMax = ""
    @State private var validationError: String?

    private var isNew: Bool { deviceToEdit == nil }

    private var previewRange: (min: Double, max: Double) {
        let minTemp = parseOptionalTemperature(customMin)
        let maxTemp = parseOptionalTemperature(customMax)
        let preview = TemperatureDevice(
            restaurantId: restaurantId ?? UUID(),
            name: name.isEmpty ? "Anteprima" : name,
            type: type,
            customMinTemp: minTemp,
            customMaxTemp: maxTemp
        )
        return TemperatureValidationService().allowedRange(
            for: preview,
            settings: SettingsStorageService.shared.haccp
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.sectionSpacing) {
                    DashboardCardView(title: "Identificazione", subtitle: "Nome riconoscibile in cucina") {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Es. Frigo cucina, Freezer magazzino…", text: $name)
                                .textFieldStyle(.roundedBorder)

                            Picker("Tipo dispositivo", selection: $type) {
                                ForEach(TemperatureDeviceType.allCases, id: \.self) { item in
                                    Label(item.label, systemImage: item.icon).tag(item)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    DashboardCardView(title: "Limiti temperatura", subtitle: "Lascia vuoto per usare i limiti HACCP predefiniti") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Minimo °C")
                                        .font(.caption)
                                        .foregroundStyle(theme.colorTextSecondary)
                                    TextField("Opzionale", text: $customMin)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Massimo °C")
                                        .font(.caption)
                                        .foregroundStyle(theme.colorTextSecondary)
                                    TextField("Opzionale", text: $customMax)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            Text("Range attivo: \(previewRange.min, specifier: "%.1f") – \(previewRange.max, specifier: "%.1f") °C")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.colorInfo)
                        }
                    }

                    if isNew {
                        Text("Dopo il salvataggio potrai registrare subito la prima misurazione.")
                            .font(.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(theme.spacing.screenPadding + 8)
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle(isNew ? "Nuovo frigo" : "Modifica frigo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Dati non validi", isPresented: Binding(get: {
                validationError != nil
            }, set: { _ in
                validationError = nil
            })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationError ?? "")
            }
        }
        .onAppear {
            guard let deviceToEdit else { return }
            name = deviceToEdit.name
            type = deviceToEdit.type
            if let customMinTemp = deviceToEdit.customMinTemp { customMin = String(customMinTemp) }
            if let customMaxTemp = deviceToEdit.customMaxTemp { customMax = String(customMaxTemp) }
        }
    }

    private func save() {
        guard let restaurantId, let user else { return }
        guard user.permissions.canPerform(.manageTemperatureDevices) else {
            validationError = "Serve l'autorizzazione MASTER per gestire i frigoriferi."
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let minTemp = parseOptionalTemperature(customMin)
        let maxTemp = parseOptionalTemperature(customMax)
        if (minTemp == nil) != (maxTemp == nil) {
            validationError = "Inserisci sia il minimo sia il massimo, oppure lascia entrambi vuoti."
            return
        }
        if let minTemp, let maxTemp, minTemp >= maxTemp {
            validationError = "Il minimo deve essere più basso del massimo."
            return
        }
        let savedDevice: TemperatureDevice
        if let deviceToEdit {
            deviceToEdit.name = trimmedName
            deviceToEdit.type = type
            deviceToEdit.customMinTemp = minTemp
            deviceToEdit.customMaxTemp = maxTemp
            savedDevice = deviceToEdit
            TemperatureModuleService().log(
                action: "TEMPERATURE_DEVICE_UPDATED",
                user: user,
                restaurantId: restaurantId,
                deviceName: deviceToEdit.name,
                details: "Tipo: \(deviceToEdit.type.rawValue)",
                modelContext: modelContext
            )
        } else {
            let device = TemperatureDevice(
                restaurantId: restaurantId,
                name: trimmedName,
                type: type,
                customMinTemp: minTemp,
                customMaxTemp: maxTemp
            )
            modelContext.insert(device)
            savedDevice = device
            TemperatureModuleService().log(
                action: "TEMPERATURE_DEVICE_CREATED",
                user: user,
                restaurantId: restaurantId,
                deviceName: device.name,
                details: "Tipo: \(device.type.rawValue)",
                modelContext: modelContext
            )
        }
        try? modelContext.save()
        onSaved?(savedDevice)
        dismiss()
    }

    private func parseOptionalTemperature(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
}

struct AddTemperatureRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let devices: [TemperatureDevice]
    let initialDeviceId: UUID
    let user: LocalUser
    let restaurantId: UUID

    @State private var selectedDeviceId: UUID
    @State private var valueText = ""
    @State private var notes = ""
    @State private var correctiveAction = ""
    @State private var validationMessage = ""
    @State private var validationColor = Color.gray
    @State private var showError = false
    @State private var errorText = ""

    private let validationService = TemperatureValidationService()
    private let moduleService = TemperatureModuleService()
    private let keypad = [
        ["7", "8", "9"],
        ["4", "5", "6"],
        ["1", "2", "3"],
        [".", "0", "⌫"]
    ]

    init(devices: [TemperatureDevice], initialDeviceId: UUID, user: LocalUser, restaurantId: UUID) {
        self.devices = devices
        self.initialDeviceId = initialDeviceId
        self.user = user
        self.restaurantId = restaurantId
        _selectedDeviceId = State(initialValue: initialDeviceId)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let keypadButtonHeight = min(max((geo.size.height - 420) / 4, 48), 58)
                let correctiveEditorHeight = min(max(geo.size.height * 0.16, 92), 120)
                VStack(spacing: 10) {
                    if devices.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(devices) { device in
                                    Button {
                                        selectedDeviceId = device.id
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(device.name)
                                                .font(.subheadline.weight(.semibold))
                                                .lineLimit(1)
                                            Text(device.type.label)
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(
                                            selectedDeviceId == device.id
                                                ? ThemeManager.shared.colorPrimary
                                                : ThemeManager.shared.colorTextPrimary
                                        )
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedDeviceId == device.id
                                                ? ThemeManager.shared.colorPrimary.opacity(0.15)
                                                : ThemeManager.shared.colorSurface
                                        )
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(
                                                    selectedDeviceId == device.id
                                                        ? ThemeManager.shared.colorPrimary
                                                        : ThemeManager.shared.colorDivider,
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Image(systemName: selectedDevice?.type.icon ?? "thermometer.medium")
                            .font(.title2)
                            .foregroundStyle(ThemeManager.shared.colorPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedDevice?.name ?? "Dispositivo")
                                .font(.title3.bold())
                                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                            Text(selectedDevice?.type.label ?? "-")
                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                .font(.caption)
                        }
                        Spacer()
                    }
                    if let device = selectedDevice {
                        let range = validationService.allowedRange(for: device, settings: SettingsStorageService.shared.haccp)
                        Text("Range HACCP: \(range.min, specifier: "%.1f") – \(range.max, specifier: "%.1f") °C")
                            .font(.caption)
                            .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text(valueText.isEmpty ? "--.-" : valueText)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)

                    Text(validationMessage)
                        .foregroundColor(validationColor)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)

                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                Button("+/-") { toggleSign() }
                                    .buttonStyle(.bordered)
                                    .tint(ThemeManager.shared.colorPrimary)
                                Button("C") { clearAll() }
                                    .buttonStyle(.bordered)
                                    .tint(ThemeManager.shared.colorPrimary)
                                Spacer()
                            }

                            VStack(spacing: 8) {
                                ForEach(keypad, id: \.self) { row in
                                    HStack(spacing: 8) {
                                        ForEach(row, id: \.self) { key in
                                            Button {
                                                keyTap(key)
                                            } label: {
                                                Text(key)
                                                    .font(.title3.bold())
                                                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                                    .frame(maxWidth: .infinity, minHeight: keypadButtonHeight)
                                                    .background(ThemeManager.shared.colorDivider)
                                                    .cornerRadius(10)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Dettagli controllo")
                                .font(.caption.bold())
                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                            TextField("Note (opzionale)", text: $notes)
                                .textFieldStyle(.roundedBorder)
                            Text("Azione correttiva")
                                .font(.caption)
                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                            TextEditor(text: $correctiveAction)
                                .frame(minHeight: correctiveEditorHeight, maxHeight: correctiveEditorHeight)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(ThemeManager.shared.colorSurfaceElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(requiresCorrectiveAction ? ThemeManager.shared.colorWarning : ThemeManager.shared.colorDivider, lineWidth: 1)
                                )
                                .cornerRadius(10)
                            Text(requiresCorrectiveAction ? "Obbligatoria: inserisci azione per valori fuori range." : "Opzionale: utile per tracciabilità.")
                                .font(.caption)
                                .foregroundStyle(requiresCorrectiveAction ? ThemeManager.shared.colorWarning : ThemeManager.shared.colorTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: min(geo.size.width * 0.35, 260), alignment: .top)
                    }

                    HStack(spacing: 12) {
                        Button("Annulla") { dismiss() }
                            .buttonStyle(.bordered)
                            .tint(ThemeManager.shared.colorPrimary)
                        Button("Conferma misurazione") {
                            save()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ThemeManager.shared.colorPrimary)
                        .disabled(!canSubmit)
                    }
                }
                .padding(14)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
            .navigationTitle("Nuova misurazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .alert("Errore", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText)
            }
            .onChange(of: valueText) { _, _ in
                updateValidation()
            }
            .onChange(of: selectedDeviceId) { _, _ in
                updateValidation()
            }
        }
    }

    private func keyTap(_ key: String) {
        switch key {
        case "⌫":
            guard !valueText.isEmpty else { return }
            valueText.removeLast()
        case ".":
            if !valueText.contains(".") {
                valueText += "."
            }
        default:
            if valueText.count < 6 {
                valueText += key
            }
        }
    }

    private func toggleSign() {
        if valueText.hasPrefix("-") {
            valueText.removeFirst()
        } else if !valueText.isEmpty {
            valueText = "-" + valueText
        } else {
            valueText = "-"
        }
    }

    private func clearAll() {
        valueText = ""
        notes = ""
        correctiveAction = ""
        validationMessage = ""
    }

    private func updateValidation() {
        guard let device = selectedDevice, let value = Double(valueText) else {
            validationMessage = ""
            validationColor = .gray
            return
        }
        let result = validationService.validate(value: value, device: device, settings: SettingsStorageService.shared.haccp)
        validationMessage = result.message
        validationColor = result.status.color
    }

    private func save() {
        guard let device = selectedDevice, let value = Double(valueText) else { return }
        do {
            _ = try moduleService.addRecord(
                value: value,
                measuredAt: Date(),
                notes: notes.isEmpty ? nil : notes,
                correctiveAction: correctiveAction.isEmpty ? nil : correctiveAction,
                device: device,
                user: user,
                restaurantId: restaurantId,
                modelContext: modelContext
            )
            HapticManager.shared.notification(.success)
            dismiss()
        } catch {
            errorText = "Salvataggio fallito"
            showError = true
        }
    }

    private var canSubmit: Bool {
        guard selectedDevice != nil, Double(valueText) != nil else { return false }
        if requiresCorrectiveAction {
            return !correctiveAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private var requiresCorrectiveAction: Bool {
        guard let device = selectedDevice, let value = Double(valueText) else { return false }
        let result = validationService.validate(value: value, device: device, settings: SettingsStorageService.shared.haccp)
        return result.status == .outOfRange || result.status == .critical
    }

    private var selectedDevice: TemperatureDevice? {
        devices.first(where: { $0.id == selectedDeviceId }) ?? devices.first
    }
}

private extension TemperatureStatus {
    var color: Color {
        switch self {
        case .ok: return ThemeManager.shared.colorSuccess
        case .warning: return ThemeManager.shared.colorWarning
        case .outOfRange: return ThemeManager.shared.colorError
        case .critical: return Color(hex: "#8B0000")
        }
    }

    var badgeStyle: HACCPBadgeStyle {
        switch self {
        case .ok: return .conforme
        case .warning: return .warning
        case .outOfRange, .critical: return .nonConforme
        }
    }

    var borderColor: Color {
        switch self {
        case .ok: return ThemeManager.shared.colorSuccess
        case .warning: return ThemeManager.shared.colorWarning
        case .outOfRange, .critical: return ThemeManager.shared.colorError
        }
    }
}

// MARK: - Selezione frigorifero per misurazione

private struct TemperatureDevicePickerSheet: View {
    let devices: [TemperatureDevice]
    let records: [TemperatureRecord]
    let onSelect: (TemperatureDevice) -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    Text("Scegli il frigorifero da controllare")
                        .font(.subheadline)
                        .foregroundStyle(theme.colorTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

                    ForEach(devices) { device in
                        Button {
                            onSelect(device)
                        } label: {
                            pickerRow(device)
                        }
                        .buttonStyle(PremiumPressButtonStyle())
                    }
                }
                .padding(theme.spacing.screenPadding + 8)
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Nuova misurazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
            }
        }
    }

    private func pickerRow(_ device: TemperatureDevice) -> some View {
        let latest = records.filter { $0.deviceId == device.id }.max(by: { $0.measuredAt < $1.measuredAt })
        let range = TemperatureValidationService().allowedRange(
            for: device,
            settings: SettingsStorageService.shared.haccp
        )

        return HStack(spacing: 12) {
            Image(systemName: device.type.icon)
                .font(.title2)
                .foregroundStyle(theme.colorPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Text("\(device.type.label) · \(range.min, specifier: "%.0f")–\(range.max, specifier: "%.0f") °C")
                    .font(.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                if let latest {
                    Text("Ultima: \(latest.value, specifier: "%.1f") °C · \(latest.measuredAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
            Spacer()
            if let latest {
                HACCPBadge(title: latest.status.label, style: latest.status.badgeStyle, showIcon: false)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(theme.colorTextSecondary)
        }
        .padding(14)
        .background(theme.colorSurface)
        .cornerRadius(12)
    }
}
