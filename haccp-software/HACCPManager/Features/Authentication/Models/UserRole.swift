import Foundation

public enum UserRole: String, Codable, CaseIterable {
    case master = "MASTER"
    case boss = "BOSS"
    case manager = "MANAGER"
    case cucina = "CUCINA"
    case cameriere = "CAMERIERE"
    case haccpOperator = "HACCP_OPERATOR"
    case viewer = "VIEWER"
}
