//
//  SettingsLegalTexts.swift
//  Indice documenti legali (Impostazioni → Info App).
//

import Foundation

enum SettingsLegalDocument: String, Identifiable, CaseIterable {
    case terms
    case privacy
    case cookies
    case legal
    case dataProcessor
    case licenses
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return "Termini e Condizioni"
        case .privacy: return "Informativa Privacy"
        case .cookies: return "Cookie e Tecnologie"
        case .legal: return "Note Legali HACCP"
        case .dataProcessor: return "Responsabile del Trattamento"
        case .licenses: return "Licenze Software"
        case .support: return "Supporto Tecnico"
        }
    }

    var subtitle: String {
        switch self {
        case .terms: return "Condizioni d'uso dell'applicazione"
        case .privacy: return "GDPR — trattamento dati personali"
        case .cookies: return "Archiviazione locale, iCloud, identificatori"
        case .legal: return "Disclaimer e riferimenti normativi"
        case .dataProcessor: return "Sintesi art. 28 GDPR per il ristoratore"
        case .licenses: return "Apple e componenti di sistema"
        case .support: return "Contatti e assistenza"
        }
    }

    var icon: String {
        switch self {
        case .terms: return "doc.text.fill"
        case .privacy: return "lock.doc.fill"
        case .cookies: return "hand.raised.fill"
        case .legal: return "scale.3d"
        case .dataProcessor: return "person.2.badge.gearshape.fill"
        case .licenses: return "shippingbox.fill"
        case .support: return "lifepreserver.fill"
        }
    }

    var body: String {
        switch self {
        case .terms: return LegalDocumentBodies.terms
        case .privacy: return LegalDocumentBodies.privacy
        case .cookies: return LegalDocumentBodies.cookies
        case .legal: return LegalDocumentBodies.legal
        case .dataProcessor: return LegalDocumentBodies.dataProcessor
        case .licenses: return LegalDocumentBodies.licenses
        case .support: return LegalDocumentBodies.support
        }
    }
}
