//
//  ProcessElapsedFormatter.swift
//  Cronometro da 0 → 1 → 2 … poi M:SS, poi H:MM:SS.
//

import Foundation

enum ProcessElapsedFormatter {

    static func elapsed(since start: Date, now: Date = Date()) -> TimeInterval {
        max(0, now.timeIntervalSince(start))
    }

    static func format(elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "\(seconds)"
    }

    static func format(since start: Date, now: Date = Date()) -> String {
        format(elapsed: elapsed(since: start, now: now))
    }
}
