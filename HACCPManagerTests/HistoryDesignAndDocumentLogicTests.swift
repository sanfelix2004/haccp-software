import XCTest
@testable import HACCP_Manager

/// Badge Storia + regole chiusura per documenti/UI.
@MainActor
final class HistoryDesignAndDocumentLogicTests: XCTestCase {

    func testHistoryBadgeStyleForTerminato() {
        let entry = HistoryEntry(
            id: "t1",
            module: .traceability,
            title: "Astice",
            category: "Produzione",
            status: "Terminato",
            operatorName: "Chef",
            date: Date(),
            details: [],
            hasCriticality: false
        )
        XCTAssertEqual(entry.statusBadgeStyle, .info)
    }

    func testHistoryBadgeStyleForDisponibile() {
        let entry = HistoryEntry(
            id: "t2",
            module: .traceability,
            title: "Astice",
            category: "Produzione",
            status: "Disponibile",
            operatorName: "Chef",
            date: Date(),
            details: [],
            hasCriticality: false
        )
        XCTAssertEqual(entry.statusBadgeStyle, .conforme)
    }

    func testHistoryBadgeStyleForScartato() {
        let entry = HistoryEntry(
            id: "t3",
            module: .traceability,
            title: "Astice",
            category: "Produzione",
            status: "Scartato",
            operatorName: "Chef",
            date: Date(),
            details: [],
            hasCriticality: false
        )
        XCTAssertEqual(entry.statusBadgeStyle, .nonConforme)
    }

    func testOperationalStatusStyleFromOutcomeStrings() {
        XCTAssertEqual(TraceabilityLotOperationalStatus.style(forOutcome: "Terminato"), .info)
        XCTAssertEqual(TraceabilityLotOperationalStatus.style(forOutcome: "Scaduto"), .warning)
        XCTAssertEqual(TraceabilityLotOperationalStatus.style(forOutcome: "Scartato"), .nonConforme)
    }

    func testDocumentArchiveModuleLabelsExist() {
        // I due moduli mensili devono restare distinti.
        XCTAssertEqual(DocumentArchiveLayout.tracciabilitaProduzioneFolderTitle, "Tracciabilità")
        XCTAssertEqual(DocumentArchiveLayout.controlloScadenzeFolderTitle, "Controllo scadenze")
    }
}
