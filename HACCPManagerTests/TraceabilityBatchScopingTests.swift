import XCTest
import SwiftData
@testable import HACCP_Manager

/// Ingredienti per lotto (batch): Burro di Astice #1 non deve finire su Astice #2.
@MainActor
final class TraceabilityBatchScopingTests: XCTestCase {

    private var restaurantId: UUID!
    private var userId: UUID!
    private var productionId: UUID!

    override func setUp() {
        super.setUp()
        restaurantId = UUID()
        userId = UUID()
        productionId = UUID()
    }

    func testArchiveGroupsScopeIngredientsPerBatch() {
        let batch1 = makeBatch(code: "20260720-10", producedAt: Date().addingTimeInterval(-120))
        let batch2 = makeBatch(code: "20260720-11", producedAt: Date())

        let lottoBurro = UUID()
        let lottoMenta = UUID()
        let lottoRosmarino = UUID()

        let burro = makeIncoming(name: "Burro", lot: "B1", lottoId: lottoBurro)
        let menta = makeIncoming(name: "MENTA", lot: "524168", lottoId: lottoMenta)
        let rosmarino = makeIncoming(name: "ROSMARINO", lot: "524154", lottoId: lottoRosmarino)

        let production = Production(
            id: productionId,
            restaurantId: restaurantId,
            name: "Astice",
            categoryId: UUID(),
            categoryNameSnapshot: "Secondi",
            isCustom: true
        )

        let lottoLinks = [
            LottoFotoProductionLink(
                lottoFotoId: lottoBurro,
                productionId: productionId,
                produzioneBatchId: batch1.id
            ),
            LottoFotoProductionLink(
                lottoFotoId: lottoMenta,
                productionId: productionId,
                produzioneBatchId: batch2.id
            ),
            LottoFotoProductionLink(
                lottoFotoId: lottoRosmarino,
                productionId: productionId,
                produzioneBatchId: batch2.id
            )
        ]

        // Link legacy senza batch (Burro collegato al piatto): non deve contaminare batch2.
        let legacyLinks = [
            TraceabilityLink(
                receivedItemId: burro.id,
                productionId: productionId,
                produzioneBatchId: nil
            ),
            TraceabilityLink(
                receivedItemId: menta.id,
                productionId: productionId,
                produzioneBatchId: batch2.id
            ),
            TraceabilityLink(
                receivedItemId: rosmarino.id,
                productionId: productionId,
                produzioneBatchId: batch2.id
            )
        ]

        let hub = TraceabilityHubContext(
            records: [burro, menta, rosmarino],
            productions: [production],
            links: legacyLinks,
            lottoProductionLinks: lottoLinks,
            batches: [batch1, batch2],
            productionOutputRecords: [
                makeOutput(for: batch1, status: .available),
                makeOutput(for: batch2, status: .available)
            ]
        )

        let groups = hub.productionArchiveGroups(
            records: [burro, menta, rosmarino],
            filter: .all,
            searchText: ""
        )

        XCTAssertEqual(groups.count, 2)

        let g1 = groups.first { $0.batchCode == "20260720-10" }
        let g2 = groups.first { $0.batchCode == "20260720-11" }
        XCTAssertNotNil(g1)
        XCTAssertNotNil(g2)

        let names1 = Set(g1?.ingredients.map(\.name) ?? [])
        let names2 = Set(g2?.ingredients.map(\.name) ?? [])

        XCTAssertEqual(names1, ["Burro"])
        XCTAssertEqual(names2, ["MENTA", "ROSMARINO"])
        XCTAssertFalse(names2.contains("Burro"))
    }

