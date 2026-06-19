//
//  ProductionLabelSourceWorkspaceView.swift
//  Crea e stampa etichette per un modulo HACCP (es. Abbattimento).
//

import SwiftUI
import SwiftData

struct ProductionLabelSourceWorkspaceView: View {
    let source: ProductionLabelLinkedSource
    @ObservedObject var dataStore: ProductionLabelsDataStore
    let restaurantId: UUID
    let restaurantName: String
    let user: LocalUser
    let onChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @StateObject private var vm = ProductionLabelsViewModel()
    @ObservedObject private var printQueue = ProductionLabelPrintQueue.shared
    @ObservedObject private var printerManager = ClabelPrinterManager.shared

    @State private var newLabelDraft: ProductionLabelDraft?
    @State private var selectedLabelId: UUID?
    @State private var errorMessage: String?

    private let labelService = ProductionLabelsService()

    private var allItems: [ProductionLabelSourceItem] {
        ProductionLabelSourceItem.items(for: source, dataStore: dataStore)
    }

    private var pendingItems: [ProductionLabelSourceItem] {
        allItems
            .filter { $0.existingLabel(in: dataStore.labels) == nil }
            .sorted { $0.expiryInfo.sortOrder < $1.expiryInfo.sortOrder }
    }

    private var filteredLabels: [ProductionLabelRecord] {
        vm.filteredLabels(from: dataStore.labels, linkedSource: source)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                sourceHero

                if !printQueue.pendingJobs.isEmpty {
                    printQueueCard
                }

                DashboardCardView(
                    title: "Da etichettare",
                    subtitle: pendingSubtitle
                ) {
                    pendingItemsList
                }

                if !filteredLabels.isEmpty {
                    DashboardCardView(
                        title: "Etichette create",
                        subtitle: "\(filteredLabels.count) · una per elemento"
                    ) {
                        ProductionLabelFilterBar(filter: $vm.filter, labels: dataStore.labels)

                        LazyVStack(spacing: 10) {
                            ForEach(filteredLabels.prefix(60)) { label in
                                Button {
                                    selectedLabelId = label.id
                                } label: {
                                    ProductionLabelRowView(label: label)
                                }
                                .buttonStyle(PremiumPressButtonStyle())
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(theme.spacing.screenPadding + 8)
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle(source.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { newLabelDraft != nil },
            set: { if !$0 { newLabelDraft = nil } }
        )) {
            if let draft = newLabelDraft {
                ProductionLabelEditorSheet(
                    mode: .create(draft),
                    restaurantId: restaurantId,
                    user: user,
                    initialTab: .preview,
                    onSaved: { record, shouldPrint in
                        handleLabelSaved(record, shouldPrint: shouldPrint)
                    },
                    onCancel: { newLabelDraft = nil }
                )
            }
        }
        .navigationDestination(item: $selectedLabelId) { labelId in
            ProductionLabelDetailLoaderView(
                labelId: labelId,
                restaurantId: restaurantId,
                restaurantName: restaurantName,
                user: user,
                onChanged: onChanged
            )
        }
        .alert("Etichette", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            Task { await drainPrintQueue() }
        }
    }

    private var pendingSubtitle: String {
        if pendingItems.isEmpty {
            return "Tutti gli elementi hanno già un'etichetta"
        }
        let expired = pendingItems.filter { $0.expiryInfo == .expired }.count
        let rejected = pendingItems.filter { $0.expiryInfo == .rejected }.count
        let soon = pendingItems.filter { $0.expiryInfo == .soon }.count
        let valid = pendingItems.filter { $0.expiryInfo == .ok }.count
        var parts = ["\(pendingItems.count) da etichettare"]
        if expired > 0 { parts.append("\(expired) scaduti") }
        if rejected > 0 { parts.append("\(rejected) respinti") }
        if soon > 0 { parts.append("\(soon) in scadenza") }
        if valid > 0 { parts.append("\(valid) validi") }
        return parts.joined(separator: " · ")
    }

    private var sourceHero: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.colorPrimary.opacity(0.22), theme.colorPrimary.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: source.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.colorPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(source.title)
                    .font(theme.typography.title3.weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
                Text(source.subtitle)
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colorTextSecondary)
                if filteredLabels.count > 0 {
                    Label("\(filteredLabels.count) etichettati", systemImage: "checkmark.seal.fill")
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colorSuccess)
                }
            }

            Spacer(minLength: 0)

            ModuleHelpButton(help: ModuleHelpLibrary.sidebar(.productionLabels), size: 36)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .fill(theme.colorSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .stroke(theme.colorPrimary.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var pendingItemsList: some View {
        if allItems.isEmpty {
            Text(source.emptyItemsMessage)
                .font(theme.typography.subheadline)
                .foregroundStyle(theme.colorTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if pendingItems.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.colorSuccess)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tutto etichettato")
                        .font(theme.typography.headline)
                    Text("Ogni elemento ha già la sua etichetta. Puoi ristampare dalla sezione sotto.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(pendingItems) { item in
                    Button {
                        beginLabelCreation(for: item)
                    } label: {
                        pendingItemRow(item)
                    }
                    .buttonStyle(PremiumPressButtonStyle())
                }
            }
        }
    }

    private func pendingItemRow(_ item: ProductionLabelSourceItem) -> some View {
        let expiry = item.expiryInfo
        let borderColor: Color = {
            switch expiry {
            case .expired, .rejected: return theme.colorError.opacity(0.45)
            case .soon: return theme.colorWarning.opacity(0.45)
            default: return theme.colorPrimary.opacity(0.2)
            }
        }()

        return HStack(spacing: 14) {
            leadingVisual(for: item)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(item.subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let origin = item.originBadgeTitle {
                        HACCPBadge(title: origin, style: .neutral, showIcon: false)
                    }
                    if let expiryDate = item.displayExpiryDate {
                        Label(
                            expiryDate.formatted(date: .abbreviated, time: .omitted),
                            systemImage: "calendar"
                        )
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                    }
                    HACCPBadge(title: expiry.badgeTitle, style: expiry.badgeStyle, showIcon: expiry != .ok)
                }
            }

            Spacer(minLength: 8)

            Text("Crea")
                .font(theme.typography.caption.weight(.bold))
                .foregroundStyle(theme.colorTextOnPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(expiry == .expired || expiry == .rejected ? theme.colorTextSecondary : theme.colorPrimary)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .fill(theme.colorSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var printQueueCard: some View {
        DashboardCardView(
            title: "Coda stampa",
            subtitle: printerManager.isConnected ? "Invio alla stampante CLABEL" : "Stampante non connessa"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(printQueue.pendingJobs) { job in
                    HStack {
                        Image(systemName: "printer")
                            .foregroundStyle(theme.colorInfo)
                        Text("Etichetta in attesa · \(job.copies) copie")
                            .font(theme.typography.subheadline)
                        Spacer()
                        if printQueue.isProcessing {
                            ProgressView()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func leadingVisual(for item: ProductionLabelSourceItem) -> some View {
        if let data = item.photoData(modelContext: modelContext),
           let thumb = HACCPZoomablePhotoThumbnail(data: data, size: 48, zoomTitle: item.title) {
            thumb
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.colorPrimary.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: source.icon)
                    .foregroundStyle(theme.colorPrimary)
            }
        }
    }

    private func beginLabelCreation(for item: ProductionLabelSourceItem) {
        if let existing = item.existingLabel(in: dataStore.labels) {
            selectedLabelId = existing.id
            return
        }
        newLabelDraft = labelService.draft(from: item)
    }

    private func handleLabelSaved(_ record: ProductionLabelRecord, shouldPrint: Bool) {
        newLabelDraft = nil
        dataStore.mergeFetchedLabel(record)
        onChanged()
        guard shouldPrint else { return }
        Task {
            await printQueue.schedulePrint(
                label: record,
                restaurantName: restaurantName,
                modelContext: modelContext,
                countAsReprint: false,
                knownLabels: dataStore.labels
            )
            await drainPrintQueue()
        }
    }

    private func drainPrintQueue() async {
        await printQueue.processPending(
            labels: dataStore.labels,
            modelContext: modelContext,
            restaurantName: restaurantName
        )
    }
}

private extension ProductionLabelsService {
    func draft(from item: ProductionLabelSourceItem) -> ProductionLabelDraft {
        switch item {
        case .traceability(let record): return draft(from: record)
        case .blast(let record): return draft(from: record)
        case .defrost(let record): return draft(from: record)
        }
    }
}

enum ProductionLabelSourceItem: Identifiable {
    case traceability(TraceabilityRecord)
    case blast(BlastChillingRecord)
    case defrost(DefrostRecord)

    static func items(
        for source: ProductionLabelLinkedSource,
        dataStore: ProductionLabelsDataStore
    ) -> [ProductionLabelSourceItem] {
        switch source {
        case .traceability:
            return dataStore.traceabilityRecords.map { .traceability($0) }
        case .blastChilling:
            return dataStore.blastRecords.map { .blast($0) }
        case .defrost:
            return dataStore.defrostRecords.map { .defrost($0) }
        }
    }

    func existingLabel(in labels: [ProductionLabelRecord]) -> ProductionLabelRecord? {
        ProductionLabelLinkMatcher.existingLabel(for: self, in: labels)
    }

    var id: UUID {
        switch self {
        case .traceability(let r): return r.id
        case .blast(let r): return r.id
        case .defrost(let r): return r.id
        }
    }

    var title: String {
        switch self {
        case .traceability(let r): return r.productName
        case .blast(let r): return r.productionNameSnapshot
        case .defrost(let r): return r.productName
        }
    }

    var subtitle: String {
        switch self {
        case .traceability(let r):
            return "Lotto \(r.lotCode) · \(r.supplier) · \(r.productStatus.label)"
        case .blast(let r): return r.productionCategorySnapshot
        case .defrost(let r): return r.method
        }
    }

    var originBadgeTitle: String? {
        switch self {
        case .traceability(let r):
            return r.source == .receipt ? "Da ricezione" : "Manuale"
        default:
            return nil
        }
    }

    func photoData(modelContext: ModelContext) -> Data? {
        switch self {
        case .traceability(let item):
            var probe = ProductionLabelRecord(
                restaurantId: item.restaurantId,
                productName: item.productName,
                productionDate: item.receivedAt,
                expiryDate: item.expiryDate ?? item.receivedAt,
                createdByUserId: item.createdByUserId,
                createdByNameSnapshot: item.createdByNameSnapshot,
                traceabilityRecordId: item.id,
                goodsReceiptId: item.goodsReceiptId
            )
            return ProductionLabelImageResolver.imageData(for: probe, context: modelContext)
        default:
            return nil
        }
    }

    /// Data di riferimento per la scadenza mostrata in «Da etichettare».
    var displayExpiryDate: Date? {
        switch self {
        case .traceability(let r):
            return r.expiryDate
        case .blast(let r):
            let base = r.endedAt ?? r.startedAt
            return Calendar.current.date(byAdding: .day, value: 90, to: base)
        case .defrost(let r):
            let base = r.endAt ?? r.startAt
            return Calendar.current.date(byAdding: .hour, value: 24, to: base)
        }
    }

    var expiryInfo: ProductionLabelSourceItemExpiry {
        switch self {
        case .traceability(let r):
            if r.productStatus == .rejected || r.isNonCompliant { return .rejected }
            if r.productStatus == .expired { return .expired }
            guard let expiry = r.expiryDate else { return .unknown }
            return Self.evaluateExpiry(expiry)
        case .blast(let r):
            let base = r.endedAt ?? r.startedAt
            let expiry = Calendar.current.date(byAdding: .day, value: 90, to: base) ?? base
            return Self.evaluateExpiry(expiry)
        case .defrost(let r):
            let base = r.endAt ?? r.startAt
            let expiry = Calendar.current.date(byAdding: .hour, value: 24, to: base) ?? base
            return Self.evaluateExpiry(expiry)
        }
    }

    private static func evaluateExpiry(_ expiryDate: Date, now: Date = Date()) -> ProductionLabelSourceItemExpiry {
        let threshold = SettingsStorageService.shared.haccp.productExpiryThreshold
        if ProductExpiryEvaluator.isExpiredByDate(expiryDate, now: now) { return .expired }
        if ProductExpiryEvaluator.isDueToday(expiryDate, now: now) { return .soon }
        if ProductExpiryEvaluator.isSoonExpiring(expiryDate, thresholdDays: threshold, now: now) { return .soon }
        return .ok
    }
}
