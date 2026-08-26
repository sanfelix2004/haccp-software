import XCTest
import SwiftData
@testable import HACCP_Manager

/// Test di logica core: stati, visibilità hub, lotti interni, scadenze.
@MainActor
final class TraceabilityCoreLogicTests: XCTestCase {

    private var restaurantId: UUID!
    private var userId: UUID!

    override func setUp() {
        super.setUp()
        restaurantId = UUID()
        userId = UUID()
    }

    // MARK: - Internal lot code

    func testInternalLotCodeRecognizesProductionFormat() {
        XCTAssertTrue(InternalLotCodeGenerator.isInternalLotCode("20260720-11"))
        XCTAssertTrue(InternalLotCodeGenerator.isInternalLotCode("20260101-01"))
        XCTAssertFalse(InternalLotCodeGenerator.isInternalLotCode("524168"))
        XCTAssertFalse(InternalLotCodeGenerator.isInternalLotCode("LOTTO-ABC"))
        XCTAssertFalse(InternalLotCodeGenerator.isInternalLotCode(""))
    }

    // MARK: - Hub visibility

    func testHubRecordOnlyAvailableIncomingLots() {
        let available = makeIncoming(name: "Menta", status: .available)
        let used = makeIncoming(name: "Burro", status: .used)
        let rejected = makeIncoming(name: "Pesce", status: .rejected)
        let expired = makeIncoming(name: "Latte", status: .expired)
        let production = makeProductionOutput(name: "Astice", status: .available)

        XCTAssertTrue(TraceabilityRecordSupport.isHubRecord(available))
        XCTAssertFalse(TraceabilityRecordSupport.isHubRecord(used))
        XCTAssertFalse(TraceabilityRecordSupport.isHubRecord(rejected))
        XCTAssertFalse(TraceabilityRecordSupport.isHubRecord(expired))
        XCTAssertFalse(TraceabilityRecordSupport.isHubRecord(production))
    }

    func testUnassignedKitchenLabelDraftHiddenFromHubAndExpiry() {
        let draft = makeIncoming(name: TraceabilityRecordSupport.kitchenLabelDraftName, status: .available)
        draft.lottoFotoId = UUID()
        draft.lotCode = ""
        draft.supplier = ""

        XCTAssertTrue(TraceabilityRecordSupport.isUnassignedKitchenLabelDraft(draft))
        XCTAssertTrue(TraceabilityRecordSupport.isKitchenLabelCapture(draft))
        XCTAssertFalse(TraceabilityRecordSupport.isHubRecord(draft))
        XCTAssertFalse(TraceabilityRecordSupport.isIncomingExpiryRecord(draft))
        XCTAssertFalse(TraceabilityRecordSupport.isExpiryMonitored(draft))
    }

    func testAssignedKitchenLabelStillExcludedFromExpiry() {
        let assigned = makeIncoming(name: "Etichetta F-20260826-112345", status: .available)
        assigned.lottoFotoId = UUID()
        assigned.lotCode = "F-20260826-112345"

        XCTAssertFalse(TraceabilityRecordSupport.isUnassignedKitchenLabelDraft(assigned))
        XCTAssertTrue(TraceabilityRecordSupport.isKitchenLabelCapture(assigned))
        XCTAssertTrue(TraceabilityRecordSupport.isHubRecord(assigned))
        XCTAssertFalse(TraceabilityRecordSupport.isIncomingExpiryRecord(assigned))
    }

    func testLabelPhotoRefCodeFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 11, minute: 23, second: 45))!
        let code = LabelPhotoRefCode.make(from: date)
        XCTAssertEqual(code, "F-20260826-112345")
        XCTAssertTrue(code.hasPrefix("F-"))
        XCTAssertEqual(code.count, 17)
    }

    func testOperationallyClosedDetectsUsedAndRejected() {
        let used = makeIncoming(name: "X", status: .used)
        let rejected = makeIncoming(name: "Y", status: .rejected)
        let available = makeIncoming(name: "Z", status: .available)

        XCTAssertTrue(TraceabilityRecordSupport.isOperationallyClosed(used))
        XCTAssertTrue(TraceabilityRecordSupport.isOperationallyClosed(rejected))
        XCTAssertFalse(TraceabilityRecordSupport.isOperationallyClosed(available))
    }

    func testExpiryGracePeriodKeepsClosedLotsOneDay() {
        let closed = makeIncoming(name: "Astice", status: .used)
        closed.operationalClosedAt = Date()
        XCTAssertTrue(TraceabilityRecordSupport.isWithinClosureGracePeriod(closed))
        XCTAssertTrue(TraceabilityRecordSupport.isExpiryMonitored(closed))

        closed.operationalClosedAt = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        XCTAssertFalse(TraceabilityRecordSupport.isWithinClosureGracePeriod(closed))
        XCTAssertFalse(TraceabilityRecordSupport.isExpiryMonitored(closed))
    }

    // MARK: - Terminato status

    func testProductionUsedShowsTerminatoNotUsato() {
        let output = makeProductionOutput(name: "Astice", status: .used)
        let presentation = TraceabilityLotOperationalStatus.present(record: output, logs: [])
        XCTAssertEqual(presentation.label, "Terminato")
    }

    func testIncomingUsedShowsUsato() {
        let incoming = makeIncoming(name: "Burro", status: .used)
        let presentation = TraceabilityLotOperationalStatus.present(record: incoming, logs: [])
        XCTAssertEqual(presentation.label, "Usato")
    }

    func testClosureLogProduzioneTerminato() {
        let output = makeProductionOutput(name: "Astice", status: .used)
        let log = TraceabilityLog(
            receivedItemId: output.id,
            actionType: .withdrawn,
            operatorName: "Chef",
            detail: "Produzione Terminato"
        )
        let presentation = TraceabilityLotOperationalStatus.present(record: output, logs: [log])
        XCTAssertEqual(presentation.label, "Terminato")

        let life = TraceabilityLifecycleSummary.build(record: output, logs: [log])
        XCTAssertEqual(life.statusLabel, "Terminato")
        XCTAssertTrue(life.isClosed)
    }

    func testAvailableShowsDisponibile() {
        let output = makeProductionOutput(name: "Astice", status: .available)
        let presentation = TraceabilityLotOperationalStatus.present(record: output, logs: [])
        XCTAssertEqual(presentation.label, "Disponibile")
    }

    // MARK: - Expiry closure kinds

    func testExpiryLotClosureKindSelectability() {
        let withFutureExpiry = makeIncoming(name: "Latte", status: .available)
        withFutureExpiry.expiryDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())

        XCTAssertTrue(ExpiryLotClosureKind.finished.isSelectable(for: withFutureExpiry))
        XCTAssertTrue(ExpiryLotClosureKind.discarded.isSelectable(for: withFutureExpiry))
        XCTAssertFalse(ExpiryLotClosureKind.expired.isSelectable(for: withFutureExpiry))

        let past = makeIncoming(name: "Latte", status: .expired)
        past.expiryDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        XCTAssertTrue(ExpiryLotClosureKind.expired.isSelectable(for: past))
    }

    func testExpiryLotClosureKindHistoryVsDocuments() {
        XCTAssertFalse(ExpiryLotClosureKind.finished.requiresNote)
        XCTAssertFalse(ExpiryLotClosureKind.finished.recordsInDocuments)
        XCTAssertEqual(ExpiryLotClosureKind.finished.closedProductStatus, .used)

        XCTAssertTrue(ExpiryLotClosureKind.discarded.requiresNote)
        XCTAssertTrue(ExpiryLotClosureKind.discarded.recordsInDocuments)
        XCTAssertEqual(ExpiryLotClosureKind.discarded.closedProductStatus, .rejected)

        XCTAssertFalse(ExpiryLotClosureKind.expired.requiresNote)
        XCTAssertTrue(ExpiryLotClosureKind.expired.recordsInDocuments)
    }

    func testWithdrawalKindHistoryVsDocuments() {
        XCTAssertFalse(TraceabilityWithdrawalKind.ritirato.recordsInDocuments)
        XCTAssertTrue(TraceabilityWithdrawalKind.scartato.requiresNote)
        XCTAssertTrue(TraceabilityWithdrawalKind.scartato.recordsInDocuments)
        XCTAssertEqual(TraceabilityWithdrawalKind.scartato.closedProductStatus, .rejected)
    }

    // MARK: - Scadenza FEFO

    func testProductionExpiryConstrainedByIngredient() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let ingredient = makeIncoming(name: "Menta", status: .available)
        ingredient.expiryDate = calendar.date(byAdding: .day, value: 2, to: today)

        let constraint = ScadenzaCalculator.productionExpiryConstraint(
            shelfLifeDays: 10,
            ingredientRecords: [ingredient],
            referenceDate: today,
            calendar: calendar
        )
        XCTAssertTrue(constraint.isIngredientLimited)
        XCTAssertEqual(constraint.limitingIngredientName, "Menta")
        XCTAssertEqual(constraint.suggestedExpiryDate, ingredient.expiryDate)
    }

    func testProductionExpiryUsesCatalogWhenIngredientsFarther() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let ingredient = makeIncoming(name: "Rosmarino", status: .available)
        ingredient.expiryDate = calendar.date(byAdding: .day, value: 30, to: today)

        let constraint = ScadenzaCalculator.productionExpiryConstraint(
            shelfLifeDays: 5,
            ingredientRecords: [ingredient],
            referenceDate: today,
            calendar: calendar
        )
        XCTAssertFalse(constraint.isIngredientLimited)
        XCTAssertEqual(
            constraint.suggestedExpiryDate,
            ScadenzaCalculator.productionExpiryDate(fromDays: 5, referenceDate: today, calendar: calendar)
        )
    }

    // MARK: - Helpers

    private func makeIncoming(name: String, status: ProductStatus) -> TraceabilityRecord {
        let record = TraceabilityRecord(
            restaurantId: restaurantId,
            productName: name,
            lotCode: "LOT-\(name)",
            supplier: "Fornitore",
            receivedAt: Date(),
            createdByUserId: userId,
            createdByNameSnapshot: "Tester"
        )
        record.productStatus = status
        return record
    }

    private func makeProductionOutput(name: String, status: ProductStatus) -> TraceabilityRecord {
        let record = TraceabilityRecord(
            restaurantId: restaurantId,
            productName: name,
            lotCode: "20260720-11",
            supplier: "Cucina",
            receivedAt: Date(),
            produzioneBatchId: UUID(),
            createdByUserId: userId,
            createdByNameSnapshot: "Tester"
        )
        record.productStatus = status
        return record
    }
}
