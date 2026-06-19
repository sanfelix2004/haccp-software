import CoreGraphics

/// Formato pagina PDF ufficiale (punti PostScript, 72 dpi).
enum HACCPPDFPageLayout {
    static let a4Portrait = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    static let a4Landscape = CGRect(x: 0, y: 0, width: 841.89, height: 595.28)
    static let margin: CGFloat = 40

    /// Fascia riservata al piè di pagina ufficiale (post-stampa con `HACCPPDFOfficialFooterStamper`).
    static let officialFooterBandHeight: CGFloat = 22
    /// Spazio minimo tra ultima riga tabella e fascia footer.
    static let footerContentGap: CGFloat = 14

    /// Y massima (bordo inferiore) per il corpo: il contenuto non deve mai superarla.
    static func contentBottomY(pageRect: CGRect) -> CGFloat {
        pageRect.height - margin - officialFooterBandHeight - footerContentGap
    }

    /// Tabelle ampie (ricezione / tracciabilità) in orizzontale A4; gli altri registri in verticale A4.
    static func pageRect(for module: DocumentModule) -> CGRect {
        switch module {
        case .combinatoIngressoTracciabilita, .ricezioneMerci, .tracciabilita, .haccpCombinato:
            return a4Landscape
        default:
            return a4Portrait
        }
    }

    static func bodyFontSize(for module: DocumentModule) -> CGFloat {
        switch module {
        case .combinatoIngressoTracciabilita, .ricezioneMerci, .tracciabilita, .haccpCombinato:
            return 7.8
        default:
            return 9.2
        }
    }
}
