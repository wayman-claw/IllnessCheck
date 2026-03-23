import Foundation

struct ExportBundle: Codable {
    let exportedAt: Date
    let entries: [ExportDailyEntry]
}

struct ExportDailyEntry: Codable {
    let date: Date
    let foodCategory: String
    let foodNote: String
    let generalNote: String
    let overallHydration: String
    let hadCoffee: Bool
    let hadSoftdrinks: Bool
    let alcoholLevel: String
    let waterLevel: String
    let otherDrinksNote: String
    let symptoms: [ExportSymptom]
}

struct ExportSymptom: Codable {
    let name: String
    let severity: String
    let note: String
}

enum ExportFactory {
    static func makeBundle(from entries: [DailyEntry]) -> ExportBundle {
        ExportBundle(
            exportedAt: .now,
            entries: entries.map {
                ExportDailyEntry(
                    date: $0.date,
                    foodCategory: $0.foodCategory.rawValue,
                    foodNote: $0.foodNote,
                    generalNote: $0.generalNote,
                    overallHydration: $0.overallHydration.rawValue,
                    hadCoffee: $0.hadCoffee,
                    hadSoftdrinks: $0.hadSoftdrinks,
                    alcoholLevel: $0.alcoholLevel.rawValue,
                    waterLevel: $0.waterLevel.rawValue,
                    otherDrinksNote: $0.otherDrinksNote,
                    symptoms: $0.symptoms.map {
                        ExportSymptom(name: $0.name, severity: $0.severity.rawValue, note: $0.note)
                    }
                )
            }
        )
    }

    static func makeJSON(from entries: [DailyEntry]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let bundle = makeBundle(from: entries)

        guard let data = try? encoder.encode(bundle),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return string
    }
}
