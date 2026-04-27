import SwiftData
import Foundation

@Model
public final class LocalUser {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var roleRaw: String
    public var pinHash: String
    public var avatarColorHex: String
    public var profileImageData: Data?
    
    // Additional Optional & Required Fields
    public var dateOfBirth: Date?
    public var notes: String?
    public var creationDate: Date?
    public var lastAccessDate: Date?
    
    public var email: String?
    public var phoneNumber: String?
    
    public var role: UserRole {
        get { UserRole(rawValue: roleRaw) ?? UserRole.viewer }
        set { roleRaw = newValue.rawValue }
    }
    
    public init(id: UUID = UUID(), 
                name: String, 
                role: UserRole, 
                pinHash: String, 
                avatarColorHex: String,
                dateOfBirth: Date? = nil,
                notes: String? = nil,
                email: String? = nil,
                phoneNumber: String? = nil) 
    {
        self.id = id
        self.name = name
        self.roleRaw = role.rawValue
        self.pinHash = pinHash
        self.avatarColorHex = avatarColorHex
        self.dateOfBirth = dateOfBirth
        self.notes = notes
        self.email = email
        self.phoneNumber = phoneNumber
        self.creationDate = Date()
    }
}
