//
//  ArchivableRecord.swift
//  Protocollo per dati storici compressi / esclusi dalle UI operative.
//

import Foundation

protocol ArchivableRecord: RestaurantScoped {
    var isArchived: Bool { get set }
    var archivedAt: Date? { get set }
}

extension TemperatureRecord: ArchivableRecord {}
extension ChecklistRun: ArchivableRecord {}
extension TraceabilityRecord: ArchivableRecord {}
extension CleaningRecord: ArchivableRecord {}
extension BlastChillingRecord: ArchivableRecord {}
extension DefrostRecord: ArchivableRecord {}
extension OilControlRecord: ArchivableRecord {}
extension GoodsReceivingRecord: ArchivableRecord {}
extension FridgeCheckRecord: ArchivableRecord {}
extension ProductionLabelRecord: ArchivableRecord {}
