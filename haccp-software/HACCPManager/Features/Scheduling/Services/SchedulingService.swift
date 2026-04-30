import Foundation

struct SchedulingService {
    func dueCount(tasks: [ScheduledTask], now: Date = Date()) -> Int {
        tasks.filter { !$0.isCompleted && ($0.dueAt ?? .distantFuture) <= now }.count
    }
}
