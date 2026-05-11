//
//  BackgroundStyle.swift
//  HACCP Manager — Theme System
//

import Foundation
import SwiftUI

enum BackgroundStyle: Int, CaseIterable, Identifiable, Codable {
    case solid    = 0
    case gradient = 1
    case minimal  = 2
    case texture  = 3
    case animated = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .solid:    return "Solido"
        case .gradient: return "Gradiente"
        case .minimal:  return "Minimal"
        case .texture:  return "Texture"
        case .animated: return "Animato"
        }
    }

    var icon: String {
        switch self {
        case .solid:    return "square.fill"
        case .gradient: return "circle.lefthalf.filled.righthalf.striped.horizontal"
        case .minimal:  return "minus.square"
        case .texture:  return "scribble.variable"
        case .animated: return "waveform.path"
        }
    }

    var helper: String {
        switch self {
        case .solid:    return "Tinta unita per massima sobrietà."
        case .gradient: return "Sfumatura discreta dall'angolo superiore."
        case .minimal:  return "Background piatto leggermente più chiaro/scuro."
        case .texture:  return "Pattern molto leggero tipo carta lavorata."
        case .animated: return "Aurora animata in modo leggero (può impattare batteria)."
        }
    }

    var isAnimated: Bool { self == .animated }
}
