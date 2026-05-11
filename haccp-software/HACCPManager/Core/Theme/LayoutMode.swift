//
//  LayoutMode.swift
//  HACCP Manager — Theme System
//
//  Definisce la densità di spaziatura globale dell'app.
//  Le views devono leggere i token tramite `ThemeSpacing` (non hard-coded).
//

import Foundation
import SwiftUI

enum LayoutMode: Int, CaseIterable, Identifiable, Codable {
    case compact     = 0
    case comfortable = 1
    case largeTouch  = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .compact:     return "Compatto"
        case .comfortable: return "Confortevole"
        case .largeTouch:  return "Large Touch"
        }
    }

    var icon: String {
        switch self {
        case .compact:     return "rectangle.compress.vertical"
        case .comfortable: return "rectangle.split.2x2"
        case .largeTouch:  return "hand.tap.fill"
        }
    }

    var helper: String {
        switch self {
        case .compact:     return "Card più piccole e più dati per schermata."
        case .comfortable: return "Spaziatura bilanciata. Default consigliato per iPad."
        case .largeTouch:  return "Pulsanti enormi e tap area maggiorata: ideale per cucina."
        }
    }

    /// Moltiplicatore globale per padding / corner radius / button height.
    var densityMultiplier: CGFloat {
        switch self {
        case .compact:     return 0.85
        case .comfortable: return 1.0
        case .largeTouch:  return 1.25
        }
    }

    var minimumButtonHeight: CGFloat {
        switch self {
        case .compact:     return 36
        case .comfortable: return 44
        case .largeTouch:  return 60
        }
    }
}
