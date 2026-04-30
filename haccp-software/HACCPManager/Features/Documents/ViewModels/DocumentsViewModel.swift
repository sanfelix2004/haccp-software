import Foundation
import Combine

@MainActor
final class DocumentsViewModel: ObservableObject {
    let service = DocumentsService()
}
