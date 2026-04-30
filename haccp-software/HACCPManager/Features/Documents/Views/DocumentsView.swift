import SwiftUI
import SwiftData

struct DocumentsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var folders: [DocumentFolder]
    @Query private var items: [DocumentItem]
    @StateObject private var vm = DocumentsViewModel()

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var scopedFolders: [DocumentFolder] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return folders.filter { $0.restaurantId == rid }.sorted(by: { $0.name < $1.name })
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Documenti") {
                if scopedFolders.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna cartella disponibile",
                        message: "Le cartelle documentali verranno create automaticamente.",
                        actionTitle: nil
                    ))
                } else {
                    VStack(spacing: 10) {
                        ForEach(scopedFolders) { folder in
                            let count = items.filter { $0.folderId == folder.id }.count
                            HStack {
                                Image(systemName: "folder.fill").foregroundColor(.red)
                                Text(folder.name).foregroundColor(.white)
                                Spacer()
                                Text(count == 0 ? "Cartella vuota" : "\(count) file")
                                    .font(.caption)
                                    .foregroundColor(count == 0 ? .gray : .white)
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
        .navigationTitle("Documenti")
        .onAppear {
            guard let rid = appState.activeRestaurantId, let currentUser else { return }
            vm.service.ensureDefaultFolders(
                restaurantId: rid,
                user: currentUser,
                existingFolders: scopedFolders,
                modelContext: modelContext
            )
        }
    }
}
