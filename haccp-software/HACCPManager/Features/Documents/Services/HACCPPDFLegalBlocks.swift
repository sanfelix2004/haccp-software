import Foundation

/// Blocchi testuali e sezioni finali comuni ai registri HACCP.
enum HACCPPDFLegalBlocks {
    static let normativeReference =
        "Reg. (CE) n. 852/2004, Reg. (CE) n. 853/2004, D.Lgs. 193/2007 e piano di autocontrollo igienico-sanitario dell'esercizio."

    static func preambleParagraphs() -> [String] {
        [
            "Il presente documento è redatto nell'ambito del sistema di autocontrollo basato sui principi HACCP ed costituisce evidenza documentale delle attività di controllo registrate nel periodo indicato.",
            "I dati riportati derivano esclusivamente dalle registrazioni inserite dagli operatori autorizzati tramite l'applicazione \(LegalConstants.appName). In assenza di attività nel periodo, le sezioni operative riportano l'annotazione «\(HACCPRegisterCopy.noActivityInPeriod)».",
            "Il documento non sostituisce il piano HACCP approvato, le procedure aziendali né le verifiche delle Autorità competenti."
        ]
    }

    static func conservationParagraphs() -> [String] {
        [
            "Conservare il presente registro per il periodo previsto dal piano di autocontrollo e dalla normativa vigente in materia di registrazioni HACCP (in genere non inferiore a 6–12 mesi, salvo obblighi più lunghi per specifiche attività o registri).",
            "L'identificativo univoco e l'impronta digitale SHA-256 sono registrati nell'archivio documentale dell'applicazione al momento della generazione, a garanzia dell'integrità del file archiviato."
        ]
    }

    static func authenticityParagraphs(haccpManager: String) -> [String] {
        let manager = haccpManager.trimmingCharacters(in: .whitespacesAndNewlines)
        let responsible = manager.isEmpty ? "il Responsabile dell'autocontrollo igienico-sanitario" : manager
        return [
            "Il sottoscritto \(responsible) dichiara, sotto la propria responsabilità, che le informazioni contenute nel presente documento corrispondono alle attività di controllo effettivamente svolte nel periodo di riferimento, nei limiti dei dati registrati in app.",
            "Le firme in calce attestano la presa visione e l'archiviazione del documento nell'ambito del sistema documentale HACCP del locale."
        ]
    }

    static func signatureBlock(haccpManager: String) -> HACCPPDFSignatureBlock {
        let manager = haccpManager.trimmingCharacters(in: .whitespacesAndNewlines)
        let managerLine = manager.isEmpty ? "Responsabile autocontrollo igienico-sanitario" : "Responsabile HACCP: \(manager)"
        return HACCPPDFSignatureBlock(
            intro: "Firme per presa visione e archiviazione",
            roles: [
                managerLine,
                "Titolare / Legale rappresentante dell'esercizio",
                "Operatore di chiusura periodo (se diverso)"
            ]
        )
    }

    static func appendClosingSections(to sections: inout [HACCPPDFSection], restaurant: Restaurant) {
        sections.append(.prose(
            title: "Note sulla conservazione",
            paragraphs: conservationParagraphs()
        ))
        sections.append(.prose(
            title: "Dichiarazione di veridicità",
            paragraphs: authenticityParagraphs(haccpManager: restaurant.haccpManager)
        ))
        sections.append(.signatures(
            title: "Approvazione e firme",
            block: signatureBlock(haccpManager: restaurant.haccpManager)
        ))
    }
}
