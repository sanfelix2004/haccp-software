import CoreBluetooth
import Foundation
import Combine

@MainActor
final class ClabelPrinterManager: NSObject, ObservableObject {

    static let shared = ClabelPrinterManager()

    enum ConnectionState: Equatable {
        case idle
        case scanning
        case connecting
        case connected
        case printing
        case disconnected
        case unauthorized
        case poweredOff
    }

    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var discoveredDevices: [DiscoveredBLEDevice] = []
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var connectedWriteChannel: String?
    @Published var lastErrorMessage: String?
    @Published var lastSuccessMessage: String?

    private static let savedUUIDKey = "clabel.printer.peripheralUUID"
    private static let savedNameKey = "clabel.printer.peripheralName"

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var writeUsesResponse = true
    private var peripheralByID: [UUID: CBPeripheral] = [:]
    private var writeContinuation: CheckedContinuation<Void, Error>?

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    var isConnected: Bool { connectionState == .connected || connectionState == .printing }

    var isReadyToPrint: Bool { isConnected && writeCharacteristic != nil }

    var savedPeripheralUUID: UUID? {
        guard let raw = UserDefaults.standard.string(forKey: Self.savedUUIDKey) else { return nil }
        return UUID(uuidString: raw)
    }

    // MARK: - Scan

    func startScanning() {
        lastErrorMessage = nil
        guard centralManager.state == .poweredOn else {
            syncStateFromCentral()
            return
        }
        discoveredDevices = []
        peripheralByID = [:]
        connectionState = .scanning
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    func stopScanning() {
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = connectedPeripheral != nil ? .connected : .idle
        }
    }

    // MARK: - Connect

    func connect(to deviceID: UUID) {
        stopScanning()
        guard let peripheral = peripheralByID[deviceID] ?? retrievePeripheral(id: deviceID) else {
            lastErrorMessage = "Dispositivo non trovato. Avvia una nuova ricerca."
            return
        }
        if connectedPeripheral?.identifier != deviceID {
            if let current = connectedPeripheral {
                centralManager.cancelPeripheralConnection(current)
            }
            connectedPeripheral = nil
            writeCharacteristic = nil
        }
        connectionState = .connecting
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        stopScanning()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        writeCharacteristic = nil
        connectedWriteChannel = nil
        connectedDeviceName = nil
        connectionState = .disconnected
    }

    func reconnectIfSaved() {
        guard centralManager.state == .poweredOn,
              let uuid = savedPeripheralUUID,
              connectedPeripheral == nil else { return }
        connect(to: uuid)
    }

    func forgetSavedPrinter() {
        UserDefaults.standard.removeObject(forKey: Self.savedUUIDKey)
        UserDefaults.standard.removeObject(forKey: Self.savedNameKey)
        SettingsStorageService.shared.printer.savedPeripheralIdentifier = ""
        SettingsStorageService.shared.printer.savedPeripheralDisplayName = ""
        SettingsStorageService.shared.saveAll()
        disconnect()
    }

    // MARK: - Print

    func printTestPage() async throws {
        lastErrorMessage = nil
        lastSuccessMessage = nil
        let engine: ClabelPrintEngine = {
            let pref = SettingsStorageService.shared.printer.printEngine
            return pref == .auto ? .tsplText : pref
        }()
        let job = jobData(for: engine, label: nil, settings: SettingsStorageService.shared.printer, test: true)
        try await sendPrintJob(job)
        lastSuccessMessage = "Comandi inviati (\(engine.label)). Se non esce nulla, cambia protocollo sotto."
    }

    func print(label: ProductionLabelRecord, settings: LabelPrinterSettings, restaurantName: String? = nil) async throws {
        lastErrorMessage = nil
        lastSuccessMessage = nil
        let engine: ClabelPrintEngine = settings.printEngine == .auto ? .tsplText : settings.printEngine
        let job = jobData(for: engine, label: label, settings: settings, test: false, restaurantName: restaurantName)
        try await sendPrintJob(job)
        lastSuccessMessage = "Etichetta inviata (\(engine.label))."
    }

