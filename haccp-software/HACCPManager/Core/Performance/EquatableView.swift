//
//  EquatableView.swift
//  Riduce over-rendering SwiftUI su righe/liste stabili.
//

import SwiftUI

/// Wrapper che evita il re-render quando `content` è `Equatable` e invariato.
struct EquatableView<Content: View & Equatable>: View, Equatable {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
    }

    static func == (lhs: EquatableView<Content>, rhs: EquatableView<Content>) -> Bool {
        lhs.content == rhs.content
    }
}

extension View where Self: Equatable {
    /// Applica confronto strutturale per evitare invalidazioni della gerarchia.
    func performanceEquatable() -> EquatableView<Self> {
        EquatableView { self }
    }
}
