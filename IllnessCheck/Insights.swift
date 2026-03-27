import Foundation

struct ComparisonInsight: Identifiable {
    let id = UUID()
    let title: String
    let leftLabel: String
    let leftValue: Double
    let rightLabel: String
    let rightValue: Double
}

struct SymptomStat: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let averageSeverity: Double
}

struct InsightMessage: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

struct AppInsights {
    let streakDays: Int
    let averageMood: Double
    let hydrationScore: Double
    let symptomFreeDays: Int
    let averageSymptomsPerDay: Double
    let goodDayShare: Double
    let earnedAchievements: [Achievement]
    let topSymptoms: [SymptomStat]
    let comparisons: [ComparisonInsight]
    let messages: [InsightMessage]
}

enum InsightsBuilder {
    static func build(from entries: [DailyEntry]) -> AppInsights {
        let sorted = entries.sorted { $0.date < $1.date }
        let streak = calculateStreak(from: sorted)
        let mood = sorted.isEmpty ? 0 : Double(sorted.map(\.moodScore).reduce(0, +)) / Double(sorted.count)
        let hydrationValues = sorted.map { $0.overallHydration.fillFraction }
        let hydration = hydrationValues.isEmpty ? 0 : hydrationValues.reduce(0, +) / Double(hydrationValues.count)
        let symptomFreeDays = sorted.filter { $0.symptoms.isEmpty }.count
        let averageSymptoms = sorted.isEmpty ? 0 : Double(sorted.reduce(0) { $0 + $1.symptoms.count }) / Double(sorted.count)
        let goodDayShare = sorted.isEmpty ? 0 : Double(sorted.filter { $0.moodScore >= 4 }.count) / Double(sorted.count)

        var achievements: [Achievement] = []
        if !entries.isEmpty { achievements.append(.firstEntry) }
        if streak >= 3 { achievements.append(.streak3) }
        if streak >= 7 { achievements.append(.streak7) }
        if entries.filter({ $0.waterLevel == .much || $0.waterLevel == .medium }).count >= 5 { achievements.append(.hydrationWin) }
        if entries.filter({ !$0.generalNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).count >= 5 { achievements.append(.reflectionPro) }

        let topSymptoms = buildTopSymptoms(from: sorted)
        let comparisons = buildComparisons(from: sorted)
        let messages = buildMessages(from: sorted, topSymptoms: topSymptoms, comparisons: comparisons, mood: mood, symptomFreeDays: symptomFreeDays)

        return AppInsights(
            streakDays: streak,
            averageMood: mood,
            hydrationScore: hydration,
            symptomFreeDays: symptomFreeDays,
            averageSymptomsPerDay: averageSymptoms,
            goodDayShare: goodDayShare,
            earnedAchievements: achievements,
            topSymptoms: topSymptoms,
            comparisons: comparisons,
            messages: messages
        )
    }

    private static func buildTopSymptoms(from entries: [DailyEntry]) -> [SymptomStat] {
        let grouped = Dictionary(grouping: entries.flatMap(\.symptoms)) { $0.name }

        return grouped.map { name, symptoms in
            let severityAverage = Double(symptoms.map { severityScore(for: $0.severity) }.reduce(0, +)) / Double(symptoms.count)
            return SymptomStat(name: name, count: symptoms.count, averageSeverity: severityAverage)
        }
        .sorted {
            if $0.count == $1.count {
                return $0.averageSeverity > $1.averageSeverity
            }
            return $0.count > $1.count
        }
        .prefix(5)
        .map { $0 }
    }

    private static func buildComparisons(from entries: [DailyEntry]) -> [ComparisonInsight] {
        var comparisons: [ComparisonInsight] = []

        if let coffee = compare(entries: entries, left: { $0.hadCoffee }, right: { !$0.hadCoffee }) {
            comparisons.append(ComparisonInsight(title: "Kaffee vs. kein Kaffee", leftLabel: "Mit Kaffee", leftValue: coffee.0, rightLabel: "Ohne Kaffee", rightValue: coffee.1))
        }

        if let water = compare(entries: entries, left: { $0.waterLevel == .much || $0.waterLevel == .medium }, right: { $0.waterLevel == .little || $0.waterLevel == .none }) {
            comparisons.append(ComparisonInsight(title: "Mehr Wasser vs. weniger Wasser", leftLabel: "Mehr Wasser", leftValue: water.0, rightLabel: "Wenig Wasser", rightValue: water.1))
        }

        if let alcohol = compare(entries: entries, left: { $0.alcoholLevel != .none }, right: { $0.alcoholLevel == .none }) {
            comparisons.append(ComparisonInsight(title: "Alkohol vs. kein Alkohol", leftLabel: "Mit Alkohol", leftValue: alcohol.0, rightLabel: "Ohne Alkohol", rightValue: alcohol.1))
        }

        if let healthy = compare(entries: entries, left: { $0.foodCategory == .healthy }, right: { $0.foodCategory != .healthy }) {
            comparisons.append(ComparisonInsight(title: "Healthy vs. andere Tage", leftLabel: "Healthy", leftValue: healthy.0, rightLabel: "Andere", rightValue: healthy.1))
        }

        return comparisons
    }

    private static func buildMessages(from entries: [DailyEntry], topSymptoms: [SymptomStat], comparisons: [ComparisonInsight], mood: Double, symptomFreeDays: Int) -> [InsightMessage] {
        var messages: [InsightMessage] = []

        if !entries.isEmpty {
            messages.append(InsightMessage(title: "Tagesgefühl", body: "Dein durchschnittliches Tagesgefühl liegt aktuell bei \(String(format: "%.1f", mood)) von 5."))
        }

        if let topSymptom = topSymptoms.first {
            messages.append(InsightMessage(title: "Häufigstes Symptom", body: "\(topSymptom.name) wurde bisher \(topSymptom.count)x erfasst."))
        }

        if symptomFreeDays > 0 {
            messages.append(InsightMessage(title: "Symptomfreie Tage", body: "Du hattest bereits \(symptomFreeDays) Tage ohne Beschwerden."))
        }

        if let strongestComparison = comparisons.max(by: { abs($0.leftValue - $0.rightValue) < abs($1.leftValue - $1.rightValue) }) {
            let delta = strongestComparison.leftValue - strongestComparison.rightValue
            let direction = delta >= 0 ? "besser" : "schlechter"
            messages.append(InsightMessage(title: strongestComparison.title, body: "Dein Mood Score ist bei \(strongestComparison.leftLabel.lowercased()) im Schnitt um \(String(format: "%.1f", abs(delta))) Punkte \(direction)."))
        }

        return Array(messages.prefix(4))
    }

    private static func compare(entries: [DailyEntry], left: (DailyEntry) -> Bool, right: (DailyEntry) -> Bool) -> (Double, Double)? {
        let leftEntries = entries.filter(left)
        let rightEntries = entries.filter(right)
        guard !leftEntries.isEmpty, !rightEntries.isEmpty else { return nil }

        let leftAverage = Double(leftEntries.map(\.moodScore).reduce(0, +)) / Double(leftEntries.count)
        let rightAverage = Double(rightEntries.map(\.moodScore).reduce(0, +)) / Double(rightEntries.count)
        return (leftAverage, rightAverage)
    }

    private static func severityScore(for level: SeverityLevel) -> Double {
        switch level {
        case .light: return 1
        case .medium: return 2
        case .strong: return 3
        }
    }

    private static func calculateStreak(from entries: [DailyEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        let calendar = Calendar.current
        let normalizedDates = Array(Set(entries.map { calendar.startOfDay(for: $0.date) })).sorted(by: >)

        var streak = 0
        var expectedDate = calendar.startOfDay(for: .now)

        for date in normalizedDates {
            if calendar.isDate(date, inSameDayAs: expectedDate) {
                streak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            } else if date < expectedDate {
                break
            }
        }

        return streak
    }
}
