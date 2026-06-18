//
//  LiveProcessDurationText.swift
//  Cronometro live indipendente dal ticker globale (TimelineView).
//

import SwiftUI

struct LiveProcessDurationText: View {
    let since: Date
    var font: Font = .body
    var color: Color?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            Text(ProcessElapsedFormatter.format(since: since, now: timeline.date))
                .font(font)
                .monospacedDigit()
                .foregroundStyle(color ?? .primary)
        }
    }
}