    func testClosedProductionHiddenFromHubButVisibleInHistoryMode() {
        let batch = makeBatch(code: "20260720-11", producedAt: Date())
        let lottoId = UUID()
        let menta = makeIncoming(name: "MENTA", lot: "524168", lottoId: lottoId)
        let production = Production(
            id: productionId,
            restaurantId: restaurantId,
            name: "Astice",
            categoryId: UUID(),
            categoryNameSnapshot: "Secondi",
            isCustom: true
        )
        let output = makeOutput(for: batch, status: .used)
        output.operationalClosedAt = Date()

        let hub = TraceabilityHubContext(
            records: [menta],
            productions: [production],
            links: [
                TraceabilityLink(
                    receivedItemId: menta.id,
                    productionId: productionId,
                    produzioneBatchId: batch.id
                )
            ],
            lottoProductionLinks: [
                LottoFotoProductionLink(
                    lottoFotoId: lottoId,
                    productionId: productionId,
                    produzioneBatchId: batch.id
                )
            ],
            batches: [batch],
            productionOutputRecords: [output]
        )

        let hubGroups = hub.productionArchiveGroups(
            records: [menta],
            filter: .all,
            searchText: "",
            includeClosedProductions: false
        )
        XCTAssertTrue(hubGroups.isEmpty, "Produzione Terminato deve uscire da Tracciabilità")

        let historyGroups = hub.productionArchiveGroups(
            records: [menta],
            filter: .all,
            searchText: "",
            includeClosedProductions: true
        )
        XCTAssertEqual(historyGroups.count, 1)
        XCTAssertEqual(historyGroups.first?.statusLabel, "Terminato")
        XCTAssertTrue(historyGroups.first?.ingredients.allSatisfy { $0.statusLabel == nil } ?? false)
    }

    func testHistoryProviderShowsTerminatoBadgeStatus() {
        let batch = makeBatch(code: "20260720-11", producedAt: Date())
        let lottoId = UUID()
        let menta = makeIncoming(name: "MENTA", lot: "524168", lottoId: lottoId)
        let production = Production(
            id: productionId,
            restaurantId: restaurantId,
            name: "Astice",
            categoryId: UUID(),
            categoryNameSnapshot: "Secondi",
            isCustom: true
        )
        let output = makeOutput(for: batch, status: .used)
        output.operationalClosedAt = Date()
        let log = TraceabilityLog(
            receivedItemId: output.id,
            actionType: .withdrawn,
            operatorName: "Chef",
            detail: "Produzione Terminato"
        )

        let entries = TraceabilityHistoryProvider().entries(
            records: [menta, output],
            productions: [production],
            links: [
                TraceabilityLink(
                    receivedItemId: menta.id,
                    productionId: productionId,
                    produzioneBatchId: batch.id
                )
            ],
            lottoProductionLinks: [
                LottoFotoProductionLink(
                    lottoFotoId: lottoId,
                    productionId: productionId,
                    produzioneBatchId: batch.id
                )
            ],
            lottoFotos: [],
            batches: [batch],
            images: [],
            logs: [log],
            restaurantId: restaurantId
        )

        let productionEntry = entries.first { $0.category == "Produzione registrata" }
        XCTAssertNotNil(productionEntry)
        XCTAssertEqual(productionEntry?.status, "Terminato")
        XCTAssertEqual(productionEntry?.title, "Astice")
        XCTAssertTrue(productionEntry?.traceabilityIngredients?.allSatisfy { $0.statusLabel == nil } ?? false)
    }

    // MARK: - Helpers

    private func makeBatch(code: String, producedAt: Date) -> ProduzioneBatch {
        ProduzioneBatch(
            restaurantId: restaurantId,
            productionId: productionId,
            productionNameSnapshot: "Astice",
            batchCode: code,
            producedAt: producedAt,
            status: .completato,
            createdByUserId: userId,
            createdByNameSnapshot: "Tester"
        )
    }

    private func makeIncoming(name: String, lot: String, lottoId: UUID) -> TraceabilityRecord {
        TraceabilityRecord(
            restaurantId: restaurantId,
            productName: name,
            lotCode: lot,
            supplier: "Fornitore",
            receivedAt: Date(),
            createdByUserId: userId,
            createdByNameSnapshot: "Tester",
            lottoFotoId: lottoId
        )
    }

    private func makeOutput(for batch: ProduzioneBatch, status: ProductStatus) -> TraceabilityRecord {
        let record = TraceabilityRecord(
            restaurantId: restaurantId,
            productName: batch.productionNameSnapshot,
            lotCode: batch.batchCode,
            supplier: "Cucina",
            receivedAt: batch.producedAt,
            produzioneBatchId: batch.id,
            createdByUserId: userId,
            createdByNameSnapshot: "Tester"
        )
        record.productStatus = status
        return record
    }
}
