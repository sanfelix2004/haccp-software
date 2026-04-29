import SwiftUI

struct AnalyticsPeriodPicker: View {
    @Binding var selection: AnalyticsPeriod

    var body: some View {
        Picker("Periodo", selection: $selection) {
            ForEach(AnalyticsPeriod.allCases) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }
}
