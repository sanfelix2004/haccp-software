//
//  ProductionLabelStickerView.swift
//  Anteprima etichetta adesiva HACCP (adesivo + stato fuori dal foglio).
//

import SwiftUI

struct ProductionLabelStickerView: View {
    let label: ProductionLabelRecord
    var compact: Bool = false

    @Environment(\.theme) private var theme
    @Bindable private var settingsStorage = SettingsStorageService.shared

    private var stickerContent: LabelStickerContent {
        LabelStickerContent.from(label, settings: settingsStorage.printer)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabelStickerCanvas(
                content: stickerContent,
                showSizeCaption: !compact,
                maxPreviewWidth: compact ? 280 : 420
            )

            if !compact {
                statusFooter
            }
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        HStack(spacing: 8) {
            switch label.expiryState {
            case .ok:
                HACCPBadge(title: "Scadenza OK", style: .conforme, showIcon: true)
            case .soon:
                HACCPBadge(title: "In scadenza", style: .warning, showIcon: true)
            case .expired:
                HACCPBadge(title: "Scaduto", style: .nonConforme, showIcon: true)
            }
            HACCPBadge(title: label.productStatus.label, style: .info, showIcon: false)
            if !label.allergenList.isEmpty {
                HACCPBadge(title: "Allergeni", style: .warning, showIcon: true)
            }
            Spacer(minLength: 0)
        }
        .font(theme.typography.caption2)
    }
}
