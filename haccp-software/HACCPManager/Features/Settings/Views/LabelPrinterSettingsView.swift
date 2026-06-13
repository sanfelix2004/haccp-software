import SwiftUI

struct LabelPrinterSettingsView: View {
    var storage = SettingsStorageService.shared
    @ObservedObject private var printerManager = ClabelPrinterManager.shared
    @State private var isPrintingTest = false
    @State private var isRunningDiagnostics = false

    var body: some View {
        @Bindable var storage = storage
        VStack(spacing: 24) {
            connectionCard
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "printer.fill")
                    .font(.title2)
                    .foregroundStyle(statusColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stampante CLABEL")
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                }
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
            }

            if let name = printerManager.connectedDeviceName, printerManager.isConnected {
                HStack {
                    Text("Collegata a")
                        .font(.subheadline)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    Spacer()
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                }
            } else if !storage.printer.savedPeripheralDisplayName.isEmpty {
                HStack {
                    Text("Salvata")
                        .font(.subheadline)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    Spacer()
                    Text(storage.printer.savedPeripheralDisplayName)
                        .font(.subheadline.weight(.semibold))
                }
            }

            Text("Etichette \(storage.printer.labelSize) · Bluetooth")
                .font(.caption2)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)

            if let channel = printerManager.connectedWriteChannel, printerManager.isConnected {
                Text("Canale: \(channel)")
                    .font(.caption2)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }

            if let ok = printerManager.lastSuccessMessage {
                Text(ok)
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.colorSuccess)
            }

            protocolPicker

            HStack(spacing: 12) {
                if printerManager.isReadyToPrint {
                    Button("Disconnetti") {
                        printerManager.disconnect()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await runTestPrint() }
                    } label: {
                        if isPrintingTest {
                            ProgressView()
                        } else {
                            Text("Stampa prova")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPrintingTest || isRunningDiagnostics)

                    Button {
                        Task { await runDiagnostics() }
                    } label: {
                        if isRunningDiagnostics {
                            ProgressView()
                        } else {
                            Text("Diagnostica")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isPrintingTest || isRunningDiagnostics)
                } else if printerManager.isConnected {
                    Text("Connessione in corso… attendi il canale di stampa.")
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.colorWarning)
                } else if printerManager.savedPeripheralUUID != nil {
                    Button("Riconnetti") {
                        printerManager.reconnectIfSaved()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if printerManager.savedPeripheralUUID != nil {
                    Button("Dimentica", role: .destructive) {
                        printerManager.forgetSavedPrinter()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ThemeManager.shared.colorSurface)
        .cornerRadius(20)
    }

    // MARK: - Ricerca dispositivi

    private var discoveryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Dispositivi Bluetooth vicini")
                    .font(.headline)
                Spacer()
                if printerManager.connectionState == .scanning {
                    ProgressView()
                        .scaleEffect(0.85)
                }
            }

            Text("Accendi la stampante CLABEL e selezionala dall'elenco. Non serve conoscere il nome esatto.")
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)

            Button {
                if printerManager.connectionState == .scanning {
                    printerManager.stopScanning()
                } else {
                    printerManager.startScanning()
                }
            } label: {
                Text(printerManager.connectionState == .scanning ? "Ferma ricerca" : "Cerca dispositivi...")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ThemeManager.shared.colorDivider)
                    .cornerRadius(10)
            }

            if printerManager.discoveredDevices.isEmpty {
                Text(printerManager.connectionState == .scanning
                     ? "Ricerca in corso… avvicina la stampante."
                     : "Nessun dispositivo trovato. Avvia la ricerca con la stampante accesa.")
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(printerManager.discoveredDevices) { device in
                        Button {
                            printerManager.connect(to: device.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .foregroundStyle(ThemeManager.shared.colorPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                    Text("Segnale \(device.signalDescription) · \(device.rssi) dBm")
                                        .font(.caption2)
                                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                }
                                Spacer()
                                if printerManager.savedPeripheralUUID == device.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ThemeManager.shared.colorSuccess)
                                }
                                if printerManager.connectionState == .connecting,
                                   printerManager.savedPeripheralUUID == device.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                        }
                        if device.id != printerManager.discoveredDevices.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ThemeManager.shared.colorSurface)
        .cornerRadius(20)
    }

    private var labelFieldsSection: some View {
        @Bindable var storage = storage
        return VStack(alignment: .leading, spacing: 20) {
            Text("Campi Etichetta Standard")
                .font(.headline)

            Group {
                Toggle("Nome Prodotto", isOn: $storage.printer.showProductName)
                Toggle("Data Preparazione", isOn: $storage.printer.showPrepDate)
                Toggle("Data Scadenza", isOn: $storage.printer.showExpiryDate)
                Toggle("Lotto Produzione", isOn: $storage.printer.showLotNumber)
                Toggle("Nome Operatore", isOn: $storage.printer.showOperatorName)
                Toggle("Avvisi Allergeni", isOn: $storage.printer.showAllergenWarning)
            }
            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
        }
        .padding()
        .background(ThemeManager.shared.colorSurface)
        .cornerRadius(16)
        .onChange(of: storage.printer.showProductName) { storage.saveAll() }
        .onChange(of: storage.printer.showPrepDate) { storage.saveAll() }
        .onChange(of: storage.printer.showExpiryDate) { storage.saveAll() }
        .onChange(of: storage.printer.showLotNumber) { storage.saveAll() }
        .onChange(of: storage.printer.showOperatorName) { storage.saveAll() }
        .onChange(of: storage.printer.showAllergenWarning) { storage.saveAll() }
    }

    private var qrCodeSection: some View {
        @Bindable var storage = storage
        return VStack(alignment: .leading, spacing: 20) {
            Text("Codice QR")
                .font(.headline)

            Toggle("Mostra QR su etichetta", isOn: $storage.printer.showQRCode)

            if storage.printer.showQRCode {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rotazione")
                        .font(.subheadline.weight(.semibold))
                    Picker("Rotazione QR", selection: $storage.printer.qrRotationRaw) {
                        ForEach(LabelQRCodeRotation.allCases) { rotation in
                            Text(rotation.label).tag(rotation.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Posizione")
                        .font(.subheadline.weight(.semibold))
                    Picker("Posizione QR", selection: $storage.printer.qrCornerRaw) {
                        ForEach(LabelQRCodeCorner.allCases) { corner in
                            Text(corner.label).tag(corner.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Stepper(
                        value: $storage.printer.qrCellSize,
                        in: 2...8,
                        step: 1
                    ) {
                        Text("Dimensione moduli: \(storage.printer.qrCellSize)")
                            .font(.subheadline)
                    }

                    Text("Scansiona il QR da Etichette di produzione per aprire subito prodotto, lotto e scadenza. QR compatto HC1 per stampa 50×30.")
                        .font(.caption2)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                }
            }
        }
        .padding()
        .background(ThemeManager.shared.colorSurface)
        .cornerRadius(16)
        .onChange(of: storage.printer.showQRCode) { storage.saveAll() }
        .onChange(of: storage.printer.qrRotationRaw) { storage.saveAll() }
        .onChange(of: storage.printer.qrCornerRaw) { storage.saveAll() }
        .onChange(of: storage.printer.qrCellSize) { storage.saveAll() }
    }

    private var protocolPicker: some View {
        @Bindable var storage = storage
        return VStack(alignment: .leading, spacing: 8) {
            Text("Protocollo stampa")
                .font(.subheadline.weight(.semibold))
            Picker("Protocollo", selection: $storage.printer.printEngineRaw) {
                ForEach(ClabelPrintEngine.allCases) { engine in
                    Text(engine.label).tag(engine.rawValue)
                }
            }
            .pickerStyle(.menu)
            Text("Se non stampa: prova «TSPL (testo)», poi «TSPL (immagine)». Usa «Stampa prova» dopo ogni cambio.")
                .font(.caption2)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
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
