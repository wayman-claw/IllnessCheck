import Foundation
import SwiftData

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
    @Relationship(deleteRule: .cascade) var symptoms: [SymptomEntry]

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
        symptoms: [SymptomEntry] = []
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
    var name: String
    var severityRaw: String
    var note: String

    init(name: String, severity: SeverityLevel, note: String = "") {
        self.name = name
        self.severityRaw = severity.rawValue
        self.note = note
    }

    var severity: SeverityLevel {
        get { SeverityLevel(rawValue: severityRaw) ?? .medium }
        set { severityRaw = newValue.rawValue }
    }
}

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

enum SymptomPreset: String, CaseIterable, Identifiable {
    case headache
    case bellyAche
    case nausea
    case fatigue
    case soreThroat
    case backPain
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .headache: return "Kopfschmerzen"
        case .bellyAche: return "Bauchschmerzen"
        case .nausea: return "Übelkeit"
        case .fatigue: return "Müdigkeit"
        case .soreThroat: return "Halsschmerzen"
        case .backPain: return "Rückenschmerzen"
        case .custom: return "Sonstiges"
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
        case .custom: return "cross.case.fill"
        }
    }

    static func preset(for symptomName: String) -> SymptomPreset? {
        let normalized = symptomName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCases.first { $0.title.lowercased() == normalized }
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
