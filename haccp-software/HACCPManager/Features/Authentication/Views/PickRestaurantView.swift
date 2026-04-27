import SwiftUI
import SwiftData

public struct PickRestaurantView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query(sort: \Restaurant.name) private var restaurants: [Restaurant]
    @Query private var stores: [AppDataStore]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            ThemeManager.shared.background.ignoresSafeArea()
            
            VStack(spacing: 50) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                    
                    Text("Seleziona Ristorante")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Scegli l'unità operativa su cui lavorare oggi.")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                // Restaurant Grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 30)], spacing: 30) {
                        ForEach(restaurants) { restaurant in
                            RestaurantCard(restaurant: restaurant) {
                                selectRestaurant(restaurant)
                            }
                        }
                    }
                    .padding(40)
                }
            }
        }
    }
    
    private func selectRestaurant(_ restaurant: Restaurant) {
        appState.switchRestaurant(id: restaurant.id, modelContext: modelContext)
    }
}

struct RestaurantCard: View {
    let restaurant: Restaurant
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 24) {
                // Logo Fallback
                ZStack {
                    if let data = restaurant.logoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "house.fill")
                            .font(.title)
                            .foregroundColor(.red.opacity(0.5))
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(restaurant.name)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text(restaurant.city)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Resp: \(restaurant.haccpManager)")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.red.opacity(0.7))
                    .font(.title3.bold())
            }
            .padding(24)
            .background(Color.white.opacity(0.04))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
