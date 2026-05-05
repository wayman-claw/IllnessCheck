import Foundation
import SwiftData

// MARK: - Versioned model namespaces
//
// SwiftData requires that each VersionedSchema has its OWN `@Model` class
// references. If V1 and V2 both list the same `DailyEntry.self`, the migration
// planner crashes with:
//   "The current model reference and the next model reference cannot be equal."
//
// We solve this the canonical way: every schema version owns its model classes
// as nested types. The rest of the app uses top-level typealiases that always
// point at the *current* schema (V2 today). When we introduce V3 later, we
// add SchemaV3 with its own nested classes, bump the typealiases, and add a
// new MigrationStage. No call sites change.

// MARK: SchemaV1 (legacy — pre symptom categories)

extension SchemaV1 {
    /// V1 shape of DailyEntry. Identical fields to today, but lives under V1
    /// so SwiftData can read pre-migration stores.
    @Model
    final class DailyEntry {
        var date: Date
        var foodCategoryRaw: String
        var foodNote: String
        var generalNote: String
        var overallHydrationRaw: String
        var hadCoffee: Bool
        var hadSoftdrinks: Bool
        var alcoholLevelRaw: String
        var waterLevelRaw: String
        var otherDrinksNote: String
        var moodScore: Int
        var cyclePhaseRaw: String
        var cycleDay: Int?
        var cycleNote: String
        var createdAt: Date
        var updatedAt: Date
        @Relationship(deleteRule: .cascade) var symptoms: [SchemaV1.SymptomEntry]

        init(
            date: Date = .now,
            foodCategoryRaw: String = FoodCategory.regular.rawValue,
            foodNote: String = "",
            generalNote: String = "",
            overallHydrationRaw: String = IntakeLevel.medium.rawValue,
            hadCoffee: Bool = false,
            hadSoftdrinks: Bool = false,
            alcoholLevelRaw: String = OptionalIntakeLevel.none.rawValue,
            waterLevelRaw: String = OptionalIntakeLevel.medium.rawValue,
            otherDrinksNote: String = "",
            moodScore: Int = 3,
            cyclePhaseRaw: String = CyclePhase.notSet.rawValue,
            cycleDay: Int? = nil,
            cycleNote: String = "",
            createdAt: Date = .now,
            updatedAt: Date = .now,
            symptoms: [SchemaV1.SymptomEntry] = []
        ) {
            self.date = Calendar.current.startOfDay(for: date)
            self.foodCategoryRaw = foodCategoryRaw
            self.foodNote = foodNote
            self.generalNote = generalNote
            self.overallHydrationRaw = overallHydrationRaw
            self.hadCoffee = hadCoffee
            self.hadSoftdrinks = hadSoftdrinks
            self.alcoholLevelRaw = alcoholLevelRaw
            self.waterLevelRaw = waterLevelRaw
            self.otherDrinksNote = otherDrinksNote
            self.moodScore = moodScore
            self.cyclePhaseRaw = cyclePhaseRaw
            self.cycleDay = cycleDay
            self.cycleNote = cycleNote
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.symptoms = symptoms
        }
    }

    /// V1 shape of SymptomEntry: only free-text `name`, no category relationship.
    @Model
    final class SymptomEntry {
        var name: String
        var severityRaw: String
        var note: String

        init(name: String, severityRaw: String, note: String = "") {
            self.name = name
            self.severityRaw = severityRaw
            self.note = note
        }
    }
}

// MARK: SchemaV2 (current — symptom categories)

extension SchemaV2 {
    @Model
    final class DailyEntry {
        var date: Date
        var foodCategoryRaw: String
        var foodNote: String
        var generalNote: String
        var overallHydrationRaw: String
        var hadCoffee: Bool
        var hadSoftdrinks: Bool
        var alcoholLevelRaw: String
        var waterLevelRaw: String
        var otherDrinksNote: String
        var moodScore: Int
        var cyclePhaseRaw: String
        var cycleDay: Int?
        var cycleNote: String
        var createdAt: Date
        var updatedAt: Date
        @Relationship(deleteRule: .cascade) var symptoms: [SchemaV2.SymptomEntry]

