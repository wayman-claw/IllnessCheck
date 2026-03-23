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
    @State private var symptoms: [EditableSymptom] = []
    @State private var drinks: [EditableDrink] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Day") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Food") {
                    Picker("Category", selection: $foodCategory) {
                        ForEach(FoodCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }

                    TextField("Food note", text: $foodNote, axis: .vertical)
                }

                Section("Drinks") {
                    ForEach($drinks) { $drink in
                        DrinkEditorRow(drink: $drink)
                    }
                    .onDelete { drinks.remove(atOffsets: $0) }

                    Button("Add Drink") {
                        drinks.append(.init())
                    }
                }

                Section("Symptoms / Pain") {
                    ForEach($symptoms) { $symptom in
                        SymptomEditorRow(symptom: $symptom)
                    }
                    .onDelete { symptoms.remove(atOffsets: $0) }

                    Button("Add Symptom") {
                        symptoms.append(.init())
                    }
                }

                Section("Notes") {
                    TextField("Anything worth remembering?", text: $generalNote, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle(entry == nil ? "New Day" : "Edit Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
        symptoms = entry.symptoms.map { EditableSymptom(name: $0.name, severity: $0.severity, note: $0.note) }
        drinks = entry.drinks.map { EditableDrink(type: $0.type, amount: $0.amount, unit: $0.unit) }
    }

    private func save() {
        let target = entry ?? DailyEntry(date: date)
        target.date = Calendar.current.startOfDay(for: date)
        target.foodCategory = foodCategory
        target.foodNote = foodNote
        target.generalNote = generalNote
        target.updatedAt = .now

        target.symptoms.removeAll()
        target.drinks.removeAll()

        for symptom in symptoms where !symptom.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            target.symptoms.append(SymptomEntry(name: symptom.name, severity: symptom.severity, note: symptom.note))
        }

        for drink in drinks where drink.amount > 0 {
            target.drinks.append(DrinkEntry(type: drink.type, amount: drink.amount, unit: drink.unit))
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

struct EditableDrink: Identifiable {
    let id = UUID()
    var type: DrinkType = .water
    var amount: Double = 250
    var unit: DrinkUnit = .milliliters
}

private struct SymptomEditorRow: View {
    @Binding var symptom: EditableSymptom

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Symptom", text: $symptom.name)
            Picker("Severity", selection: $symptom.severity) {
                ForEach(SeverityLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
            TextField("Optional note", text: $symptom.note)
        }
        .padding(.vertical, 4)
    }
}

private struct DrinkEditorRow: View {
    @Binding var drink: EditableDrink

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Type", selection: $drink.type) {
                ForEach(DrinkType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }

            HStack {
                TextField("Amount", value: $drink.amount, format: .number)
                    .keyboardType(.decimalPad)
                Picker("Unit", selection: $drink.unit) {
                    ForEach(DrinkUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
