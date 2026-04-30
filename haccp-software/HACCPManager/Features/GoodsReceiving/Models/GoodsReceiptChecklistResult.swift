import Foundation

enum GoodsChecklistResultValue: String, Codable, CaseIterable {
    case ok = "OK"
    case notOk = "NON_OK"
    case notApplicable = "N_A"

    var label: String {
        switch self {
        case .ok: return "OK"
        case .notOk: return "NON OK"
        case .notApplicable: return "N/A"
        }
    }
}

struct GoodsReceiptChecklistResult: Codable, Identifiable {
    var id: UUID
    var item: GoodsChecklistTemplateItem
    var value: GoodsChecklistResultValue
    var note: String?

    init(
        id: UUID = UUID(),
        item: GoodsChecklistTemplateItem,
        value: GoodsChecklistResultValue = .ok,
        note: String? = nil
    ) {
        self.id = id
        self.item = item
        self.value = value
        self.note = note
    }
}
