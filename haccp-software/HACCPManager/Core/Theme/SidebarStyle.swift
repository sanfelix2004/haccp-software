//
//  SidebarStyle.swift
//  HACCP Manager — Theme System
//

import Foundation
import SwiftUI

enum SidebarStyle: Int, CaseIterable, Identifiable, Codable {
    case full     = 0
    case compact  = 1
    case floating = 2
    case blur     = 3
    case solid    = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .full:     return "Full"
        case .compact:  return "Compact"
        case .floating: return "Floating"
        case .blur:     return "Blur"
        case .solid:    return "Solid"
        }
    }

    var icon: String {
        switch self {
        case .full:     return "sidebar.left"
        case .compact:  return "sidebar.squares.left"
        case .floating: return "rectangle.righthalf.inset.filled.arrow.right"
        case .blur:     return "rectangle.dashed"
        case .solid:    return "rectangle.fill"
        }
    }

    var helper: String {
        switch self {
        case .full:     return "Sidebar estesa con icona + etichetta. Massima leggibilità."
        case .compact:  return "Solo icone, larghezza ridotta. Più spazio ai contenuti."
        case .floating: return "Sidebar fluttuante con bordi morbidi e separazione dal contenuto."
        case .blur:     return "Sfondo sidebar in vetro smerigliato. Look premium Apple."
        case .solid:    return "Fondo opaco a tinta unita. Look enterprise pulito."
        }
    }

    var prefersBlur: Bool { self == .blur || self == .floating }
    var prefersOpaque: Bool { self == .solid }
    var prefersCompact: Bool { self == .compact }
}
