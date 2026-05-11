//
//  ThemeSpacing.swift
//  HACCP Manager — Theme System
//
//  Token di spaziatura/raggi/altezze. Si adattano al LayoutMode scelto.
//

import Foundation
import SwiftUI

struct ThemeSpacing {
    let layoutMode: LayoutMode
    let cornerBase: CGFloat

    init(layoutMode: LayoutMode = .comfortable, cornerBase: CGFloat = 16) {
        self.layoutMode = layoutMode
        self.cornerBase = cornerBase
    }

    private var m: CGFloat { layoutMode.densityMultiplier }

    // Scala di spaziatura (xs..xxl) modulata dalla densità.
    var xxs: CGFloat { 2 * m }
    var xs:  CGFloat { 4 * m }
    var sm:  CGFloat { 8 * m }
    var md:  CGFloat { 12 * m }
    var lg:  CGFloat { 16 * m }
    var xl:  CGFloat { 24 * m }
    var xxl: CGFloat { 32 * m }
    var xxxl: CGFloat { 48 * m }

    // Padding di base
    var cardPadding:        CGFloat { lg }
    var screenPadding:      CGFloat { lg }
    var sectionSpacing:     CGFloat { xl }

    // Corner radii (modulati su tema + layout)
    var cornerSmall:  CGFloat { max(4, cornerBase * 0.5  * m) }
    var cornerMedium: CGFloat { max(6, cornerBase * 0.75 * m) }
    var cornerLarge:  CGFloat { max(8, cornerBase        * m) }
    var cornerXL:     CGFloat { max(12, cornerBase * 1.25 * m) }

    // Buttons
    var buttonMinHeight: CGFloat { layoutMode.minimumButtonHeight }
    var buttonHorizontalPadding: CGFloat { lg }
    var buttonVerticalPadding:   CGFloat { md }
    var buttonCornerRadius:      CGFloat { cornerMedium }

    // Card height defaults (per dashboard grid)
    var dashboardTileMinHeight: CGFloat {
        switch layoutMode {
        case .compact:     return 110
        case .comfortable: return 132
        case .largeTouch:  return 164
        }
    }
}
