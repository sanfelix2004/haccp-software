import SwiftUI

struct LabelPrinterSettingsView: View {
    var storage = SettingsStorageService.shared
    @ObservedObject private var printerManager = ClabelPrinterManager.shared
    @State private var isPrintingTest = false
    @State private var isRunningDiagnostics = false

    var body: some View {
        @Bindable var storage = storage
        VStack(spacing: 20) {
            connectionCard
            labelSizeSection
            discoveryCard
            labelFieldsSection
            qrCodeSection
        }
        .onAppear {
            if let uuid = printerManager.savedPeripheralUUID,
               storage.printer.savedPeripheralIdentifier.isEmpty {
                storage.printer.savedPeripheralIdentifier = uuid.uuidString
            }
            printerManager.reconnectIfSaved()
        }
        .onDisappear {
            printerManager.stopScanning()
        }
        .alert("Stampante", isPresented: Binding(
            get: { printerManager.lastErrorMessage != nil },
            set: { if !$0 { printerManager.lastErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(printerManager.lastErrorMessage ?? "")
        }
    }

    // MARK: - Connessione

    private var connectionCard: some View {
        SettingsPanelCard(title: "Stampante CLABEL S1", caption: statusText) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    if let name = printerManager.connectedDeviceName, printerManager.isConnected {
                        Text("Collegata a \(name)")
                            .font(.subheadline.weight(.semibold))
                    } else if !storage.printer.savedPeripheralDisplayName.isEmpty {
                        Text("Salvata: \(storage.printer.savedPeripheralDisplayName)")
                            .font(.subheadline)
                    } else {
                        Text(storage.printer.labelSizeDisplay)
                            .font(.caption)
                            .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    }
                    Spacer()
                }

                if let ok = printerManager.lastSuccessMessage {
                    Text(ok)
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.colorSuccess)
                }

                HStack(spacing: 10) {
                    if printerManager.isReadyToPrint {
                        Button("Disconnetti") { printerManager.disconnect() }
                            .buttonStyle(.bordered)
                        Button { Task { await runTestPrint() } } label: {
                            if isPrintingTest { ProgressView() } else { Text("Prova") }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isPrintingTest || isRunningDiagnostics)
                    } else if printerManager.isConnected {
                        Text("Connessione in corso…")
                            .font(.caption)
                            .foregroundStyle(ThemeManager.shared.colorWarning)
                    } else if printerManager.savedPeripheralUUID != nil {
                        Button("Riconnetti") { printerManager.reconnectIfSaved() }
                            .buttonStyle(.borderedProminent)
                    }

                    if printerManager.savedPeripheralUUID != nil {
                        Button("Dimentica", role: .destructive) { printerManager.forgetSavedPrinter() }
                            .buttonStyle(.bordered)
                    }
                }

                SettingsExpandableCard(title: "Protocollo stampa", caption: "Solo se la prova non funziona") {
                    protocolPickerContent
                }
            }
        }
    }

    // MARK: - Ricerca dispositivi

    private var discoveryCard: some View {
        SettingsPanelCard(title: "Dispositivi vicini", caption: "Accendi la stampante e avvia la ricerca.") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    if printerManager.connectionState == .scanning {
                        printerManager.stopScanning()
                    } else {
                        printerManager.startScanning()
                    }
                } label: {
                    HStack {
                        if printerManager.connectionState == .scanning {
                            ProgressView().scaleEffect(0.85)
                        }
                        Text(printerManager.connectionState == .scanning ? "Ferma ricerca" : "Cerca dispositivi")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ThemeManager.shared.colorSurfaceElevated)
                    .cornerRadius(10)
                }

                if printerManager.discoveredDevices.isEmpty {
                    Text(printerManager.connectionState == .scanning
                         ? "Ricerca in corso…"
                         : "Nessun dispositivo. Avvia la ricerca.")
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    VStack(spacing: 0) {
                        ForEach(printerManager.discoveredDevices) { device in
                            Button { printerManager.connect(to: device.id) } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.displayName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                        Text(device.signalDescription)
                                            .font(.caption2)
                                            .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                    }
                                    Spacer()
                                    if printerManager.savedPeripheralUUID == device.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(ThemeManager.shared.colorSuccess)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                }
                                .padding(.vertical, 10)
                            }
                            if device.id != printerManager.discoveredDevices.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var labelSizeSection: some View {
        SettingsPanelCard(
            title: "Formato rotolo",
            caption: "Rotolo fisso 50×30 mm (CLABEL S1)."
        ) {
            HStack {
                Text("Rotolo")
                Spacer()
                Text("50×30 mm")
                    .fontWeight(.semibold)
            }
            Text("Layout compatto: prodotto, date, lotto e QR piccolo.")
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
        }
    }

    private var labelFieldsSection: some View {
        @Bindable var storage = storage
        return SettingsPanelCard(title: "Campi etichetta") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Nome prodotto", isOn: $storage.printer.showProductName)
                Toggle("Data preparazione", isOn: $storage.printer.showPrepDate)
                Toggle("Data scadenza", isOn: $storage.printer.showExpiryDate)
                Toggle("Lotto", isOn: $storage.printer.showLotNumber)
                Toggle("Operatore", isOn: $storage.printer.showOperatorName)
                Toggle("Allergeni", isOn: $storage.printer.showAllergenWarning)
            }
            .font(.subheadline)
        }
        .onChange(of: storage.printer.showProductName) { storage.saveAll() }
        .onChange(of: storage.printer.showPrepDate) { storage.saveAll() }
        .onChange(of: storage.printer.showExpiryDate) { storage.saveAll() }
        .onChange(of: storage.printer.showLotNumber) { storage.saveAll() }
        .onChange(of: storage.printer.showOperatorName) { storage.saveAll() }
        .onChange(of: storage.printer.showAllergenWarning) { storage.saveAll() }
    }

    private var qrCodeSection: some View {
        @Bindable var storage = storage
        return SettingsPanelCard(title: "Codice QR", caption: "Scansione etichette solo dall’app su iPad") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Mostra QR su etichetta", isOn: $storage.printer.showQRCode)

                if storage.printer.showQRCode {
                    SettingsExpandableCard(title: "Posizione e dimensione QR", caption: "Predefiniti per \(storage.printer.clabelSize.displayName)") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Rotazione", selection: $storage.printer.qrRotationRaw) {
                                ForEach(LabelQRCodeRotation.allCases) { rotation in
                                    Text(rotation.label).tag(rotation.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)

                            Picker("Posizione", selection: $storage.printer.qrCornerRaw) {
                                ForEach(LabelQRCodeCorner.allCases) { corner in
                                    Text(corner.label).tag(corner.rawValue)
                                }
                            }
                            .pickerStyle(.menu)

                            Stepper(value: $storage.printer.qrCellSize, in: 2...8) {
                                Text("Moduli: \(storage.printer.qrCellSize)")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: storage.printer.showQRCode) { storage.saveAll() }
        .onChange(of: storage.printer.qrRotationRaw) { storage.saveAll() }
        .onChange(of: storage.printer.qrCornerRaw) { storage.saveAll() }
        .onChange(of: storage.printer.qrCellSize) { storage.saveAll() }
    }

    private var protocolPickerContent: some View {
        @Bindable var storage = storage
        return VStack(alignment: .leading, spacing: 8) {
            Picker("Protocollo", selection: $storage.printer.printEngineRaw) {
                ForEach(ClabelPrintEngine.allCases) { engine in
                    Text(engine.label).tag(engine.rawValue)
                }
            }
            .pickerStyle(.menu)
            Text("Prova «TSPL (testo)» se la stampa fallisce.")
                .font(.caption2)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            Button {
                Task { await runDiagnostics() }
            } label: {
                if isRunningDiagnostics {
                    ProgressView()
                } else {
                    Text("Diagnostica stampa")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isPrintingTest || isRunningDiagnostics)
        }
        .onChange(of: storage.printer.printEngineRaw) { storage.saveAll() }
    }

    private var statusText: String {
        switch printerManager.connectionState {
        case .connected:
            return printerManager.isReadyToPrint ? "Connessa e pronta a stampare" : "Connessa (canale stampa…)"
        case .printing: return "Stampa in corso…"
        case .scanning: return "Ricerca dispositivi…"
        case .connecting: return "Connessione in corso…"
        case .unauthorized: return "Permesso Bluetooth negato"
        case .poweredOff: return "Bluetooth spento"
        case .disconnected: return "Disconnessa"
        case .idle: return "Non connessa"
        }
    }

    private var statusColor: Color {
        switch printerManager.connectionState {
        case .connected: return ThemeManager.shared.colorSuccess
        case .printing, .connecting, .scanning: return ThemeManager.shared.colorInfo
        case .unauthorized, .poweredOff: return ThemeManager.shared.colorWarning
        default: return ThemeManager.shared.colorTextSecondary
        }
    }

    private func runDiagnostics() async {
        isRunningDiagnostics = true
        defer { isRunningDiagnostics = false }
        await printerManager.runPrintDiagnostics()
    }

    private func runTestPrint() async {
        isPrintingTest = true
        defer { isPrintingTest = false }
        do {
            try await printerManager.printTestPage()
        } catch {
            printerManager.lastErrorMessage = error.localizedDescription
        }
    }
}
