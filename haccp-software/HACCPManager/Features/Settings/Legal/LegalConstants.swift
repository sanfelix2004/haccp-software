//
//  LegalConstants.swift
//  Dati anagrafici del titolare — aggiornare prima della pubblicazione su App Store.
//

import Foundation

enum LegalConstants {
    static let appName = "HACCP Manager"
    static let dataController = "Romanazzi IT Solutions"
    static let registeredOffice = "Italia" // Completare con indirizzo sede legale
    static let vatNumber = "—" // Completare con P.IVA / C.F.
    static let supportEmail = "romanazzi.sanfelice004@gmail.com"
    static let privacyEmail = "sanfelicefrancesco004@gmail.com"
    static let website = "https://romanazzi.it" // Completare se disponibile
    static let lastUpdated = "18 giugno 2026"
    static let governingLaw = "Repubblica Italiana"
    static let competentCourt = "foro del consumatore o, per clienti professionali, foro di residenza del Titolare"

    static var documentFooter: String {
        """
        —

        Ultimo aggiornamento: \(lastUpdated)
        \(appName) · \(dataController)
        Contatti: \(privacyEmail) · \(supportEmail)
        """
    }
}
