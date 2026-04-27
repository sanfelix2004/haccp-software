import Foundation

public struct AppearanceSettings: Codable {
    var theme: Int = 0 // 0: Dark, 1: Light (Future)
    var highContrast: Bool = false
    var textSizeModifier: Double = 1.0
    var animationsEnabled: Bool = true
    var kitchenMode: Bool = false
    var reduceMotion: Bool = false
    var reduceGraphicsEffects: Bool = false
}
