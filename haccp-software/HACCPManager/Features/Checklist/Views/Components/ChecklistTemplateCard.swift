//
//  ChecklistTemplateCard.swift
//

import SwiftUI

struct ChecklistTemplateCard: View {
    let template: ChecklistTemplate
    let canExecute: Bool
    let canManage: Bool
    let canDelete: Bool
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.colorPrimary.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: template.category.systemImage)
                        .font(.title3)
                        .foregroundStyle(theme.colorPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title)
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                    HStack(spacing: 8) {
                        Label(template.category.label, systemImage: template.category.systemImage)
                        Label(template.frequency.label, systemImage: template.frequency.systemImage)
                    }
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                    if !template.checklistDescription.isEmpty {
                        Text(template.checklistDescription)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                if !template.isActive {
                    HACCPBadge(title: "Inattivo", style: .neutral, showIcon: false)
                }
            }

            HStack(spacing: 10) {
                if canExecute {
                    PrimaryButton(title: "Avvia", icon: "play.fill", action: onStart)
                }
                if canManage {
                    SecondaryButton(title: "Modifica", icon: "pencil") {
                        onEdit()
                    }
                    if canDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(14)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(theme.colorDivider.opacity(0.8), lineWidth: 1)
        )
    }
}
