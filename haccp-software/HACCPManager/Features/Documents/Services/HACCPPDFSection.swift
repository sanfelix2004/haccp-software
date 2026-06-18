import Foundation

/// Sezione di un documento PDF ufficiale HACCP (tabelle, testo normativo, firme).
struct HACCPPDFSection: Sendable {
    let title: String
    let subtitle: String?
    let content: HACCPPDFSectionContent

    init(title: String, subtitle: String? = nil, content: HACCPPDFSectionContent) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    static func keyValueTable(
        title: String,
        subtitle: String? = nil,
        headers: [String] = ["Campo", "Valore"],
        rows: [[PDFTableCell]]
    ) -> HACCPPDFSection {
        HACCPPDFSection(title: title, subtitle: subtitle, content: .keyValueTable(headers: headers, rows: rows))
    }

    static func dataTable(
        title: String,
        subtitle: String? = nil,
        headers: [String],
        rows: [[PDFTableCell]]
    ) -> HACCPPDFSection {
        HACCPPDFSection(title: title, subtitle: subtitle, content: .dataTable(headers: headers, rows: rows))
    }

    static func prose(title: String, subtitle: String? = nil, paragraphs: [String]) -> HACCPPDFSection {
        HACCPPDFSection(title: title, subtitle: subtitle, content: .prose(paragraphs))
    }

    static func signatures(title: String, block: HACCPPDFSignatureBlock) -> HACCPPDFSection {
        HACCPPDFSection(title: title, content: .signatures(block))
    }
}

enum HACCPPDFSectionContent: Sendable {
    case keyValueTable(headers: [String], rows: [[PDFTableCell]])
    case dataTable(headers: [String], rows: [[PDFTableCell]])
    case prose([String])
    case signatures(HACCPPDFSignatureBlock)
}

struct HACCPPDFSignatureBlock: Sendable {
    let intro: String
    let roles: [String]
}

/// Metadati mostrati nell'intestazione grafica di ogni PDF.
struct HACCPPDFDocumentContext: Sendable {
    let restaurantName: String
    let reportTitle: String
    let periodLine: String
    let reportDateLine: String
    let officialDocumentId: String
    let generatedAt: Date
    let haccpManager: String
    let restaurantAddress: String
    let restaurantContacts: String
}

typealias HACCPPDFSectionBundle = (sections: [HACCPPDFSection], flags: OfficialReportSectionFlags)
