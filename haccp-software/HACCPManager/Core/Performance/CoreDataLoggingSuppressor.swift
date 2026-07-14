//
//  CoreDataLoggingSuppressor.swift
//  Disabilita log di debug Core Data/SwiftData (es. WAL checkpoint) in console.
//

import Foundation

enum CoreDataLoggingSuppressor {

    /// Deve essere chiamato prima di qualsiasi `ModelContainer` / Core Data init.
    static func apply() {
        disableUserDefaultsLogging()
        disableProcessEnvironmentLogging()
    }

    private static func disableUserDefaultsLogging() {
        let defaults = UserDefaults.standard
        let disabledFlags: [String: Any] = [
            "com.apple.CoreData.Logging.stderr": false,
            "com.apple.CoreData.SQLDebug": 0,
            "com.apple.CoreData.CloudKitDebug": 0,
            "com.apple.CoreData.ConcurrencyDebug": 0,
            "com.apple.CoreData.MigrationDebug": 0,
            "com.apple.CoreData.VerboseLogging": 0,
            "com.apple.CoreData.Logging.oslog": false,
        ]
        defaults.register(defaults: disabledFlags)
        for (key, value) in disabledFlags {
            defaults.set(value, forKey: key)
        }
    }

    private static func disableProcessEnvironmentLogging() {
        let envPairs: [(String, String)] = [
            ("com.apple.CoreData.Logging.stderr", "0"),
            ("com.apple.CoreData.SQLDebug", "0"),
            ("com.apple.CoreData.CloudKitDebug", "0"),
            ("com.apple.CoreData.ConcurrencyDebug", "0"),
            ("com.apple.CoreData.MigrationDebug", "0"),
            ("com.apple.CoreData.VerboseLogging", "0"),
        ]
        for (key, value) in envPairs {
            setenv(key, value, 1)
        }
    }
}
