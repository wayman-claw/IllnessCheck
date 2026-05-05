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
    let slug: String
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
    let correlations: [CorrelationInsight]
    let messages: [InsightMessage]
}

enum InsightsBuilder {
    static func build(from entries: [DailyEntry], userSex: UserSex = .undisclosed) -> AppInsights {
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
        if streak >= 14 { achievements.append(.streak14) }
        if streak >= 30 { achievements.append(.streak30) }
        if entries.filter({ $0.waterLevel == .much || $0.waterLevel == .medium }).count >= 5 { achievements.append(.hydrationWin) }
        if entries.filter({ !$0.generalNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).count >= 5 { achievements.append(.reflectionPro) }
        if hasPerfectWeek(in: sorted) { achievements.append(.perfectWeek) }
        if hasSymptomFree7(in: sorted) { achievements.append(.symptomFree7) }
        if hasMonthExplorer(in: sorted) { achievements.append(.monthExplorer) }

        let topSymptoms = buildTopSymptoms(from: sorted)
        let comparisons = buildComparisons(from: sorted)
        let correlations = CorrelationEngine.insights(entries: sorted, userSex: userSex)
        if !correlations.isEmpty { achievements.append(.firstCorrelation) }
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
            correlations: correlations,
            messages: messages
        )
    }

    /// 7 consecutive days where moodScore >= 4. We just need ANY such window
    /// in the user's history; we walk all sorted entries and check 7-day windows.
    private static func hasPerfectWeek(in sortedEntries: [DailyEntry]) -> Bool {
        guard sortedEntries.count >= 7 else { return false }
        let calendar = Calendar.current
        // Group by day to dedupe; keep highest mood for that day.
        var moodByDay: [Date: Int] = [:]
        for entry in sortedEntries {
            let day = calendar.startOfDay(for: entry.date)
            moodByDay[day] = max(moodByDay[day] ?? 0, entry.moodScore)
        }
        let sortedDays = moodByDay.keys.sorted()
        var streak = 0
        var previous: Date?
        for day in sortedDays {
            if let prev = previous,
               let next = calendar.date(byAdding: .day, value: 1, to: prev),
               !calendar.isDate(day, inSameDayAs: next) {
                streak = 0
            }
            if (moodByDay[day] ?? 0) >= 4 {
                streak += 1
                if streak >= 7 { return true }
            } else {
                streak = 0
            }
            previous = day
        }
        return false
    }

    /// 7 consecutive days without any logged symptoms.
    private static func hasSymptomFree7(in sortedEntries: [DailyEntry]) -> Bool {
        guard sortedEntries.count >= 7 else { return false }
        let calendar = Calendar.current
        var symptomFreeByDay: [Date: Bool] = [:]
        for entry in sortedEntries {
            let day = calendar.startOfDay(for: entry.date)
            // If ANY entry that day has symptoms, mark the day as not symptom-free.
            if entry.symptoms.isEmpty {
                if symptomFreeByDay[day] == nil { symptomFreeByDay[day] = true }
            } else {
                symptomFreeByDay[day] = false
            }
        }
        let sortedDays = symptomFreeByDay.keys.sorted()
        var streak = 0
        var previous: Date?
        for day in sortedDays {
            if let prev = previous,
               let next = calendar.date(byAdding: .day, value: 1, to: prev),
               !calendar.isDate(day, inSameDayAs: next) {
                streak = 0
            }
            if symptomFreeByDay[day] == true {
                streak += 1
                if streak >= 7 { return true }
            } else {
                streak = 0
            }
            previous = day
        }
        return false
    }

    /// All days of any single calendar month covered by entries.
    private static func hasMonthExplorer(in sortedEntries: [DailyEntry]) -> Bool {
        guard !sortedEntries.isEmpty else { return false }
        let calendar = Calendar.current
        var daysByMonth: [String: Set<Int>] = [:]
        for entry in sortedEntries {
            let comps = calendar.dateComponents([.year, .month, .day], from: entry.date)
            guard let year = comps.year, let month = comps.month, let day = comps.day else { continue }
            let key = "\(year)-\(month)"
            daysByMonth[key, default: []].insert(day)
        }
        for (key, days) in daysByMonth {
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let year = Int(parts[0]),
                  let month = Int(parts[1]),
                  let monthDate = calendar.date(from: DateComponents(year: year, month: month)),
                  let range = calendar.range(of: .day, in: .month, for: monthDate)
            else { continue }
            if days.count >= range.count { return true }
        }
        return false
    }

    private static func buildTopSymptoms(from entries: [DailyEntry]) -> [SymptomStat] {
        // Group by stable analytics key (category slug, falling back to a normalized
        // legacy name). The display name comes from the linked category when present.
        let allSymptoms = entries.flatMap(\.symptoms)
        let grouped = Dictionary(grouping: allSymptoms) { $0.analyticsKey }

        return grouped.map { slug, symptoms in
            let severityAverage = Double(symptoms.map { severityScore(for: $0.severity) }.reduce(0, +)) / Double(symptoms.count)
            let displayName = symptoms.first?.displayName ?? slug
            return SymptomStat(slug: slug, name: displayName, count: symptoms.count, averageSeverity: severityAverage)
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
