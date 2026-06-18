import SwiftUI

struct KitchenProcessSubjectPicker: View {
    @Environment(\.theme) private var theme

    @Binding var subject: KitchenProcessSubject
    let allowedSources: [KitchenProcessSubjectSource]
    let traceabilityRecords: [TraceabilityRecord]
    let incomingFoodTemplates: [ProductTemplate]
    let productions: [Production]
    let productionCategories: [ProductionCategory]

    @State private var selectedProductionCategoryId: UUID?
    @State private var selectedGoodsCategory: GoodsCategory = .all
    @State private var traceSearch = ""

    private var categoryOrderById: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: productionCategories.map { ($0.id, $0.orderIndex) })
    }

    private var filteredTraceability: [TraceabilityRecord] {
        let base = KitchenProcessSubjectFactory.actionableTraceability(traceabilityRecords)
        let query = traceSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.productName.localizedCaseInsensitiveContains(query) ||
            $0.lotCode.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredIncomingFood: [ProductTemplate] {
        let base = incomingFoodTemplates.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        guard selectedGoodsCategory != .all else { return base }
        return base.filter { $0.category == selectedGoodsCategory }
    }

    private var filteredProductions: [Production] {
        if let selectedProductionCategoryId {
            return productions
                .filter { $0.categoryId == selectedProductionCategoryId }
                .sorted(by: productionNameSort)
        }
        return productions.sorted(by: productionCategorySort)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if allowedSources.count > 1 {
                Picker("Fonte", selection: $subject.source) {
                    ForEach(allowedSources) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: subject.source) { _, newSource in
                    resetForSource(newSource)
                }
            }

            switch subject.source {
            case .traceability:
                traceabilitySection
            case .incomingFood:
                incomingFoodSection
            case .production:
                productionSection
            case .manual:
                manualSection
            }

            if subject.isValid {
                selectedBanner
            }
        }
    }

    private var traceabilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lotti già ricevuti e registrati in tracciabilità.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
            TextField("Cerca prodotto o lotto", text: $traceSearch)
                .textFieldStyle(.roundedBorder)

            if filteredTraceability.isEmpty {
                Text("Nessun lotto disponibile. Registra prima una ricezione merci.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredTraceability.prefix(80)) { trace in
                        traceabilityRow(trace)
                    }
                }
            }
        }
    }

    private func traceabilityRow(_ trace: TraceabilityRecord) -> some View {
        let selected = subject.traceabilityItemId == trace.id
        return Button {
            subject = .from(trace: trace)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trace.productName)
                        .font(theme.typography.subheadline.bold())
                        .foregroundStyle(theme.colorTextPrimary)
                    Text("Lotto \(trace.lotCode)")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.colorSuccess)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? theme.colorPrimary.opacity(0.08) : theme.colorSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? theme.colorPrimary.opacity(0.35) : theme.colorDivider.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var incomingFoodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tipi di merce in ingresso (surgelati, freschi, …). Gestisci il catalogo da Alimenti in ingresso.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
            goodsCategoryTabs
            if filteredIncomingFood.isEmpty {
                Text("Nessun alimento in questa categoria. Aggiungilo da Alimenti in ingresso nel menu.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            } else {
                ProductSelectionGridView(
                    products: filteredIncomingFood,
                    recentProductIds: [],
                    selectedProductId: subject.productTemplateId,
                    onSelect: { subject = .from(template: $0) }
                )
            }
        }
    }

    private var productionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Piatti e preparazioni del menu. Gestisci il catalogo da Catalogo piatti.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
            productionCategoryTabs
            if filteredProductions.isEmpty {
                Text("Nessun piatto in questa categoria. Aggiungilo da Catalogo piatti.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            } else {
                BlastChillingProductionGridView(
                    productions: filteredProductions,
                    selectedProductionId: subject.productionId,
                    onSelect: { subject = .from(production: $0) }
                )
            }
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Nome prodotto *", text: $subject.productName)
                .textFieldStyle(.roundedBorder)
            TextField("Lotto (opzionale)", text: Binding(
                get: { subject.lotNumber ?? "" },
                set: { subject.lotNumber = $0.nilIfEmpty }
            ))
            .textFieldStyle(.roundedBorder)
            Text("Solo se il prodotto non è ancora nel catalogo né in tracciabilità.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
        }
    }

    private var selectedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.colorSuccess)
            VStack(alignment: .leading, spacing: 2) {
                Text(subject.displayTitle)
                    .font(theme.typography.subheadline.bold())
                    .foregroundStyle(theme.colorTextPrimary)
                Text(subject.displaySubtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(theme.colorPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var goodsCategoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(GoodsCategory.allCases) { category in
                    goodsCategoryButton(category)
                }
            }
        }
    }

    private func goodsCategoryButton(_ category: GoodsCategory) -> some View {
        Button {
            selectedGoodsCategory = category
        } label: {
            Text(category == .all ? "Tutti" : category.rawValue)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(selectedGoodsCategory == category ? theme.colorTextOnPrimary : theme.colorTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedGoodsCategory == category ? theme.colorPrimary : theme.colorDivider)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private var productionCategoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                productionCategoryButton(nil, title: "Tutti")
                ForEach(productionCategories) { category in
                    productionCategoryButton(category.id, title: category.name)
                }
            }
        }
    }

    private func productionCategoryButton(_ id: UUID?, title: String) -> some View {
        Button {
            selectedProductionCategoryId = id
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedProductionCategoryId == id ? theme.colorTextOnPrimary : theme.colorTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedProductionCategoryId == id ? theme.colorPrimary : theme.colorDivider)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func resetForSource(_ source: KitchenProcessSubjectSource) {
        subject.traceabilityItemId = nil
        subject.productTemplateId = nil
        subject.productionId = nil
        if source != .manual {
            subject.productName = ""
            subject.lotNumber = nil
            subject.categoryName = nil
        }
    }

    private func productionNameSort(_ lhs: Production, _ rhs: Production) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func productionCategorySort(_ lhs: Production, _ rhs: Production) -> Bool {
        let lhsOrder = categoryOrderById[lhs.categoryId] ?? Int.max
        let rhsOrder = categoryOrderById[rhs.categoryId] ?? Int.max
        if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
        return productionNameSort(lhs, rhs)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
