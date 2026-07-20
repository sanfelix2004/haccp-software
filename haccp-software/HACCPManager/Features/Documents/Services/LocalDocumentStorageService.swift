import Foundation

/// Path locali stabili per ristorante e periodo (pronti per mirror iCloud Drive).
final class LocalDocumentStorageService: LocalDocumentStorageProtocol {
    static let shared = LocalDocumentStorageService()
    private init() {}

    private let rootFolderName = "HACCPManager"

    func stablePDFDirectory(restaurantId: UUID) throws -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base
            .appendingPathComponent(rootFolderName, isDirectory: true)
            .appendingPathComponent(restaurantId.uuidString, isDirectory: true)
            .appendingPathComponent("PDF", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func relativePathForICloud(
        restaurantDisplayName: String,
        periodFolder: String,
        groupFolder: String?,
        moduleFolder: String,
        fileName: String
    ) -> String {
        let safeRestaurant = Self.sanitizeFolderName(restaurantDisplayName)
        let safeModule = Self.sanitizeFolderName(moduleFolder)
        if let groupFolder, !groupFolder.isEmpty {
            let safeGroup = Self.sanitizeFolderName(groupFolder)
            return "HACCP Manager/\(safeRestaurant)/\(periodFolder)/\(safeGroup)/\(safeModule)/\(fileName)"
        }
        return "HACCP Manager/\(safeRestaurant)/\(periodFolder)/\(safeModule)/\(fileName)"
    }

    static func sanitizeFolderName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " _-"))
        let scalars = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let collapsed = String(scalars).split(separator: " ").joined(separator: " ")
        return collapsed.isEmpty ? "Ristorante" : String(collapsed.prefix(48))
    }

    /// Nomi file professionali (slug ristorante + periodo).
    static func officialFileName(
        restaurantShortName: String,
        type: DocumentType,
        module: DocumentModule,
        interval: DateInterval,
        calendar: Calendar
    ) -> String {
        let slug = sanitizeFolderName(restaurantShortName).replacingOccurrences(of: " ", with: "_")
        let start = interval.start
        switch type {
        case .giornaliero:
            let c = calendar.dateComponents([.year, .month, .day], from: start)
            let d = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            if module == .haccpCombinato {
                return "\(d)_HACCP_\(slug)_Ricezione_Tracciabilita.pdf"
            }
            if module == .ricezioneMerci {
                return "\(d)_HACCP_\(slug)_Ricezione.pdf"
            }
            if module == .tracciabilita {
                return "\(d)_HACCP_\(slug)_Tracciabilita.pdf"
            }
            return "\(d)_HACCP_\(slug)_\(module.rawValue).pdf"
        case .mensile:
            let c = calendar.dateComponents([.year, .month], from: start)
            let m = String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
            if module == .nonConformita {
                return "\(m)_NonConformita_\(slug).pdf"
            }
            if module == .haccpCombinato {
                return "\(m)_HACCP_\(slug)_Report_Mensile.pdf"
            }
            if module == .combinatoIngressoTracciabilita {
                return "\(m)_HACCP_\(slug)_Ingresso_Tracciabilita.pdf"
            }
            if module == .combinatoTracciabilitaProduzione {
                return "\(m)_HACCP_\(slug)_Tracciabilita_Produzioni.pdf"
            }
            if module == .combinatoCatenaFreddo {
                return "\(m)_HACCP_\(slug)_Catena_Freddo.pdf"
            }
            if module == .combinatoIgieneControlli {
                return "\(m)_HACCP_\(slug)_Igiene_Controlli.pdf"
            }
            if module == .combinatoProduzione {
                return "\(m)_HACCP_\(slug)_Produzione.pdf"
            }
            if module == .controlloScadenze {
                return "\(m)_HACCP_\(slug)_Tracciabilita_Produzioni.pdf"
            }
            if module == .ricezioneMerci {
                return "\(m)_HACCP_\(slug)_Ricezione.pdf"
            }
            if module == .tracciabilita {
                return "\(m)_HACCP_\(slug)_Tracciabilita.pdf"
            }
            return "\(m)_HACCP_\(slug)_\(module.rawValue).pdf"
        case .settimanale:
            let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start)
            let yw = String(format: "%04d-W%02d", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
            if module == .haccpCombinato {
                return "\(yw)_HACCP_\(slug)_Report_Settimanale.pdf"
            }
            if module == .ricezioneMerci {
                return "\(yw)_HACCP_\(slug)_Ricezione_Settimanale.pdf"
            }
            if module == .tracciabilita {
                return "\(yw)_HACCP_\(slug)_Tracciabilita_Settimanale.pdf"
            }
            return "\(yw)_HACCP_\(slug)_\(module.rawValue).pdf"
        case .annuale:
            let y = calendar.component(.year, from: start)
            return "\(y)_HACCP_\(slug)_Report_Annuale.pdf"
        case .nonConformita:
            let c = calendar.dateComponents([.year, .month], from: start)
            let m = String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
            return "\(m)_NonConformita_\(slug).pdf"
        default:
            let c = calendar.dateComponents([.year, .month, .day], from: start)
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0) + "_\(slug)_documento.pdf"
        }
    }

    static func periodFolderLabel(type: DocumentType) -> String {
        switch type {
        case .mensile, .nonConformita, .giornaliero, .settimanale, .annuale:
            return "Mensili"
        default:
            return "Documenti"
        }
    }
}
