//
//  TraceabilityHubSnapshot.swift
//  Derivati hub pre-calcolati in un unico passaggio (evita ricalcoli SwiftUI).
//

import Foundation

struct TraceabilityHubSnapshot: Equatable {
    static let empty = TraceabilityHubSnapshot()

    var metrics: TraceabilityHubMetrics = TraceabilityHubMetrics(
        total: 0, available: 0, unlinked: 0, critical: 0, todayCount: 0
    )
    var productionGroups: [TraceabilityProductionArchiveGroup] = []
    var unlinkedRecords: [TraceabilityRecord] = []
    var criticalRecords: [TraceabilityRecord] = []
    var filteredRecords: [TraceabilityRecord] = []
    var productionSuggestions: [String] = []

    static func == (lhs: TraceabilityHubSnapshot, rhs: TraceabilityHubSnapshot) -> Bool {
        lhs.metrics == rhs.metrics
            && lhs.productionGroups == rhs.productionGroups
            && lhs.unlinkedRecords.map(\.id) == rhs.unlinkedRecords.map(\.id)
            && lhs.criticalRecords.map(\.id) == rhs.criticalRecords.map(\.id)
            && lhs.filteredRecords.map(\.id) == rhs.filteredRecords.map(\.id)
            && lhs.productionSuggestions == rhs.productionSuggestions
    }
}

enum TraceabilityHubSnapshotBuilder {

    @MainActor
    static func build(
        context: TraceabilityHubContext,
        records: [TraceabilityRecord],
        filter: TraceabilityHubFilter,
        searchText: String
    ) -> TraceabilityHubSnapshot {
        let groups = context.productionArchiveGroups(
            records: records,
            filter: filter,
            searchText: searchText
        )
        let unlinked = context.unlinkedRecords(
            records: records,
            filter: filter,
            searchText: searchText
        )
        let critical = context.criticalRecords(
            records: records,
            filter: filter,
            searchText: searchText
        )
        let filtered = context.filteredRecords(
            records,
            filter: filter,
            searchText: searchText
        )

        var seen = Set<String>()
        let suggestions = context
            .productionArchiveGroups(records: records, filter: .all, searchText: "")
            .compactMap { group -> String? in
                let name = group.productionName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { return nil }
                return name
            }
            .prefix(12)
            .map { $0 }

        return TraceabilityHubSnapshot(
            metrics: context.metrics(for: records),
            productionGroups: groups,
            unlinkedRecords: unlinked,
            criticalRecords: critical,
            filteredRecords: filtered,
            productionSuggestions: suggestions
        )
    }
}
