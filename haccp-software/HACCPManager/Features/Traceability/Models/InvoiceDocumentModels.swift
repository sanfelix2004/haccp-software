import Foundation

/// Tipo documento commerciale riconosciuto dalla foto.
enum InvoiceDocumentKind: String, Codable, Sendable {
    case ddt
    case fattura
    case unknown

    var label: String {
        switch self {
        case .ddt: return "Documento di trasporto (DDT)"
        case .fattura: return "Fattura"
        case .unknown: return "Documento"
        }
    }

    var isCommercialDocument: Bool {
        self == .ddt || self == .fattura
    }
}

/// Riga tabella estratta da fattura/DDT.
struct InvoiceLineItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var productCode: String?
    var lotCode: String?
    var description: String
    var unit: String?
    var quantity: Double?
    /// Di solito assente sui DDT; mai obbligatoria in questo flusso.
    var expiryDate: Date?

    init(
        id: UUID = UUID(),
        productCode: String? = nil,
        lotCode: String? = nil,
        description: String,
        unit: String? = nil,
        quantity: Double? = nil,
        expiryDate: Date? = nil
    ) {
        self.id = id
        self.productCode = productCode
        self.lotCode = lotCode
        self.description = description
        self.unit = unit
        self.quantity = quantity
        self.expiryDate = expiryDate
    }

    var displayLot: String {
        let trimmed = lotCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }

    var displayCode: String {
        let trimmed = productCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }

    /// Formato checklist: `Codice: X | Lotto: Y | Descrizione: Z`
    var checklistLabel: String {
        "Codice: \(displayCode) | Lotto: \(displayLot) | Descrizione: \(description)"
    }

    var quantityLabel: String? {
        guard let quantity else { return nil }
        let qty = quantity.formatted(.number.precision(.fractionLength(0...2)))
        if let unit, !unit.isEmpty {
            return "\(qty) \(unit)"
        }
        return qty
    }
}

/// Esito OCR di una foto di fattura/DDT.
struct InvoiceDocumentExtraction: Sendable {
    var documentKind: InvoiceDocumentKind
    var documentNumber: String?
    var documentDate: Date?
    var supplierName: String?
    var recipientName: String?
    var rows: [InvoiceLineItem]
    var confidence: Double
    var rawText: String?
    var auditLines: [String]

    var isRecognizedDocument: Bool {
        documentKind.isCommercialDocument || !rows.isEmpty
    }
}

/// Riga selezionata dall’utente, pronta per lo scatto foto + conferma.
struct InvoiceSelectedLine: Identifiable, Hashable {
    let id: UUID
    var line: InvoiceLineItem
    var suggestedTemplateId: UUID?
    var suggestedTemplateName: String?

    init(line: InvoiceLineItem, suggestedTemplateId: UUID? = nil, suggestedTemplateName: String? = nil) {
        self.id = line.id
        self.line = line
        self.suggestedTemplateId = suggestedTemplateId
        self.suggestedTemplateName = suggestedTemplateName
    }
}