    func printWithFallback(
        label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        restaurantName: String? = nil
    ) async throws {
        let primary: ClabelPrintEngine = settings.printEngine == .auto ? .tsplText : settings.printEngine
        let fallbacks: [ClabelPrintEngine] = [.tsplText, .tsplBitmap, .escPosLujiang, .escPosAiYin]
            .filter { $0 != primary }

        do {
            let job = jobData(for: primary, label: label, settings: settings, test: false, restaurantName: restaurantName)
            try await sendPrintJob(job)
            lastSuccessMessage = "Etichetta inviata (\(primary.label))."
        } catch {
            for engine in fallbacks {
                do {
                    let job = jobData(for: engine, label: label, settings: settings, test: false, restaurantName: restaurantName)
                    try await sendPrintJob(job)
                    lastSuccessMessage = "Etichetta inviata (\(engine.label), fallback)."
                    SettingsStorageService.shared.printer.printEngine = engine
                    SettingsStorageService.shared.saveAll()
                    return
                } catch {
                    continue
                }
            }
            throw error
        }
    }

    /// Prova ogni protocollo in sequenza (diagnostica). Può stampare più etichette di test.
    func runPrintDiagnostics() async {
        lastErrorMessage = nil
        lastSuccessMessage = nil
        let engines: [ClabelPrintEngine] = [.tsplText, .tsplBitmap, .escPosLujiang, .escPosAiYin]
        var sent: [String] = []
        for engine in engines {
            do {
                let job = jobData(for: engine, label: nil, settings: SettingsStorageService.shared.printer, test: true)
                try await sendPrintJob(job)
                sent.append(engine.label)
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                lastErrorMessage = "\(engine.label): \(error.localizedDescription)"
                return
            }
        }
        lastSuccessMessage = "Diagnostica inviata: \(sent.joined(separator: " → ")). Controlla quale etichetta è uscita corretta e seleziona quel protocollo."
    }

    private func jobData(
        for engine: ClabelPrintEngine,
        label: ProductionLabelRecord?,
        settings: LabelPrinterSettings,
        test: Bool,
        restaurantName: String? = nil
    ) -> Data {
        let spec = settings.labelSpec
        let widthBytes = spec.widthBytes
        let heightDots = spec.heightDots

        switch engine {
        case .auto:
            return ClabelTSPLProtocol.buildTestJob(spec: spec)
        case .tsplText:
            if test {
                return ClabelTSPLProtocol.buildTestJob(spec: spec)
            }
            guard let label else { return ClabelTSPLProtocol.buildTestJob(spec: spec) }
            return ClabelTSPLProtocol.buildTextJob(label: label, settings: settings, restaurantName: restaurantName)
        case .tsplBitmap:
            if test {
                return ClabelTSPLProtocol.buildTestJob(spec: spec)
            }
            guard let label else { return ClabelTSPLProtocol.buildTestJob(spec: spec) }
            let raster = ProductionLabelBitmapRenderer.raster(
                for: label,
                settings: settings,
                restaurantName: restaurantName
            )
            return ClabelTSPLProtocol.buildBitmapJob(raster: raster, spec: spec)
        case .escPosLujiang:
            if test {
                return ClabelThermalProtocol.buildTestPattern(widthBytes: widthBytes, heightDots: heightDots)
            }
            guard let label else { return ClabelThermalProtocol.buildTestPattern(widthBytes: widthBytes, heightDots: heightDots) }
            let raster = ProductionLabelBitmapRenderer.raster(
                for: label,
                settings: settings,
                restaurantName: restaurantName
            )
            return ClabelThermalProtocol.buildPrintJob(
                raster: raster,
                widthBytes: widthBytes,
                heightDots: heightDots,
                variant: .lujiang
            )
        case .escPosAiYin:
            if test {
                return ClabelThermalProtocol.buildTestPattern(widthBytes: widthBytes, heightDots: heightDots)
            }
            guard let label else { return ClabelThermalProtocol.buildTestPattern(widthBytes: widthBytes, heightDots: heightDots) }
            let raster = ProductionLabelBitmapRenderer.raster(
                for: label,
                settings: settings,
                restaurantName: restaurantName
            )
            return ClabelThermalProtocol.buildPrintJob(
                raster: raster,
                widthBytes: widthBytes,
                heightDots: heightDots,
                variant: .aiYin
            )
        }
    }

