//
//  KitchenProcessNotifications.swift
//  Sincronizza Avvisi, Grafici, Storia e moduli dopo salvataggi operativi.
//

import Foundation

extension Notification.Name {
    /// Qualsiasi registrazione/criticità HACCP creata, aggiornata o risolta.
    static let kitchenProcessRecordsDidChange = Notification.Name("HACCP.kitchenProcessRecordsDidChange")
}

enum KitchenProcessNotifications {
    static func postRecordsDidChange() {
        NotificationCenter.default.post(name: .kitchenProcessRecordsDidChange, object: nil)
    }
}
