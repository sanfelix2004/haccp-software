import SwiftUI

struct GoodsReceiptControlSheet: View {
    enum SectionTab: String, CaseIterable, Identifiable {
        case temperature = "Temperatura"
        case moment = "Momento"
        case lotExpiry = "N lotto / scad."
        case notes = "Appunti"
        case checklist = "Lista controllo"

        var id: String { rawValue }
    }

    let product: ProductTemplate
    let requirement: GoodsReceiptRequirement
    @ObservedObject var vm: GoodsReceiptControlViewModel
    let isConfirmEnabled: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @State private var selectedTab: SectionTab = .moment

    private var tabs: [SectionTab] {
        var output: [SectionTab] = [.moment]
        if requirement.requiresTemperature { output.append(.temperature) }
        if requirement.requiresLot || requirement.requiresExpiryDate || requirement.requiresProductionDate { output.append(.lotExpiry) }
        if requirement.requiresChecklist { output.append(.checklist) }
        output.append(.notes)
        return output
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(product.name)
                        .font(.title3.bold())
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(tabs) { tab in
                                Button {
                                    selectedTab = tab
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(tab.rawValue)
                                        let status = tabStatus(for: tab)
                                        if status.hasWarning {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .foregroundStyle(ThemeManager.shared.colorWarning)
                                                .font(.caption2)
                                        } else if !status.isComplete {
                                            Image(systemName: "circle")
                                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                                .font(.caption2)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(ThemeManager.shared.colorSuccess)
                                                .font(.caption2)
                                        }
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(selectedTab == tab ? .white : .gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == tab ? Color.red.opacity(0.65) : ThemeManager.shared.colorDivider)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if selectedTab == .moment {
                        GoodsReceiptMomentSection(receivedAt: $vm.receivedAt)
                    }
                    if selectedTab == .temperature, requirement.requiresTemperature {
                        GoodsReceiptTemperatureSection(requirement: requirement, temperatureText: $vm.temperatureText)
                    }
                    if selectedTab == .lotExpiry, requirement.requiresLot || requirement.requiresExpiryDate || requirement.requiresProductionDate {
                        GoodsReceiptLotExpirySection(requirement: requirement, lotNumber: $vm.lotNumber, includeExpiryDate: $vm.includeExpiryDate, expiryDate: $vm.expiryDate, includeProductionDate: $vm.includeProductionDate, productionDate: $vm.productionDate, quantityText: $vm.quantityText, unit: $vm.unit)
                    }
                    if selectedTab == .checklist, requirement.requiresChecklist {
                        GoodsReceiptChecklistSection(checklistResults: $vm.checklistResults)
                    }
                    if selectedTab == .notes {
                        GoodsReceiptNotesSection(notes: $vm.notes, correctiveAction: $vm.correctiveAction)
                    }
                }
                .padding(20)
            }
            .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ho finito", action: onConfirm)
                        .disabled(!isConfirmEnabled)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            selectedTab = tabs.first ?? .moment
        }
    }

    private func tabStatus(for tab: SectionTab) -> (hasWarning: Bool, isComplete: Bool) {
        switch tab {
        case .moment:
            return (false, true)
        case .temperature:
            guard requirement.requiresTemperature else { return (false, true) }
            guard let temp = vm.temperatureValue else {
                return (false, !vm.temperatureText.isEmpty)
            }
            let isOutOfRange = (requirement.defaultMinTemp.map { temp < $0 } ?? false) ||
                               (requirement.defaultMaxTemp.map { temp > $0 } ?? false)
            return (isOutOfRange, true)
        case .lotExpiry:
            let lotValid = true // Lotto opzionale anche se il template lo segnalava.
            let expiryValid = !requirement.requiresExpiryDate || vm.includeExpiryDate
            let prodValid = !requirement.requiresProductionDate || vm.includeProductionDate
            let qtyValid = !vm.quantityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let allComplete = lotValid && expiryValid && prodValid && qtyValid
            return (false, allComplete)
        case .checklist:
            guard requirement.requiresChecklist else { return (false, true) }
            let hasFailures = vm.checklistResults.contains { $0.value == .notOk }
            let missingItemNotes = vm.checklistResults.contains {
                $0.value == .notOk && ($0.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return (hasFailures, !missingItemNotes)
        case .notes:
            let hasNonCompliance = vm.checklistResults.contains { $0.value == .notOk } ||
                                   (vm.temperatureValue.map { temp in
                                       (requirement.defaultMinTemp.map { temp < $0 } ?? false) ||
                                       (requirement.defaultMaxTemp.map { temp > $0 } ?? false)
                                   } ?? false)
            if hasNonCompliance {
                let noteOk = !vm.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let actionOk = !vm.correctiveAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                return (!noteOk || !actionOk, noteOk && actionOk)
            }
            return (false, true)
        }
    }
}
