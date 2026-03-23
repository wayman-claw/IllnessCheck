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
    @State private var moodScore: Int = 3
    @State private var symptoms: [EditableSymptom] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    EditorHeroCard(date: date)

                    EditorSection(title: "Tag") {
                        DatePicker("Datum", selection: $date, displayedComponents: .date)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tagesgefühl")
                                .font(.subheadline.weight(.medium))
                            MoodScorePicker(score: $moodScore)
                        }
                    }

                    EditorSection(title: "Essen") {
                        Picker("Heute gegessen", selection: $foodCategory) {
                            ForEach(FoodCategory.allCases) { category in
                                Text(category.title).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField("Kurze Notiz zum Essen", text: $foodNote, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                    }

                    EditorSection(title: "Trinken") {
                        DrinkLevelCard(title: "Insgesamt", icon: "drop.circle.fill", selection: $overallHydration)

                        HStack(spacing: 12) {
                            ToggleChip(title: "Kaffee", icon: "cup.and.saucer.fill", isOn: $hadCoffee)
                            ToggleChip(title: "Softdrinks", icon: "takeoutbag.and.cup.and.straw.fill", isOn: $hadSoftdrinks)
                        }

                        LabeledContent("Alkohol") {
                            MenuPicker(options: OptionalIntakeLevel.allCases, selection: $alcoholLevel)
                        }
                        LabeledContent("Wasser") {
                            MenuPicker(options: OptionalIntakeLevel.allCases, selection: $waterLevel)
                        }
                        TextField("Anderes", text: $otherDrinksNote, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                    }

                    EditorSection(title: "Beschwerden") {
                        SymptomPresetScroller { preset in
                            symptoms.append(.init(name: preset == .custom ? "" : preset.title))
                        }

                        if symptoms.isEmpty {
                            Text("Keine Beschwerden hinzugefügt")
                                .foregroundStyle(.secondary)
                        }

                        ForEach($symptoms) { $symptom in
                            SymptomEditorCard(symptom: $symptom) {
                                symptoms.removeAll { $0.id == symptom.id }
                            }
                        }
                    }

                    EditorSection(title: "Notizen") {
                        TextField("Was war heute noch wichtig?", text: $generalNote, axis: .vertical)
                            .lineLimit(4...8)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        save()
                    }
                    .fontWeight(.semibold)
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
        moodScore = entry.moodScore
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
        target.moodScore = moodScore
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

struct EditableSymptom: Identifiable, Equatable {
    let id = UUID()
    var name: String = ""
    var severity: SeverityLevel = .medium
    var note: String = ""
}

private struct EditorHeroCard: View {
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wie war dein Tag?")
                .font(.title.bold())
            Text(date.formatted(date: .complete, time: .omitted))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.16), Color.blue.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

private struct EditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

private struct MoodScorePicker: View {
    @Binding var score: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    score = value
                } label: {
                    Image(systemName: value <= score ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(value <= score ? .pink : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DrinkLevelCard: View {
    let title: String
    let icon: String
    @Binding var selection: IntakeLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(selection.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.1), in: Capsule())
            }

            HStack(spacing: 12) {
                ForEach(IntakeLevel.allCases) { option in
                    Button {
                        selection = option
                    } label: {
                        VStack(spacing: 8) {
                            WaterGlassIcon(fillFraction: option.fillFraction, isSelected: selection == option)
                                .frame(width: 32, height: 40)
                            Text(option.title)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection == option ? Color.blue.opacity(0.12) : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct WaterGlassIcon: View {
    let fillFraction: Double
    let isSelected: Bool

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let width = geometry.size.width
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.5), lineWidth: 2)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: width - 8, height: max(6, (height - 8) * fillFraction))
                    .padding(.bottom, 4)
            }
        }
    }
}

private struct ToggleChip: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isOn ? Color.orange.opacity(0.16) : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SymptomEditorCard: View {
    @Binding var symptom: EditableSymptom
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Beschwerde", text: $symptom.name)
                    .textFieldStyle(.roundedBorder)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
            }

            Picker("Stärke", selection: $symptom.severity) {
                ForEach(SeverityLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)

            TextField("Optionale Notiz", text: $symptom.note)
                .textFieldStyle(.roundedBorder)
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .padding(.vertical, 2)
        }
    }
}
