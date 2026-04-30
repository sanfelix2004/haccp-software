import SwiftUI

struct GoodsReceiptTemperatureSection: View {
    let requirement: GoodsReceiptRequirement
    @Binding var temperatureText: String

    private let keypad = ["1","2","3","4","5","6","7","8","9","+/-","0","."]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temperatura").font(.headline).foregroundColor(.white)
            HStack {
                TextField("--", text: $temperatureText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numbersAndPunctuation)
                Text("°C").foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.07))
            .cornerRadius(12)

            if requirement.defaultMinTemp != nil || requirement.defaultMaxTemp != nil {
                Text(rangeText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(keypad, id: \.self) { key in
                    Button(key) { tapKey(key) }
                        .buttonStyle(.borderedProminent)
                        .tint(.white.opacity(0.16))
                }
            }
        }
    }

    private var rangeText: String {
        if let min = requirement.defaultMinTemp, let max = requirement.defaultMaxTemp {
            return "Min: \(String(format: "%+.0f", min))°C  Max: \(String(format: "%+.0f", max))°C"
        }
        if let max = requirement.defaultMaxTemp {
            return "Max: \(String(format: "%+.0f", max))°C"
        }
        return ""
    }

    private func tapKey(_ key: String) {
        if key == "+/-" {
            if temperatureText.hasPrefix("-") { temperatureText.removeFirst() }
            else { temperatureText = "-" + temperatureText }
            return
        }
        if key == ".", temperatureText.contains(".") { return }
        temperatureText.append(key)
    }
}
