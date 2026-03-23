import Foundation

struct AppInsights {
    let streakDays: Int
    let averageMood: Double
    let hydrationScore: Double
    let earnedAchievements: [Achievement]
}

enum InsightsBuilder {
    static func build(from entries: [DailyEntry]) -> AppInsights {
        let sorted = entries.sorted { $0.date < $1.date }
        let streak = calculateStreak(from: sorted)
        let mood = sorted.isEmpty ? 0 : Double(sorted.map(\.moodScore).reduce(0, +)) / Double(sorted.count)
        let hydrationValues = sorted.map { $0.overallHydration.fillFraction }
        let hydration = hydrationValues.isEmpty ? 0 : hydrationValues.reduce(0, +) / Double(hydrationValues.count)

        var achievements: [Achievement] = []
        if !entries.isEmpty { achievements.append(.firstEntry) }
        if streak >= 3 { achievements.append(.streak3) }
        if streak >= 7 { achievements.append(.streak7) }
        if entries.filter({ $0.waterLevel == .much || $0.waterLevel == .medium }).count >= 5 { achievements.append(.hydrationWin) }
        if entries.filter({ !$0.generalNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).count >= 5 { achievements.append(.reflectionPro) }

        return AppInsights(streakDays: streak, averageMood: mood, hydrationScore: hydration, earnedAchievements: achievements)
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
