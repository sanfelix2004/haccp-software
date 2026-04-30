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
                        .foregroundColor(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(tabs) { tab in
                                Button {
                                    selectedTab = tab
                                } label: {
                                    Text(tab.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(selectedTab == tab ? .white : .gray)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedTab == tab ? Color.red.opacity(0.65) : Color.white.opacity(0.08))
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
            .background(Color(hex: "#0A0A0A").ignoresSafeArea())
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
}
