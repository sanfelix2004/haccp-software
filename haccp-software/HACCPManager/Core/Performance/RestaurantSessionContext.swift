//
//  RestaurantSessionContext.swift
//  Utente e ristorante attivi — una sola @Query in root, niente query duplicate per modulo.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class RestaurantSessionContext: ObservableObject {
    @Published private(set) var currentUser: LocalUser?
    @Published private(set) var masterUser: LocalUser?
    @Published private(set) var activeRestaurant: Restaurant?

    func sync(
        users: [LocalUser],
        restaurants: [Restaurant],
        currentUserId: UUID?,
        activeRestaurantId: UUID?
    ) {
        currentUser = currentUserId.flatMap { id in users.first { $0.id == id } }
        masterUser = users.first { $0.role == .master }
        if let activeRestaurantId {
            activeRestaurant = restaurants.first { $0.id == activeRestaurantId }
        } else {
            activeRestaurant = restaurants.first
        }
    }
}
