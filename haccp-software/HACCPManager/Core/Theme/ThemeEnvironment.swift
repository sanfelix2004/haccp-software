//
//  ThemeEnvironment.swift
//  HACCP Manager — Theme System
//
//  Environment bridge per il `ThemeManager`. Da iOS 17 `@Observable`
//  funziona come `@Environment` se il valore è propagato esplicitamente.
//

import SwiftUI

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue: ThemeManager = .shared
}

extension EnvironmentValues {
    /// Manager dei temi. Iniettato a livello root da `ContentView`.
    /// Le views possono fare:
    /// ```swift
    /// @Environment(\.theme) private var theme
    /// ```
    var theme: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

/// Modificatore di convenienza per propagare il manager.
extension View {
    /// Inietta il `ThemeManager` nel sotto-grafo SwiftUI.
    /// Da chiamare a livello root (di solito una volta sola in `ContentView`).
    func themeProvider(_ manager: ThemeManager = .shared) -> some View {
        self.environment(\.theme, manager)
    }
}
