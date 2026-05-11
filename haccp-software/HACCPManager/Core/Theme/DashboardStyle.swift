//
//  DashboardStyle.swift
//  HACCP Manager — Theme System
//

import Foundation
import SwiftUI

enum DashboardStyle: Int, CaseIterable, Identifiable, Codable {
    case cardsClassic   = 0
    case glassmorphism  = 1
    case minimalFlat    = 2
    case enterprise     = 3
    case modernNeon     = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .cardsClassic:  return "Cards Classic"
        case .glassmorphism: return "Glassmorphism"
        case .minimalFlat:   return "Minimal Flat"
        case .enterprise:    return "Enterprise"
        case .modernNeon:    return "Modern Neon"
        }
    }

    var icon: String {
        switch self {
        case .cardsClassic:  return "square.grid.2x2.fill"
        case .glassmorphism: return "circle.dashed.inset.filled"
        case .minimalFlat:   return "square.dashed"
        case .enterprise:    return "building.columns.fill"
        case .modernNeon:    return "sparkles"
        }
    }

    var helper: String {
        switch self {
        case .cardsClassic:  return "Card classiche HACCP con bordi sottili. Familiare e affidabile."
        case .glassmorphism: return "Effetto vetro premium con blur leggero. Apple-like."
        case .minimalFlat:   return "Solo testo e dati. Massima leggibilità, zero distrazioni."
        case .enterprise:    return "Bordi marcati, gerarchia tipografica netta. ASL-ready."
        case .modernNeon:    return "Accenti glow e contorni vividi. Look high-tech kitchen."
        }
    }

    // MARK: Style tokens

    var cardBlurRadius: Double {
        switch self {
        case .cardsClassic:  return 0
        case .glassmorphism: return 18
        case .minimalFlat:   return 0
        case .enterprise:    return 0
        case .modernNeon:    return 8
        }
    }

    var cardBackgroundOpacity: Double {
        switch self {
        case .cardsClassic:  return 0.05
        case .glassmorphism: return 0.12
        case .minimalFlat:   return 0.02
        case .enterprise:    return 0.08
        case .modernNeon:    return 0.06
        }
    }

    var cardStrokeOpacity: Double {
        switch self {
        case .cardsClassic:  return 0.08
        case .glassmorphism: return 0.18
        case .minimalFlat:   return 0.0
        case .enterprise:    return 0.25
        case .modernNeon:    return 0.4
        }
    }

    var cardCornerRadiusBase: CGFloat {
        switch self {
        case .cardsClassic:  return 16
        case .glassmorphism: return 20
        case .minimalFlat:   return 8
        case .enterprise:    return 6
        case .modernNeon:    return 14
        }
    }

    var cardShadowOpacity: Double {
        switch self {
        case .cardsClassic:  return 0.15
        case .glassmorphism: return 0.22
        case .minimalFlat:   return 0.0
        case .enterprise:    return 0.18
        case .modernNeon:    return 0.35
        }
    }

    var usesAccentGlow: Bool { self == .modernNeon }
}
