import SwiftUI
import SwiftData

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @Query(sort: [SortDescriptor(\DailyEntry.date, order: .reverse)]) private var allEntries: [DailyEntry]

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
    @State private var cyclePhase: CyclePhase = .notSet
    @State private var cycleDayText: String = ""
    @State private var cycleNote: String = ""
    @State private var symptoms: [EditableSymptom] = []
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    EditorHeroCard(date: date)

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

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

                    if appSettings.shouldShowCycleSection {
                        EditorSection(title: "Zyklus") {
                            Picker("Phase", selection: $cyclePhase) {
                                ForEach(CyclePhase.allCases) { phase in
                                    Text(phase.title).tag(phase)
                                }
                            }
                            .pickerStyle(.menu)

                            TextField("Zyklustag (optional)", text: $cycleDayText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)

                            TextField("Notiz zum Zyklus", text: $cycleNote, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    EditorSection(title: "Beschwerden") {
                        SymptomCategoryGrid(
                            selectedSymptoms: $symptoms
                        )

                        if !symptoms.isEmpty {
                            VStack(spacing: 10) {
                                ForEach($symptoms) { $symptom in
                                    SymptomSeverityRow(symptom: $symptom) {
                                        symptoms.removeAll { $0.id == symptom.id }
                                    }
                                }
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
        moodScore = min(max(entry.moodScore, 1), 5)
        cyclePhase = entry.cyclePhase
        cycleDayText = entry.cycleDay.map(String.init) ?? ""
        cycleNote = entry.cycleNote
        symptoms = entry.symptoms.compactMap(EditableSymptom.init(from:))
    }

    private func save() {
        validationMessage = nil

        let normalizedDate = Calendar.current.startOfDay(for: date)

        if let duplicate = allEntries.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) && $0.persistentModelID != entry?.persistentModelID
        }) {
            validationMessage = "Für diesen Tag existiert bereits ein Eintrag. Bitte bearbeite den vorhandenen Tag statt einen zweiten anzulegen."
            if entry == nil {
                populateFromExistingEntry(duplicate)
            }
            return
        }

        let target = entry ?? DailyEntry(date: normalizedDate)
        target.date = normalizedDate
        target.foodCategory = foodCategory
        target.foodNote = foodNote.trimmingCharacters(in: .whitespacesAndNewlines)
        target.generalNote = generalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        target.overallHydration = overallHydration
        target.hadCoffee = hadCoffee
        target.hadSoftdrinks = hadSoftdrinks
        target.alcoholLevel = alcoholLevel
        target.waterLevel = waterLevel
        target.otherDrinksNote = otherDrinksNote.trimmingCharacters(in: .whitespacesAndNewlines)
        target.moodScore = min(max(moodScore, 1), 5)
        target.cyclePhase = appSettings.shouldShowCycleSection ? cyclePhase : .notSet
        target.cycleDay = appSettings.shouldShowCycleSection ? sanitizedCycleDay : nil
        target.cycleNote = appSettings.shouldShowCycleSection ? cycleNote.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        target.updatedAt = .now

        replaceSymptoms(on: target)

        if entry == nil {
            modelContext.insert(target)
        }

        dismiss()
    }

    private var sanitizedCycleDay: Int? {
        guard let value = Int(cycleDayText), value > 0, value <= 60 else { return nil }
        return value
    }

    private func replaceSymptoms(on target: DailyEntry) {
        target.symptoms.removeAll()

        let newEntries: [SymptomEntry] = symptoms.compactMap { editable in
            guard let category = editable.category else { return nil }
            return SymptomEntry(
                name: category.displayName,
                severity: editable.severity,
                note: editable.note.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category
            )
        }

        for entry in newEntries {
            target.symptoms.append(entry)
        }
    }

    private func populateFromExistingEntry(_ existing: DailyEntry) {
        date = existing.date
        foodCategory = existing.foodCategory
        foodNote = existing.foodNote
        generalNote = existing.generalNote
        overallHydration = existing.overallHydration
        hadCoffee = existing.hadCoffee
        hadSoftdrinks = existing.hadSoftdrinks
        alcoholLevel = existing.alcoholLevel
        waterLevel = existing.waterLevel
        otherDrinksNote = existing.otherDrinksNote
        moodScore = existing.moodScore
        cyclePhase = existing.cyclePhase
        cycleDayText = existing.cycleDay.map(String.init) ?? ""
        cycleNote = existing.cycleNote
        symptoms = existing.symptoms.compactMap(EditableSymptom.init(from:))
    }
}

struct EditableSymptom: Identifiable, Equatable {
    let id = UUID()
    var category: SymptomCategory?
    var severity: SeverityLevel = .medium
    var note: String = ""

    init(category: SymptomCategory? = nil, severity: SeverityLevel = .medium, note: String = "") {
        self.category = category
        self.severity = severity
        self.note = note
    }

    /// Build from an existing persisted SymptomEntry. Skips entries without a
    /// category (defensive: shouldn't happen post-V2-migration, but if it does,
    /// dropping the row in the editor is safer than presenting an unselectable item).
    init?(from persisted: SymptomEntry) {
        guard let category = persisted.category else { return nil }
        self.category = category
        self.severity = persisted.severity
        self.note = persisted.note
    }

    static func == (lhs: EditableSymptom, rhs: EditableSymptom) -> Bool {
        lhs.id == rhs.id
            && lhs.severity == rhs.severity
            && lhs.note == rhs.note
            && lhs.category?.persistentModelID == rhs.category?.persistentModelID
    }
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

// MARK: - Symptom selection (V2: tap-only, no free text)

/// Tap-to-toggle grid of all active symptom categories. No free-text input.
/// Selecting a category appends a default-severity EditableSymptom; tapping
/// again removes it.
private struct SymptomCategoryGrid: View {
    @Binding var selectedSymptoms: [EditableSymptom]
    @Query(
        filter: #Predicate<SymptomCategory> { !$0.isArchived },
        sort: [SortDescriptor(\SymptomCategory.sortOrder), SortDescriptor(\SymptomCategory.displayName)]
    )
    private var categories: [SymptomCategory]

    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if categories.isEmpty {
                Text("Keine Kategorien verfügbar. Lege über Einstellungen → Symptom-Kategorien neue an.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(categories) { category in
                        SymptomCategoryChip(
                            category: category,
                            isSelected: isSelected(category)
                        ) {
                            toggle(category)
                        }
                    }
                }
            }
        }
    }

    private func isSelected(_ category: SymptomCategory) -> Bool {
        selectedSymptoms.contains { $0.category?.persistentModelID == category.persistentModelID }
    }

    private func toggle(_ category: SymptomCategory) {
        if let idx = selectedSymptoms.firstIndex(where: { $0.category?.persistentModelID == category.persistentModelID }) {
            selectedSymptoms.remove(at: idx)
        } else {
            selectedSymptoms.append(EditableSymptom(category: category))
        }
    }
}

private struct SymptomCategoryChip: View {
    let category: SymptomCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.symbolName)
                    .font(.subheadline.weight(.medium))
                Text(category.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Severity + optional note for a single selected symptom. Shown only after the
/// user has tapped a category chip.
private struct SymptomSeverityRow: View {
    @Binding var symptom: EditableSymptom
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let category = symptom.category {
                    Image(systemName: category.symbolName)
                        .foregroundStyle(.secondary)
                    Text(category.displayName)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Entfernen")
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
extension CyclePhase: TitledOption {}


