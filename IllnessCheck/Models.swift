import Foundation
import SwiftData

@Model
final class DailyEntry {
    var date: Date
    var foodCategoryRaw: String
    var foodNote: String
    var generalNote: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var symptoms: [SymptomEntry]
    @Relationship(deleteRule: .cascade) var drinks: [DrinkEntry]

    init(
        date: Date = .now,
        foodCategory: FoodCategory = .regular,
        foodNote: String = "",
        generalNote: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        symptoms: [SymptomEntry] = [],
        drinks: [DrinkEntry] = []
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.foodCategoryRaw = foodCategory.rawValue
        self.foodNote = foodNote
        self.generalNote = generalNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.symptoms = symptoms
        self.drinks = drinks
    }

    var foodCategory: FoodCategory {
        get { FoodCategory(rawValue: foodCategoryRaw) ?? .regular }
        set { foodCategoryRaw = newValue.rawValue }
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

@Model
final class DrinkEntry {
    var typeRaw: String
    var amount: Double
    var unitRaw: String

    init(type: DrinkType, amount: Double, unit: DrinkUnit = .milliliters) {
        self.typeRaw = type.rawValue
        self.amount = amount
        self.unitRaw = unit.rawValue
    }

    var type: DrinkType {
        get { DrinkType(rawValue: typeRaw) ?? .water }
        set { typeRaw = newValue.rawValue }
    }

    var unit: DrinkUnit {
        get { DrinkUnit(rawValue: unitRaw) ?? .milliliters }
        set { unitRaw = newValue.rawValue }
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

enum DrinkType: String, CaseIterable, Identifiable {
    case water
    case coffee
    case tea
    case alcohol
    case custom

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

enum DrinkUnit: String, CaseIterable, Identifiable {
    case milliliters = "ml"
    case cups
    case glasses

    var id: String { rawValue }
}
