import SwiftUI
import SwiftData

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: DailyEntry?

    @State private var date: Date = .now
    @State private var foodCategory: FoodCategory = .regular
    @State private var foodNote: String = ""
    @State private var generalNote: String = ""
    @State private var overallHydration: IntakeLevel = .medium
    @State private var hadCoffee = false
    @State private var hadSoftdrinks = false
    @State private var alcoholLevel: OptionalIntakeLevel = .none
    @State private var waterLevel: OptionalIntakeLevel = .medium
    @State private var otherDrinksNote: String = ""
    @State private var symptoms: [EditableSymptom] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Tag") {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                }

                Section("Essen") {
                    Picker("Heute gegessen", selection: $foodCategory) {
                        ForEach(FoodCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Kurze Notiz zum Essen", text: $foodNote, axis: .vertical)
                }

                Section("Trinken erfassen") {
                    LabeledContent("Insgesamt getrunken") {
                        MenuPicker(options: IntakeLevel.allCases, selection: $overallHydration)
                    }

                    Toggle("Kaffee", isOn: $hadCoffee)
                    Toggle("Softdrinks", isOn: $hadSoftdrinks)

                    LabeledContent("Alkohol") {
                        MenuPicker(options: OptionalIntakeLevel.allCases, selection: $alcoholLevel)
                    }

                    LabeledContent("Wasser") {
                        MenuPicker(options: OptionalIntakeLevel.allCases, selection: $waterLevel)
                    }

                    TextField("Anderes", text: $otherDrinksNote, axis: .vertical)
                }

                Section("Beschwerden") {
                    SymptomPresetScroller { preset in
                        symptoms.append(.init(name: preset == .custom ? "" : preset.title))
                    }

                    ForEach($symptoms) { $symptom in
                        SymptomEditorRow(symptom: $symptom)
                    }
                    .onDelete { symptoms.remove(atOffsets: $0) }
                }

                Section("Notizen") {
                    TextField("Was war heute noch wichtig?", text: $generalNote, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle(entry == nil ? "Check-in" : "Tag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        save()
                    }
                }
            }
            .onAppear(perform: loadExistingEntry)
        }
    }

    private func loadExistingEntry() {
        guard let entry else { return }
        date = entry.date
        foodCategory = entry.foodCategory
        foodNote = entry.foodNote
        generalNote = entry.generalNote
        overallHydration = entry.overallHydration
        hadCoffee = entry.hadCoffee
        hadSoftdrinks = entry.hadSoftdrinks
        alcoholLevel = entry.alcoholLevel
        waterLevel = entry.waterLevel
        otherDrinksNote = entry.otherDrinksNote
        symptoms = entry.symptoms.map { EditableSymptom(name: $0.name, severity: $0.severity, note: $0.note) }
    }

    private func save() {
        let target = entry ?? DailyEntry(date: date)
        target.date = Calendar.current.startOfDay(for: date)
        target.foodCategory = foodCategory
        target.foodNote = foodNote
        target.generalNote = generalNote
        target.overallHydration = overallHydration
        target.hadCoffee = hadCoffee
        target.hadSoftdrinks = hadSoftdrinks
        target.alcoholLevel = alcoholLevel
        target.waterLevel = waterLevel
        target.otherDrinksNote = otherDrinksNote
        target.updatedAt = .now

        target.symptoms.removeAll()

        for symptom in symptoms where !symptom.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            target.symptoms.append(SymptomEntry(name: symptom.name, severity: symptom.severity, note: symptom.note))
        }

        if entry == nil {
            modelContext.insert(target)
        }

        dismiss()
    }
}

struct EditableSymptom: Identifiable {
    let id = UUID()
    var name: String = ""
    var severity: SeverityLevel = .medium
    var note: String = ""
}

private struct SymptomEditorRow: View {
    @Binding var symptom: EditableSymptom

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Beschwerde", text: $symptom.name)
            Picker("Stärke", selection: $symptom.severity) {
                ForEach(SeverityLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)

            TextField("Optionale Notiz", text: $symptom.note)
        }
        .padding(.vertical, 6)
    }
}

private struct MenuPicker<Option: CaseIterable & Identifiable & Hashable & TitledOption>: View where Option.AllCases: RandomAccessCollection {
    let options: Option.AllCases
    @Binding var selection: Option

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(Array(options), id: \.self) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)
    }
}

private protocol TitledOption {
    var title: String { get }
}

extension IntakeLevel: TitledOption {}
extension OptionalIntakeLevel: TitledOption {}

private struct SymptomPresetScroller: View {
    let onSelect: (SymptomPreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SymptomPreset.allCases) { preset in
                    Button(preset.title) {
                        onSelect(preset)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
