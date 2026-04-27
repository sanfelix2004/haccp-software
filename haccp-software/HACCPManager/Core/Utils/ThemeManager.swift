import SwiftUI
import Observation

@Observable
public class ThemeManager {
    public static let shared = ThemeManager()
    
    public init() {}
    
    public var appearance: AppearanceSettings {
        SettingsStorageService.shared.appearance
    }
    
    // Core Colors
    public var primary: Color { .red }
    public var accent: Color { Color(hex: "#FFD700") } // Gold
    
    public var preferredColorScheme: ColorScheme? {
        appearance.theme == 0 ? .dark : .light
    }
    
    public var background: Color {
        if appearance.theme == 0 { // Dark
            return Color(hex: "#0A0A0A")
        } else { // Light
            return Color(hex: "#F5F5F7")
        }
    }
    
    public var surface: Color {
        if appearance.theme == 0 {
            return Color(hex: "#1A1A1A")
        } else {
            return .white
        }
    }
    
    public var text: Color {
        if appearance.theme == 0 {
            return .white
        } else {
            return .black
        }
    }
    
    public var textSecondary: Color {
        .gray
    }
    
    public var isDark: Bool {
        appearance.theme == 0
    }
    
    // Component Styles
    public var cornerRadius: CGFloat { 16 }
    
    public var buttonPadding: CGFloat {
        appearance.kitchenMode ? 24 : 16
    }
    
    public var fontSizeBase: CGFloat {
        16 * appearance.textSizeModifier
    }
    
    // Animation Tokens
    public var spring: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }
    
    public var slowSpring: Animation {
        .spring(response: 0.6, dampingFraction: 0.8)
    }
    
    public var fastEase: Animation {
        .easeOut(duration: 0.2)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
