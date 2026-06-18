import Foundation
import Combine

@MainActor
final class DocumentsViewModel: ObservableObject {
    let service = DocumentsService()
    @Published var selectedFolderId: UUID?
}
