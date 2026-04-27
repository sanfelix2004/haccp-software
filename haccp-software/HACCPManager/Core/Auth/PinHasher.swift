import Foundation
import CryptoKit

struct PinHasher {
    static func hash(pin: String) -> String {
        let inputData = Data(pin.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
