//
//  BlastChillingDurationFormatter.swift
//  Timer calcolato da startedAt (persistente, non fragile).
//

import Foundation

enum BlastChillingDurationFormatter {

    static func elapsed(since startedAt: Date, now: Date = Date()) -> TimeInterval {
        ProcessElapsedFormatter.elapsed(since: startedAt, now: now)
    }

    static func format(elapsed: TimeInterval) -> String {
        ProcessElapsedFormatter.format(elapsed: elapsed)
    }

    static func format(since startedAt: Date, now: Date = Date()) -> String {
        ProcessElapsedFormatter.format(since: startedAt, now: now)
    }

    static func isOverRecommendedDuration(since startedAt: Date, now: Date = Date()) -> Bool {
        let limit = TimeInterval(PerformanceConfig.blastChillingRecommendedMinutes * 60)
        return elapsed(since: startedAt, now: now) > limit
    }
}
