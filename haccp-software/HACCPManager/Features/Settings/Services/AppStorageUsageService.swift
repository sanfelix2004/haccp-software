//
//  AppStorageUsageService.swift
//  Calcolo spazio occupato su disco (SwiftData, PDF, cache).
//

import Foundation

struct AppStorageUsageBreakdown: Equatable {
    var swiftDataBytes: Int64 = 0
    var attachmentsBytes: Int64 = 0
    var cacheBytes: Int64 = 0

    var totalBytes: Int64 {
        swiftDataBytes + attachmentsBytes + cacheBytes
    }

    static let empty = AppStorageUsageBreakdown()
}

enum AppStorageUsageService {

    /// Calcolo su background thread (I/O disco).
    nonisolated static func calculate() async -> AppStorageUsageBreakdown {
        await Task.detached(priority: .utility) {
            computeBreakdown()
        }.value
    }

    nonisolated static func formattedBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        let value = Double(bytes)
        if value < 1_024 {
            return "\(bytes) B"
        }
        if value < 1_024 * 1_024 {
            return String(format: "%.1f KB", value / 1_024)
        }
        if value < 1_024 * 1_024 * 1_024 {
            return String(format: "%.1f MB", value / 1_024 / 1_024)
        }
        return String(format: "%.2f GB", value / 1_024 / 1_024 / 1_024)
    }

    nonisolated private static func computeBreakdown() -> AppStorageUsageBreakdown {
        var breakdown = AppStorageUsageBreakdown()
        let fm = FileManager.default

        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            breakdown.swiftDataBytes = directorySize(
                appSupport,
                including: { url in
                    let name = url.lastPathComponent.lowercased()
                    return name.hasSuffix(".store")
                        || name.hasSuffix(".store-wal")
                        || name.hasSuffix(".store-shm")
                }
            )
            let haccpRoot = appSupport.appendingPathComponent("HACCPManager", isDirectory: true)
            if fm.fileExists(atPath: haccpRoot.path) {
                breakdown.attachmentsBytes = directorySize(haccpRoot, including: { _ in true })
            }
        }

        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            breakdown.cacheBytes = directorySize(caches, including: { _ in true })
        }

        return breakdown
    }

    nonisolated private static func directorySize(
        _ url: URL,
        including filter: (URL) -> Bool
    ) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  filter(fileURL) else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