        init(
            date: Date = .now,
            foodCategory: FoodCategory = .regular,
            foodNote: String = "",
            generalNote: String = "",
            overallHydration: IntakeLevel = .medium,
            hadCoffee: Bool = false,
            hadSoftdrinks: Bool = false,
            alcoholLevel: OptionalIntakeLevel = .none,
            waterLevel: OptionalIntakeLevel = .medium,
            otherDrinksNote: String = "",
            moodScore: Int = 3,
            cyclePhase: CyclePhase = .notSet,
            cycleDay: Int? = nil,
            cycleNote: String = "",
            createdAt: Date = .now,
            updatedAt: Date = .now,
            symptoms: [SchemaV2.SymptomEntry] = []
        ) {
            self.date = Calendar.current.startOfDay(for: date)
            self.foodCategoryRaw = foodCategory.rawValue
            self.foodNote = foodNote
            self.generalNote = generalNote
            self.overallHydrationRaw = overallHydration.rawValue
            self.hadCoffee = hadCoffee
            self.hadSoftdrinks = hadSoftdrinks
            self.alcoholLevelRaw = alcoholLevel.rawValue
            self.waterLevelRaw = waterLevel.rawValue
            self.otherDrinksNote = otherDrinksNote
            self.moodScore = moodScore
            self.cyclePhaseRaw = cyclePhase.rawValue
            self.cycleDay = cycleDay
            self.cycleNote = cycleNote
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.symptoms = symptoms
        }

        var foodCategory: FoodCategory {
            get { FoodCategory(rawValue: foodCategoryRaw) ?? .regular }
            set { foodCategoryRaw = newValue.rawValue }
        }

        var overallHydration: IntakeLevel {
            get { IntakeLevel(rawValue: overallHydrationRaw) ?? .medium }
            set { overallHydrationRaw = newValue.rawValue }
        }

        var alcoholLevel: OptionalIntakeLevel {
            get { OptionalIntakeLevel(rawValue: alcoholLevelRaw) ?? .none }
            set { alcoholLevelRaw = newValue.rawValue }
        }

        var waterLevel: OptionalIntakeLevel {
            get { OptionalIntakeLevel(rawValue: waterLevelRaw) ?? .medium }
            set { waterLevelRaw = newValue.rawValue }
        }

        var cyclePhase: CyclePhase {
            get { CyclePhase(rawValue: cyclePhaseRaw) ?? .notSet }
            set { cyclePhaseRaw = newValue.rawValue }
        }
    }

    @Model
    final class SymptomEntry {
        /// Legacy free-text name. Kept for audit/back-compat: any pre-V2 entries had only
        /// this field. New entries (V2+) leave this as nil and rely on `category`.
        var name: String
        var severityRaw: String
        var note: String

        /// Reference to a SymptomCategory. Nil only for legacy rows that haven't been
        /// migrated yet (should not happen in practice — the V2 migration always assigns
        /// a category, even if it has to create one). Kept optional because SwiftData
        /// likes optional relationships and CloudKit will too.
        var category: SchemaV2.SymptomCategory?

        init(name: String, severity: SeverityLevel, note: String = "", category: SchemaV2.SymptomCategory? = nil) {
            self.name = name
            self.severityRaw = severity.rawValue
            self.note = note
            self.category = category
        }

        var severity: SeverityLevel {
            get { SeverityLevel(rawValue: severityRaw) ?? .medium }
            set { severityRaw = newValue.rawValue }
        }

        /// Display name preferring the linked category, falling back to the legacy
        /// stored name. Always returns something usable.
        var displayName: String {
            category?.displayName ?? name
        }

        /// Stable analytics key. Prefers the category slug; falls back to a normalized
        /// version of the legacy name so historic rows still aggregate predictably.
        var analyticsKey: String {
            if let slug = category?.slug { return slug }
            return SymptomCategorySlug.normalize(name)
        }
    }

    /// First-class category for symptoms. Built-ins are seeded once on V2 migration and
    /// can be renamed but not archived. User-created categories can be archived (soft
    /// delete). Slug is the stable analytics key and is unique.
    @Model
    final class SymptomCategory {
        @Attribute(.unique) var slug: String
        var displayName: String
        var symbolName: String
        var isBuiltIn: Bool
        var sortOrder: Int
        var isArchived: Bool
        var createdAt: Date

        init(
            slug: String,
            displayName: String,
            symbolName: String,
            isBuiltIn: Bool,
            sortOrder: Int,
            isArchived: Bool = false,
            createdAt: Date = .now
        ) {
            self.slug = slug
            self.displayName = displayName
            self.symbolName = symbolName
            self.isBuiltIn = isBuiltIn
            self.sortOrder = sortOrder
            self.isArchived = isArchived
            self.createdAt = createdAt
        }
    }
}

// MARK: - Top-level aliases (current schema = V2)
//
// All UI / business logic refers to these unqualified names. When a future
// SchemaV3 lands, we update these aliases and the call sites stay untouched.

typealias DailyEntry = SchemaV2.DailyEntry
typealias SymptomEntry = SchemaV2.SymptomEntry
typealias SymptomCategory = SchemaV2.SymptomCategory

// MARK: - Slug helpers

