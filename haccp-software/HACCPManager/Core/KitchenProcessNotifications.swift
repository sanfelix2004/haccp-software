//
//  KitchenProcessNotifications.swift
//  Sincronizza storico globale e schermate modulo dopo salvataggio.
//

import Foundation

extension Notification.Name {
    /// Decongelamento o abbattimento creati, completati o annullati.
    static let kitchenProcessRecordsDidChange = Notification.Name("HACCP.kitchenProcessRecordsDidChange")
}

enum KitchenProcessNotifications {
    static func postRecordsDidChange() {
        NotificationCenter.default.post(name: .kitchenProcessRecordsDidChange, object: nil)
    }
}
