import SwiftUI

/// Selettori giorno settimana / mese per programmazione checklist.
enum ChecklistSchedulePicker {
    static let weekdayOptions: [(value: Int, label: String)] = [
        (2, "Lunedì"),
        (3, "Martedì"),
        (4, "Mercoledì"),
        (5, "Giovedì"),
        (6, "Venerdì"),
        (7, "Sabato"),
        (1, "Domenica")
    ]

    static let monthOptions: [(value: Int, label: String)] = [
        (1, "Gennaio"), (2, "Febbraio"), (3, "Marzo"), (4, "Aprile"),
        (5, "Maggio"), (6, "Giugno"), (7, "Luglio"), (8, "Agosto"),
        (9, "Settembre"), (10, "Ottobre"), (11, "Novembre"), (12, "Dicembre")
    ]

    static func defaultWeekday() -> Int { 2 }

    static func defaultDayOfMonth() -> Int { 1 }
}

struct ChecklistScheduleFormSection: View {
    @Binding var frequency: ChecklistFrequency
    @Binding var scheduledHour: Int
    @Binding var scheduledMinute: Int
    @Binding var scheduleWeekday: Int
    @Binding var scheduleDayOfMonth: Int
    @Binding var scheduleMonth: Int

    var body: some View {
        Section("Programmazione") {
            Stepper("Ora: \(scheduledHour)", value: $scheduledHour, in: 0...23)
            Stepper("Minuti: \(scheduledMinute)", value: $scheduledMinute, in: 0...59)

            if frequency == .weekly {
                Picker("Giorno settimana", selection: $scheduleWeekday) {
                    ForEach(ChecklistSchedulePicker.weekdayOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                Text("Visibile nel tab Oggi solo in questo giorno.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if frequency == .monthly {
                Stepper("Giorno del mese: \(scheduleDayOfMonth)", value: $scheduleDayOfMonth, in: 1...28)
                Text("Compare nel tab Oggi solo il giorno indicato di ogni mese.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if frequency == .annual {
                Picker("Mese", selection: $scheduleMonth) {
                    ForEach(ChecklistSchedulePicker.monthOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                Stepper("Giorno: \(scheduleDayOfMonth)", value: $scheduleDayOfMonth, in: 1...28)
                Text("Compare una volta l'anno nella data indicata.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ChecklistBulkPassFormSection: View {
    @Binding var allowsBulkPass: Bool
    @Binding var bulkPassTitle: String
    let itemCount: Int

    var body: some View {
        if itemCount >= 2 {
            Section("Compilazione rapida") {
                Toggle("Pulsante «tutto conforme»", isOn: $allowsBulkPass)
                if allowsBulkPass {
                    TextField("Testo pulsante (es. Tutte le guarnizioni sono integre)", text: $bulkPassTitle)
                    Text("L'operatore può confermare tutte le voci con un tap e correggere solo le eccezioni.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