    // MARK: - Private

    private func retrievePeripheral(id: UUID) -> CBPeripheral? {
        centralManager.retrievePeripherals(withIdentifiers: [id]).first
    }

    private func syncStateFromCentral() {
        switch centralManager.state {
        case .poweredOn:
            if connectedPeripheral != nil, writeCharacteristic != nil {
                connectionState = .connected
            } else if connectionState != .scanning && connectionState != .connecting {
                connectionState = .idle
            }
        case .poweredOff:
            connectionState = .poweredOff
        case .unauthorized:
            connectionState = .unauthorized
        default:
            connectionState = .idle
        }
    }

    private func persistSelection(peripheral: CBPeripheral, displayName: String) {
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Self.savedUUIDKey)
        UserDefaults.standard.set(displayName, forKey: Self.savedNameKey)
        SettingsStorageService.shared.printer.savedPeripheralIdentifier = peripheral.identifier.uuidString
        SettingsStorageService.shared.printer.savedPeripheralDisplayName = displayName
        SettingsStorageService.shared.printer.defaultPrinterName = displayName
        SettingsStorageService.shared.saveAll()
    }

    private func clearConnection(savePreference: Bool, keepSavedUUID: Bool) {
        connectedPeripheral = nil
        writeCharacteristic = nil
        connectedDeviceName = keepSavedUUID ? connectedDeviceName : nil
        if !keepSavedUUID && !savePreference {
            connectedDeviceName = nil
        }
    }

    private func displayName(for peripheral: CBPeripheral, advertisement: [String: Any]?) -> String {
        if let name = peripheral.name, !name.isEmpty { return name }
        if let local = advertisement?[CBAdvertisementDataLocalNameKey] as? String, !local.isEmpty {
            return local
        }
        return "Dispositivo Bluetooth"
    }

    private func upsertDiscovery(_ peripheral: CBPeripheral, name: String, rssi: Int) {
        peripheralByID[peripheral.identifier] = peripheral
        let device = DiscoveredBLEDevice(id: peripheral.identifier, displayName: name, rssi: rssi)
        if let idx = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[idx] = device
        } else {
            discoveredDevices.append(device)
        }
        discoveredDevices.sort { $0.rssi > $1.rssi }
    }

    private func resolveWriteCharacteristic(from peripheral: CBPeripheral) -> CBCharacteristic? {
        let targets: [(CBUUID, CBUUID)] = [
            (CBUUID(string: "0000FF00-0000-1000-8000-00805F9B34FB"), CBUUID(string: "0000FF02-0000-1000-8000-00805F9B34FB")),
            (CBUUID(string: "000018F0-0000-1000-8000-00805F9B34FB"), CBUUID(string: "00002AF1-0000-1000-8000-00805F9B34FB")),
            (CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455"), CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")),
            (CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2"), CBUUID(string: "BEF8D6C9-9C21-4C9E-B632-BA0C9691F9D3"))
        ]
        for service in peripheral.services ?? [] {
            for (serviceUUID, charUUID) in targets where service.uuid == serviceUUID {
                if let match = service.characteristics?.first(where: { $0.uuid == charUUID }) {
                    return match
                }
            }
        }
        for service in peripheral.services ?? [] {
            if let writable = service.characteristics?.first(where: {
                $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse)
            }) {
                return writable
            }
        }
        return nil
    }

    private func sendPrintJob(_ data: Data) async throws {
        guard let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else {
            throw ClabelPrinterError.notConnected
        }
        let previous = connectionState
        connectionState = .printing
        defer {
            if connectionState == .printing {
                connectionState = .connected
            }
        }

        let writeType: CBCharacteristicWriteType = writeUsesResponse ? .withResponse : .withoutResponse
        let maxLen = peripheral.maximumWriteValueLength(for: writeType)
        let chunkSize = max(20, min(maxLen, writeUsesResponse ? 512 : 128))
        var offset = 0

        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunk = data.subdata(in: offset..<end)

            if writeType == .withoutResponse {
                var waitAttempts = 0
                while !peripheral.canSendWriteWithoutResponse, waitAttempts < 200 {
                    try await Task.sleep(nanoseconds: 10_000_000)
                    waitAttempts += 1
                }
                if !peripheral.canSendWriteWithoutResponse {
                    throw ClabelPrinterError.printTimeout
                }
            }

            try await writeChunk(chunk, type: writeType)
            offset = end
            let pause: UInt64 = writeType == .withoutResponse ? 45_000_000 : 20_000_000
            try await Task.sleep(nanoseconds: pause)
        }
        try await Task.sleep(nanoseconds: 800_000_000)
    }

    private func writeChunk(_ chunk: Data, type: CBCharacteristicWriteType) async throws {
        guard let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else {
            throw ClabelPrinterError.notConnected
        }
        if type == .withoutResponse {
            peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
            return
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writeContinuation = continuation
            peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension ClabelPrinterManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            syncStateFromCentral()
            if central.state == .poweredOn {
                reconnectIfSaved()
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            let name = displayName(for: peripheral, advertisement: advertisementData)
            upsertDiscovery(peripheral, name: name, rssi: RSSI.intValue)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectionState = .connecting
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            connectionState = .disconnected
            lastErrorMessage = error?.localizedDescription ?? "Connessione fallita."
            clearConnection(savePreference: false, keepSavedUUID: true)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            clearConnection(savePreference: false, keepSavedUUID: true)
            connectionState = .disconnected
            if let error {
                lastErrorMessage = error.localizedDescription
            }
            if central.state == .poweredOn, savedPeripheralUUID != nil {
                try? await Task.sleep(nanoseconds: 800_000_000)
                reconnectIfSaved()
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension ClabelPrinterManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                lastErrorMessage = error.localizedDescription
                connectionState = .disconnected
                return
            }
            for service in peripheral.services ?? [] {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                lastErrorMessage = error.localizedDescription
                return
            }
            guard writeCharacteristic == nil else { return }

            let services = peripheral.services ?? []
            let allExplored = !services.isEmpty && services.allSatisfy { $0.characteristics != nil }
            guard allExplored else { return }

            if let resolved = resolveWriteCharacteristic(from: peripheral) {
                writeCharacteristic = resolved
                if resolved.properties.contains(.writeWithoutResponse) {
                    writeUsesResponse = false
                } else {
                    writeUsesResponse = resolved.properties.contains(.write)
                }
                connectedWriteChannel = "\(resolved.service?.uuid.uuidString ?? "?") / \(resolved.uuid.uuidString)"
                let name = peripheral.name
                    ?? discoveredDevices.first(where: { $0.id == peripheral.identifier })?.displayName
                    ?? UserDefaults.standard.string(forKey: Self.savedNameKey)
                    ?? "Stampante"
                connectedDeviceName = name
                connectionState = .connected
                persistSelection(peripheral: peripheral, displayName: name)
                for svc in services {
                    if let notify = svc.characteristics?.first(where: {
                        $0.properties.contains(.notify) || $0.properties.contains(.indicate)
                    }) {
                        peripheral.setNotifyValue(true, for: notify)
                        break
                    }
                }
            } else {
                lastErrorMessage = ClabelPrinterError.characteristicNotFound.errorDescription
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            guard let continuation = writeContinuation else { return }
            writeContinuation = nil
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
    }
}