enum SymptomCategorySlug {
    /// Normalize an arbitrary string into a slug-ish stable key. Lowercases,
    /// trims, replaces whitespace with dashes, strips diacritics. Used for both
    /// the built-in slugs and any future fallback keys.
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let folded = trimmed.folding(options: .diacriticInsensitive, locale: .current)
        var output = ""
        var lastWasDash = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                output.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash, !output.isEmpty {
                output.append("-")
                lastWasDash = true
            }
        }
        if output.hasSuffix("-") { output.removeLast() }
        return output.isEmpty ? "unnamed" : output
    }
}

// MARK: - Existing enums (unchanged)

enum FoodCategory: String, CaseIterable, Identifiable {
    case healthy
    case regular
    case fastFood = "fast_food"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .healthy: return "Healthy"
        case .regular: return "Regular"
        case .fastFood: return "Fast Food"
        }
    }
}

enum SeverityLevel: String, CaseIterable, Identifiable {
    case light
    case medium
    case strong

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

enum IntakeLevel: String, CaseIterable, Identifiable {
    case little
    case medium
    case much

    var id: String { rawValue }

    var title: String {
        switch self {
        case .little: return "Wenig"
        case .medium: return "Mittel"
        case .much: return "Viel"
        }
    }

    var fillFraction: Double {
        switch self {
        case .little: return 0.3
        case .medium: return 0.6
        case .much: return 0.95
        }
    }
}

enum OptionalIntakeLevel: String, CaseIterable, Identifiable {
    case none
    case little
    case medium
    case much

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Nein"
        case .little: return "Wenig"
        case .medium: return "Mittel"
        case .much: return "Viel"
        }
    }
}

enum CyclePhase: String, CaseIterable, Identifiable {
    case notSet
    case menstruation
    case follicular
    case ovulation
    case luteal
    case uncertain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notSet: return "Nicht gesetzt"
        case .menstruation: return "Menstruation"
        case .follicular: return "Follikelphase"
        case .ovulation: return "Ovulation"
        case .luteal: return "Lutealphase"
        case .uncertain: return "Unsicher"
        }
    }
}

enum UserSex: String, CaseIterable, Identifiable {
    case male
    case female
    case undisclosed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: return "Männlich"
        case .female: return "Weiblich"
        case .undisclosed: return "Keine Angabe"
        }
    }
}

/// Built-in symptom presets. After V2 migration these become rows in
/// `SymptomCategory` with `isBuiltIn = true`. The enum stays around as the
/// canonical source of truth for the built-in seed data.
enum SymptomPreset: String, CaseIterable, Identifiable {
    case headache
    case bellyAche
    case nausea
    case fatigue
    case soreThroat
    case backPain

    var id: String { rawValue }

    /// Stable slug. Must match the slug produced by SymptomCategorySlug.normalize
    /// for the canonical German title — that's how the V2 migration de-duplicates.
    var slug: String {
        switch self {
        case .headache: return "kopfschmerzen"
        case .bellyAche: return "bauchschmerzen"
        case .nausea: return "ubelkeit"
        case .fatigue: return "mudigkeit"
        case .soreThroat: return "halsschmerzen"
        case .backPain: return "ruckenschmerzen"
        }
    }

    var title: String {
        switch self {
        case .headache: return "Kopfschmerzen"
        case .bellyAche: return "Bauchschmerzen"
        case .nausea: return "Übelkeit"
        case .fatigue: return "Müdigkeit"
        case .soreThroat: return "Halsschmerzen"
        case .backPain: return "Rückenschmerzen"
        }
    }

    var symbol: String {
        switch self {
        case .headache: return "brain.head.profile"
        case .bellyAche: return "figure.seated.side"
        case .nausea: return "waveform.path.ecg"
        case .fatigue: return "moon.zzz.fill"
        case .soreThroat: return "bandage.fill"
        case .backPain: return "figure.walk"
        }
    }

    static var orderedSeed: [SymptomPreset] {
        [.headache, .bellyAche, .nausea, .fatigue, .soreThroat, .backPain]
    }
}

enum Achievement: String, CaseIterable, Identifiable {
    case firstEntry
    case streak3
    case streak7
    case hydrationWin
    case reflectionPro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstEntry: return "Erster Check-in"
        case .streak3: return "3 Tage am Stück"
        case .streak7: return "7 Tage am Stück"
        case .hydrationWin: return "Wasser-Woche"
        case .reflectionPro: return "Reflektiert"
        }
    }

    var symbol: String {
        switch self {
        case .firstEntry: return "sparkles"
        case .streak3: return "flame.fill"
        case .streak7: return "bolt.heart.fill"
        case .hydrationWin: return "drop.fill"
        case .reflectionPro: return "book.fill"
        }
    }
}
