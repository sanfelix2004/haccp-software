import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Query private var temperatureRecords: [TemperatureRecord]
    @Query private var checklistRuns: [ChecklistRun]
    @Query private var cleaningRecords: [CleaningRecord]
    @Query private var defrostRecords: [DefrostRecord]
    @Query private var blastRecords: [BlastChillingRecord]
    @Query private var labelRecords: [ProductionLabelRecord]
    @Query private var goodsRecords: [GoodsReceivingRecord]

    @StateObject private var vm = HistoryViewModel()

    private var allEntries: [HistoryEntry] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return vm.service.buildEntries(
            restaurantId: rid,
            temperatureRecords: temperatureRecords,
            checklistRuns: checklistRuns,
            cleaningRecords: cleaningRecords,
            defrostRecords: defrostRecords,
            blastRecords: blastRecords,
            labelRecords: labelRecords,
            goodsRecords: goodsRecords
        )
    }

    private var filteredEntries: [HistoryEntry] {
        vm.filtered(entries: allEntries)
    }

    private var moduleOptions: [String] {
        ["Tutti"] + Array(Set(allEntries.map(\.module))).sorted()
    }

    private var categoryOptions: [String] {
        ["Tutte"] + Array(Set(allEntries.map(\.category))).sorted()
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Storia / Archivi") {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Picker("Modulo", selection: $vm.selectedModule) {
                            ForEach(moduleOptions, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)

                        Picker("Categoria", selection: $vm.selectedCategory) {
                            ForEach(categoryOptions, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)

                        TextField("Prodotto, dispositivo, operatore", text: $vm.searchText)
                            .textFieldStyle(.roundedBorder)
                    }

                    if filteredEntries.isEmpty {
                        DashboardEmptyStateView(state: .init(
                            title: "Nessuna registrazione disponibile",
                            message: "Lo storico centralizzato mostrera qui i moduli con dati reali.",
                            actionTitle: nil
                        ))
                    } else {
                        ForEach(filteredEntries.prefix(120)) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title).foregroundColor(.white)
                                    Text("\(entry.module) · \(entry.category)").font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(entry.operatorName).font(.caption).foregroundColor(.white.opacity(0.9))
                                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Storia")
    }
}
