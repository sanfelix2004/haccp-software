import SwiftUI

struct GoodsReceiptTemperatureSection: View {
    let requirement: GoodsReceiptRequirement
    @Binding var temperatureText: String

    private let keypad = ["1","2","3","4","5","6","7","8","9","+/-","0","."]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temperatura").font(.headline).foregroundStyle(ThemeManager.shared.colorTextPrimary)
            HStack {
                TextField("--", text: $temperatureText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numbersAndPunctuation)
                Text("°C").foregroundStyle(ThemeManager.shared.colorTextPrimary)
            }
            .padding(10)
            .background(ThemeManager.shared.colorSurfaceElevated)
            .cornerRadius(12)

            if requirement.defaultMinTemp != nil || requirement.defaultMaxTemp != nil {
                Text(rangeText)
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(keypad, id: \.self) { key in
                    Button(key) { tapKey(key) }
                        .buttonStyle(.borderedProminent)
                        .tint(ThemeManager.shared.colorPrimary)
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
