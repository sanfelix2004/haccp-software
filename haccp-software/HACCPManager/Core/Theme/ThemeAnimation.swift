//
//  ThemeAnimation.swift
//  HACCP Manager — Theme System
//
//  Token di animazione + livello globale. Le views devono usare i token,
//  mai animazioni hard-coded, così l'utente può ridurle / disattivarle in toto.
//

import Foundation
import SwiftUI

enum AnimationLevel: Int, CaseIterable, Identifiable, Codable {
    case none    = 0
    case reduced = 1
    case full    = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none:    return "Nessuna"
        case .reduced: return "Ridotte"
        case .full:    return "Complete"
        }
    }

    var icon: String {
        switch self {
        case .none:    return "stop.fill"
        case .reduced: return "tortoise.fill"
        case .full:    return "hare.fill"
        }
    }

    var helper: String {
        switch self {
        case .none:    return "Disattiva ogni transizione: prestazioni massime, accessibilità."
        case .reduced: return "Solo fade essenziali, niente molle né bounce."
        case .full:    return "Tutte le transizioni premium attive."
        }
    }
}

/// Token animazioni semantiche. Mai usare `.spring(...)` hard-coded nelle views.
struct ThemeAnimation {
    let level: AnimationLevel

    init(level: AnimationLevel) {
        self.level = level
    }

    /// Animazione standard per cambi di stato (toggle, picker, presence).
    var standard: Animation? {
        switch level {
        case .none:    return nil
        case .reduced: return .easeInOut(duration: 0.18)
        case .full:    return .spring(response: 0.4, dampingFraction: 0.85)
        }
    }

    /// Animazione veloce per micro-interazioni (hover, press).
    var fast: Animation? {
        switch level {
        case .none:    return nil
        case .reduced: return .easeOut(duration: 0.12)
        case .full:    return .easeOut(duration: 0.2)
        }
    }

    /// Animazione lenta per ingressi/uscite di pannelli grandi.
    var slow: Animation? {
        switch level {
        case .none:    return nil
        case .reduced: return .easeInOut(duration: 0.28)
        case .full:    return .spring(response: 0.6, dampingFraction: 0.8)
        }
    }

    /// Transizione predefinita per `.transition(...)`.
    var defaultTransition: AnyTransition {
        switch level {
        case .none:    return .identity
        case .reduced: return .opacity
        case .full:    return .opacity.combined(with: .scale(scale: 0.98))
        }
    }

    /// Bandiera per disattivare effetti grafici costosi (blur, glow, ombre).
    var allowsHeavyEffects: Bool { level == .full }
}
