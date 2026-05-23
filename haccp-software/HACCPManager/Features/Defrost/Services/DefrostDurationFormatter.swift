//
//  DefrostDurationFormatter.swift
//  Timer da startAt (persistente).
//

import Foundation

enum DefrostDurationFormatter {

    static func elapsed(since startAt: Date, now: Date = Date()) -> TimeInterval {
        ProcessElapsedFormatter.elapsed(since: startAt, now: now)
    }

    static func format(elapsed: TimeInterval) -> String {
        ProcessElapsedFormatter.format(elapsed: elapsed)
    }

    static func format(since startAt: Date, now: Date = Date()) -> String {
        ProcessElapsedFormatter.format(since: startAt, now: now)
    }
}
