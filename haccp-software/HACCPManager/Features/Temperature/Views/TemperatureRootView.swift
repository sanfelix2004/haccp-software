import SwiftUI
import SwiftData

struct TemperatureRootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var devices: [TemperatureDevice]
    @Query private var records: [TemperatureRecord]
    @Query private var alerts: [TemperatureAlert]

    @StateObject private var viewModel = TemperatureDashboardViewModel()
    @State private var showMasterAuthForDelete = false
    @State private var devicePendingDeletion: TemperatureDevice?
    @State private var deviceToEdit: TemperatureDevice?
    @State private var showEditDeviceSheet = false
    @State private var historyPage = 0
    @State private var historyDateFilter = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
    @State private var showShareSheet = false
    @State private var selectedShareURLs: [URL] = []

    private let pageSize = 30

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var activeRestaurant: Restaurant? {
        guard let restaurantId = appState.activeRestaurantId else { return restaurants.first }
        return restaurants.first(where: { $0.id == restaurantId })
    }

    private var restaurantId: UUID? { activeRestaurant?.id }

    private var scopedDevices: [TemperatureDevice] {
        guard let restaurantId else { return [] }
        return devices.filter { $0.restaurantId == restaurantId && $0.isActive }
            .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
    }

    private var scopedRecords: [TemperatureRecord] {
        guard let restaurantId else { return [] }
        return records.filter { $0.restaurantId == restaurantId }
    }

    private var activeAlerts: [TemperatureAlert] {
        guard let restaurantId else { return [] }
        return alerts
            .filter { $0.restaurantId == restaurantId && $0.isActive }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        VStack(spacing: 18) {
            header
            Picker("Sezione", selection: $viewModel.selectedTab) {
                ForEach(TemperatureTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

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
        }
        .padding(24)
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Temperature")
        .sheet(isPresented: $viewModel.showAddDeviceSheet) {
            TemperatureDeviceEditView(
                restaurantId: restaurantId,
                user: currentUser,
                deviceToEdit: nil
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
            if let selectedDevice = viewModel.selectedDevice, let currentUser, let restaurantId {
                AddTemperatureRecordView(
                    devices: scopedDevices,
                    initialDeviceId: selectedDevice.id,
                    user: currentUser,
                    restaurantId: restaurantId
                )
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: selectedShareURLs)
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
        .alert("Report", isPresented: Binding(get: {
            viewModel.reportError != nil || viewModel.reportReadyMessage != nil
        }, set: { _ in
            viewModel.reportError = nil
            viewModel.reportReadyMessage = nil
        })) {
            Button("OK", role: .cancel) {}
            if !viewModel.reportFiles.isEmpty {
                Button("Condividi") {
                    selectedShareURLs = viewModel.reportFiles.map(\.url)
                    showShareSheet = true
                }
            }
        } message: {
            Text(viewModel.reportError ?? viewModel.reportReadyMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Controlli temperatura")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Monitoraggio HACCP locale e tracciabile")
                    .foregroundColor(.gray)
            }
            Spacer()
            Button {
                viewModel.selectedDevice = scopedDevices.first
                viewModel.showAddRecordSheet = true
            } label: {
                Label("Nuova misurazione", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(12)
            }
            .disabled(scopedDevices.isEmpty)
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if scopedDevices.isEmpty {
                    emptyCard(text: "Configura un dispositivo per iniziare")
                } else {
                    HStack(spacing: 12) {
                        metricCard(title: "Dispositivi", value: "\(scopedDevices.count)")
                        metricCard(title: "Alert attivi", value: "\(activeAlerts.count)")
                        metricCard(title: "Misurazioni", value: "\(scopedRecords.count)")
                    }
                    let problemMap = viewModel.problematicDevices(records: scopedRecords)
                    ForEach(scopedDevices) { device in
                        Button {
                            viewModel.selectedDevice = device
                            viewModel.showAddRecordSheet = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(device.name).font(.headline).foregroundColor(.white)
                                    Text(device.type.label).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                if let status = problemMap[device.id] {
                                    Text(status.rawValue)
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(status.color)
                                        .cornerRadius(10)
                                } else {
                                    Text("Nessuna misurazione")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(14)
                        }
                    }
                }

                if !activeAlerts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dispositivi con problemi").foregroundColor(.white).font(.headline)
                        ForEach(activeAlerts.prefix(5)) { alert in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text(alert.deviceName).foregroundColor(.white)
                                    Text(alert.message).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                reportCard
            }
        }
    }

    private var reportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Report Temperature").font(.headline).foregroundColor(.white)
            Text("Genera PDF/CSV del periodo selezionato. I record inclusi verranno marcati come archiviati.")
                .font(.caption)
                .foregroundColor(.gray)
            HStack {
                Button("Genera PDF") {
                    export(includeCSV: false)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Genera PDF + CSV") {
                    export(includeCSV: true)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }

    private var devicesContent: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Dispositivi").foregroundColor(.white).font(.title3.bold())
                Spacer()
                if currentUser?.role == .master {
                    Button {
                        viewModel.showAddDeviceSheet = true
                    } label: {
                        Label("Aggiungi dispositivo", systemImage: "plus.circle.fill")
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
            }
            if currentUser?.role != .master {
                Text("Solo il MASTER puo creare, modificare o eliminare dispositivi.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if scopedDevices.isEmpty {
                emptyCard(text: "Configura un dispositivo per iniziare")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(scopedDevices) { device in
                            NavigationLink {
                                TemperatureDeviceDetailView(device: device)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(device.name).foregroundColor(.white).font(.headline)
                                        Text(device.type.label).foregroundColor(.gray).font(.caption)
                                    }
                                    Spacer()
                                    if currentUser?.role == .master {
                                        Button {
                                            deviceToEdit = device
                                            showEditDeviceSheet = true
                                        } label: {
                                            Image(systemName: "pencil.circle.fill").foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        Button(role: .destructive) {
                                            devicePendingDeletion = device
                                            showMasterAuthForDelete = true
                                        } label: {
                                            Image(systemName: "trash.fill").foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var historyContent: some View {
        VStack(spacing: 12) {
            HStack {
                DatePicker("Dal", selection: $historyDateFilter, displayedComponents: .date)
                    .labelsHidden()
                Spacer()
                Button("Pagina prec.") {
                    historyPage = max(0, historyPage - 1)
                }
                .disabled(historyPage == 0)
                Button("Pagina succ.") {
                    historyPage += 1
                }
            }
            .foregroundColor(.white)

            let filtered = scopedRecords.filter { $0.measuredAt >= historyDateFilter }
            let page = viewModel.paginatedHistory(filtered, page: historyPage, pageSize: pageSize)

            if page.isEmpty {
                emptyCard(text: "Nessuna misurazione registrata")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(page) { record in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(record.deviceName).foregroundColor(.white).font(.headline)
                                    Spacer()
                                    Text("\(record.value, specifier: "%.1f")C")
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(record.status.color)
                                        .cornerRadius(8)
                                }
                                Text("\(record.measuredByName) - \(record.measuredAt.formatted(date: .abbreviated, time: .shortened))")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                if let corrective = record.correctiveAction, !corrective.isEmpty {
                                    Text("Azione: \(corrective)")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .onChange(of: historyDateFilter) { _, _ in
            historyPage = 0
        }
    }

    private var alertsContent: some View {
        if activeAlerts.isEmpty {
            return AnyView(emptyCard(text: "Nessun alert attivo"))
        }
        return AnyView(
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(activeAlerts) { alert in
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(alert.deviceName).foregroundColor(.white).font(.headline)
                                Text(alert.message).foregroundColor(.gray).font(.caption)
                                Text(alert.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .font(.caption2)
                            }
                            Spacer()
                            Button("Risolvi") {
                                resolve(alert: alert)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(12)
                    }
                }
            }
        )
    }

    private func emptyCard(text: String) -> some View {
        Text(text)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.gray)
            Text(value).font(.title2.bold()).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func resolve(alert: TemperatureAlert) {
        guard let currentUser, let restaurantId else { return }
        do {
            try viewModel.moduleService.resolveAlert(
                alert,
                user: currentUser,
                restaurantId: restaurantId,
                modelContext: modelContext
            )
        } catch {
            viewModel.reportError = "Impossibile risolvere alert"
        }
    }

    private func handleDeleteDeviceConfirmed() {
        guard let device = devicePendingDeletion, let currentUser, let restaurantId else { return }
        do {
            try viewModel.moduleService.deleteDevice(
                device,
                user: currentUser,
                restaurantId: restaurantId,
                modelContext: modelContext
            )
            devicePendingDeletion = nil
        } catch {
            viewModel.reportError = "Impossibile eliminare dispositivo"
        }
    }

    private func export(includeCSV: Bool) {
        guard let activeRestaurant else { return }
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end
        let rows = scopedRecords.filter { $0.measuredAt >= start && $0.measuredAt <= end }
        guard !rows.isEmpty else {
            viewModel.reportError = "Nessuna misurazione nel periodo selezionato."
            return
        }
        viewModel.exportReport(
            restaurant: activeRestaurant,
            records: rows,
            devices: scopedDevices,
            startDate: start,
            endDate: end,
            includeCSV: includeCSV,
            modelContext: modelContext
        )
    }
}

struct TemperatureDeviceDetailView: View {
    let device: TemperatureDevice
    @Query private var records: [TemperatureRecord]

    var body: some View {
        let scoped = records.filter { $0.deviceId == device.id }.sorted(by: { $0.measuredAt > $1.measuredAt })
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(device.name).font(.largeTitle.bold()).foregroundColor(.white)
                Text(device.type.label).foregroundColor(.gray)
                Divider().overlay(Color.white.opacity(0.1))
                if scoped.isEmpty {
                    Text("Nessuna misurazione registrata").foregroundColor(.gray)
                } else {
                    ForEach(scoped.prefix(100)) { record in
                        HStack {
                            Text(record.measuredAt.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.gray).font(.caption)
                            Spacer()
                            Text("\(record.value, specifier: "%.1f")C").foregroundColor(.white)
                            Text(record.status.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(record.status.color)
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
    }
}

struct TemperatureDeviceEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let restaurantId: UUID?
    let user: LocalUser?
    let deviceToEdit: TemperatureDevice?

    @State private var name = ""
    @State private var type: TemperatureDeviceType = .fridge
    @State private var customMin = ""
    @State private var customMax = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome dispositivo", text: $name)
                Picker("Tipo", selection: $type) {
                    ForEach(TemperatureDeviceType.allCases, id: \.self) { item in
                        Text(item.label).tag(item)
                    }
                }
                TextField("Min custom (opzionale)", text: $customMin).keyboardType(.decimalPad)
                TextField("Max custom (opzionale)", text: $customMax).keyboardType(.decimalPad)
            }
            .navigationTitle("Dispositivo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
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
        if let deviceToEdit {
            deviceToEdit.name = name
            deviceToEdit.type = type
            deviceToEdit.customMinTemp = Double(customMin)
            deviceToEdit.customMaxTemp = Double(customMax)
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
                name: name,
                type: type,
                customMinTemp: Double(customMin),
                customMaxTemp: Double(customMax)
            )
            modelContext.insert(device)
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
        dismiss()
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
                    Picker("Dispositivo", selection: $selectedDeviceId) {
                        ForEach(devices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .tint(.white)

                    Text(selectedDevice?.name ?? "Dispositivo")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text(selectedDevice?.type.label ?? "-")
                        .foregroundColor(.gray)
                        .font(.caption)

                    Text(valueText.isEmpty ? "--.-" : valueText)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text(validationMessage)
                        .foregroundColor(validationColor)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)

                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                Button("+/-") { toggleSign() }
                                    .buttonStyle(.bordered)
                                    .tint(.white)
                                Button("C") { clearAll() }
                                    .buttonStyle(.bordered)
                                    .tint(.white)
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
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity, minHeight: keypadButtonHeight)
                                                    .background(Color.white.opacity(0.08))
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
                                .foregroundColor(.gray)
                            TextField("Note (opzionale)", text: $notes)
                                .textFieldStyle(.roundedBorder)
                            Text("Azione correttiva")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextEditor(text: $correctiveAction)
                                .frame(minHeight: correctiveEditorHeight, maxHeight: correctiveEditorHeight)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(requiresCorrectiveAction ? Color.orange : Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .cornerRadius(10)
                            Text(requiresCorrectiveAction ? "Obbligatoria: inserisci azione per valori fuori range." : "Opzionale: utile per tracciabilita.")
                                .font(.caption)
                                .foregroundColor(requiresCorrectiveAction ? .orange : .gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: min(geo.size.width * 0.35, 260), alignment: .top)
                    }

                    HStack(spacing: 12) {
                        Button("Annulla") { dismiss() }
                            .buttonStyle(.bordered)
                            .tint(.white)
                        Button("Conferma misurazione") {
                            save()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(!canSubmit)
                    }
                }
                .padding(14)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(Color(hex: "#0A0A0A").ignoresSafeArea())
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
            dismiss()
        } catch {
            errorText = "Salvataggio fallito"
            showError = true
        }
    }

    private var canSubmit: Bool {
        guard selectedDevice != nil, Double(valueText) != nil else { return false }
        guard let device = selectedDevice, let value = Double(valueText) else { return false }
        let result = validationService.validate(value: value, device: device, settings: SettingsStorageService.shared.haccp)
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
        case .ok: return .green
        case .warning: return .yellow
        case .outOfRange: return .red
        case .critical: return Color(hex: "#8B0000")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
