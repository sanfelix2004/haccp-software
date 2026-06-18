import Foundation
import SwiftData

enum DocumentType: String, Codable, CaseIterable {
    case giornaliero = "GIORNALIERO"
    case settimanale = "SETTIMANALE"
    case mensile = "MENSILE"
    case annuale = "ANNUALE"
    case nonConformita = "NON_CONFORMITA"
    case temporaneo = "TEMPORANEO"

    var label: String {
        switch self {
        case .giornaliero: return "Giornaliero"
        case .settimanale: return "Settimanale"
        case .mensile: return "Mensile"
        case .annuale: return "Annuale"
        case .nonConformita: return "Non conformità"
        case .temporaneo: return "Temporaneo"
        }
    }
}

enum HACCPExportFormat: String, Codable, CaseIterable {
    case pdf = "PDF"
    case csv = "CSV"

    var label: String {
        switch self {
        case .pdf: return "PDF"
        case .csv: return "CSV"
        }
    }
}

enum DocumentModule: String, Codable, CaseIterable {
    case ricezioneMerci = "RICEZIONE_MERCI"
    case tracciabilita = "TRACCIABILITA"
    case haccpCombinato = "HACCP_COMBINATO"
    case nonConformita = "REGISTRO_NON_CONFORMITA"
    case frigoriferi = "FRIGORIFERI"
    case controlloPulizia = "CONTROLLO_PULIZIA"
    case abbattimento = "ABBATTIMENTO"
    case programmazione = "PROGRAMMAZIONE"
    case controlloScadenze = "CONTROLLO_SCADENZE"
    case decongelamento = "DECONGELAMENTO"
    case controlloOlio = "CONTROLLO_OLIO"
    case etichetteProduzione = "ETICHETTE_PRODUZIONE"
    case checklist = "CHECKLIST"
    case combinatoIngressoTracciabilita = "COMBINATO_INGRESSO_TRACCIABILITA"
    case combinatoCatenaFreddo = "COMBINATO_CATENA_FREDDO"
    case combinatoIgieneControlli = "COMBINATO_IGIENE_CONTROLLI"
    case combinatoProduzione = "COMBINATO_PRODUZIONE"

    var label: String {
        switch self {
        case .ricezioneMerci: return "Ricezione merci"
        case .tracciabilita: return "Tracciabilità"
        case .haccpCombinato: return "HACCP combinato"
        case .nonConformita: return "Registro non conformità"
        case .frigoriferi: return "Frigoriferi"
        case .controlloPulizia: return "Controllo pulizia"
        case .abbattimento: return "Abbattimento"
        case .programmazione: return "Programmazione"
        case .controlloScadenze: return "Controllo scadenze"
        case .decongelamento: return "Decongelamento"
        case .controlloOlio: return "Controllo olio"
        case .etichetteProduzione: return "Etichette di produzione"
        case .checklist: return "Checklist"
        case .combinatoIngressoTracciabilita: return "Ingresso e tracciabilità"
        case .combinatoCatenaFreddo: return "Catena del freddo"
        case .combinatoIgieneControlli: return "Igiene e controlli"
        case .combinatoProduzione: return "Produzione ed etichettatura"
        }
    }

    var isCombinedArchive: Bool {
        switch self {
        case .haccpCombinato,
             .combinatoIngressoTracciabilita,
             .combinatoCatenaFreddo,
             .combinatoIgieneControlli,
             .combinatoProduzione:
            return true
        default:
            return false
        }
    }
}

enum DocumentStatus: String, Codable, CaseIterable {
    case generato = "GENERATO"
    case esportato = "ESPORTATO"
    case sincronizzato = "SINCRONIZZATO"
    case fallito = "FALLITO"

    var label: String {
        switch self {
        case .generato: return "Generato"
        case .esportato: return "Esportato"
        case .sincronizzato: return "Sincronizzato"
        case .fallito: return "Fallito"
        }
    }
}

@Model
final class DocumentItem {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var folderId: UUID
    var title: String = ""
    var fileName: String
    var typeRaw: String = DocumentType.temporaneo.rawValue
    var moduleRaw: String = DocumentModule.haccpCombinato.rawValue
    var periodStart: Date?
    var periodEnd: Date?
    var generatedAt: Date = Date()
    var filePath: String
    var statusRaw: String = DocumentStatus.generato.rawValue
    var formatRaw: String = HACCPExportFormat.pdf.rawValue
    var isExported: Bool = false
    var exportedAt: Date?
    var sizeInBytes: Int64 = 0
    /// Identificativo ufficiale stampato sul PDF (stabile, audit-ready).
    var officialDocumentId: String = ""
    /// SHA-256 del file PDF finale (post-elaborazione).
    var checksumSHA256: String = ""
    var documentSchemaVersion: Int = 1
    /// Versione app al momento della generazione (es. 1.2.0 build 3).
    var documentBuildVersion: String = ""
    var isSyncedToICloud: Bool = false
    /// Percorso relativo previsto su iCloud Drive (futuro sync).
    var iCloudRelativePath: String?
    /// Se false, il PDF è stato rimosso localmente ma il record resta per rigenerazione.
    var localFilePresent: Bool = true
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        folderId: UUID,
        title: String,
        fileName: String,
        type: DocumentType,
        module: DocumentModule,
        periodStart: Date? = nil,
        periodEnd: Date? = nil,
        generatedAt: Date = Date(),
        filePath: String,
        format: HACCPExportFormat = .pdf,
        status: DocumentStatus = .generato,
        isExported: Bool = false,
        exportedAt: Date? = nil,
        sizeInBytes: Int64 = 0,
        officialDocumentId: String? = nil,
        checksumSHA256: String = "",
        documentSchemaVersion: Int = 1,
        documentBuildVersion: String = "",
        isSyncedToICloud: Bool = false,
        iCloudRelativePath: String? = nil,
        localFilePresent: Bool = true,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.folderId = folderId
        self.title = title
        self.fileName = fileName
        self.typeRaw = type.rawValue
        self.moduleRaw = module.rawValue
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.generatedAt = generatedAt
        self.filePath = filePath
        self.formatRaw = format.rawValue
        self.statusRaw = status.rawValue
        self.isExported = isExported
        self.exportedAt = exportedAt
        self.sizeInBytes = sizeInBytes
        self.officialDocumentId = officialDocumentId ?? "HACCP-DOC-\(id.uuidString.uppercased())"
        self.checksumSHA256 = checksumSHA256
        self.documentSchemaVersion = documentSchemaVersion
        self.documentBuildVersion = documentBuildVersion
        self.isSyncedToICloud = isSyncedToICloud
        self.iCloudRelativePath = iCloudRelativePath
        self.localFilePresent = localFilePresent
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
    }

    var type: DocumentType {
        get { DocumentType(rawValue: typeRaw) ?? .temporaneo }
        set { typeRaw = newValue.rawValue }
    }

    var module: DocumentModule {
        get { DocumentModule(rawValue: moduleRaw) ?? .haccpCombinato }
        set { moduleRaw = newValue.rawValue }
    }

    var status: DocumentStatus {
        get { DocumentStatus(rawValue: statusRaw) ?? .generato }
        set { statusRaw = newValue.rawValue }
    }

    var format: HACCPExportFormat {
        get { HACCPExportFormat(rawValue: formatRaw) ?? .pdf }
        set { formatRaw = newValue.rawValue }
    }
}

typealias DocumentRecord = DocumentItem
