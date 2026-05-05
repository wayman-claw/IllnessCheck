//
//  Correlation.swift
//  IllnessCheck / DayTrace
//
//  Pure correlation engine: given a set of DailyEntries, produces a ranked list
//  of "trigger ⇄ symptom" insights ("on coffee days, headaches in 75%; on non-
//  coffee days in 20%"). UI-free, deterministic, easy to unit-test.
//
//  Design notes:
//  - Trigger and Symptom are decoupled: triggers come from a closed enum
//    (CorrelationTrigger) so we control naming/ordering; symptoms come from
//    user data (categories), so they're identified by SymptomCategory slug.
//  - We require both groups (with-trigger and without-trigger) to have at
//    least `minSamplePerGroup` days. Anything below that is silently dropped
//    — "garbage in, garbage out" is worse than "not enough data yet".
//  - Strength is absolute rate difference. We expose a coarse classification
//    (weak/moderate/strong) so the UI can decide visuals without re-deriving
//    thresholds.
//

import Foundation

// MARK: - Trigger taxonomy

/// Closed set of supported correlation triggers. Each trigger turns a
/// DailyEntry into a Bool ("did this day match the trigger or not?").
/// Adding a new trigger here is the only place to touch when we want to
/// correlate on a new dimension.
enum CorrelationTrigger: String, CaseIterable, Identifiable {
    case coffee
    case softdrinks
    case alcoholAny
    case lowWater
    case fastFood
    case healthyFood
    case cycleMenstruation
    case cycleFollicular
    case cycleOvulation
    case cycleLuteal

    var id: String { rawValue }

    /// Human-readable label for the "this trigger was present" side.
    var presentLabel: String {
        switch self {
        case .coffee: return "Mit Kaffee"
        case .softdrinks: return "Mit Softdrinks"
        case .alcoholAny: return "Mit Alkohol"
        case .lowWater: return "Wenig Wasser"
        case .fastFood: return "Fast Food"
        case .healthyFood: return "Gesundes Essen"
        case .cycleMenstruation: return "Menstruation"
        case .cycleFollicular: return "Follikelphase"
        case .cycleOvulation: return "Ovulation"
        case .cycleLuteal: return "Lutealphase"
        }
    }

    /// Human-readable label for the "this trigger was absent" side.
    var absentLabel: String {
        switch self {
        case .coffee: return "Ohne Kaffee"
        case .softdrinks: return "Ohne Softdrinks"
        case .alcoholAny: return "Ohne Alkohol"
        case .lowWater: return "Genug Wasser"
        case .fastFood: return "Anderes Essen"
        case .healthyFood: return "Anderes Essen"
        case .cycleMenstruation, .cycleFollicular, .cycleOvulation, .cycleLuteal:
            return "Andere Phase"
        }
    }

    /// Whether this trigger is applicable for the given user. Cycle triggers
    /// are gated by sex; the rest are universal.
    func isApplicable(for sex: UserSex) -> Bool {
        switch self {
        case .cycleMenstruation, .cycleFollicular, .cycleOvulation, .cycleLuteal:
            return sex == .female
        default:
            return true
        }
    }

    /// Evaluate the trigger against a single DailyEntry.
    func matches(_ entry: DailyEntry) -> Bool {
        switch self {
        case .coffee: return entry.hadCoffee
        case .softdrinks: return entry.hadSoftdrinks
        case .alcoholAny: return entry.alcoholLevel != .none
        case .lowWater: return entry.waterLevel == .little
        case .fastFood: return entry.foodCategory == .fastFood
        case .healthyFood: return entry.foodCategory == .healthy
        case .cycleMenstruation: return entry.cyclePhase == .menstruation
        case .cycleFollicular: return entry.cyclePhase == .follicular
        case .cycleOvulation: return entry.cyclePhase == .ovulation
        case .cycleLuteal: return entry.cyclePhase == .luteal
        }
    }
}

// MARK: - Result types

/// One trigger ⇄ symptom-category insight.
struct CorrelationInsight: Identifiable, Equatable {
    let id: String                    // stable: "<trigger>|<categorySlug>"
    let trigger: CorrelationTrigger
    let categorySlug: String
    let categoryDisplayName: String
    /// Days that matched the trigger.
    let withTriggerTotal: Int
    /// Of those, how many also had the symptom.
    let withTriggerSymptomDays: Int
    /// Days that did NOT match the trigger.
    let withoutTriggerTotal: Int
    /// Of those, how many had the symptom.
    let withoutTriggerSymptomDays: Int

    /// Symptom rate when the trigger was present, in [0, 1].
    var withTriggerRate: Double {
        guard withTriggerTotal > 0 else { return 0 }
        return Double(withTriggerSymptomDays) / Double(withTriggerTotal)
    }

    /// Symptom rate when the trigger was absent, in [0, 1].
    var withoutTriggerRate: Double {
        guard withoutTriggerTotal > 0 else { return 0 }
        return Double(withoutTriggerSymptomDays) / Double(withoutTriggerTotal)
    }

    /// Absolute difference (signed: positive ⇒ symptom MORE likely with trigger).
    var rateDelta: Double { withTriggerRate - withoutTriggerRate }

    /// Strength bucket based on |rateDelta|. Coarse on purpose — we don't
    /// claim statistical significance, just "worth showing the user".
    var strength: Strength {
        let d = abs(rateDelta)
        switch d {
        case ..<0.15: return .weak
        case ..<0.30: return .moderate
        default: return .strong
        }
    }

    enum Strength: String { case weak, moderate, strong }
}

// MARK: - Engine

enum CorrelationEngine {
    /// Default minimum days required per group (with-trigger and without-trigger).
    /// Below this, an insight is suppressed. Tunable per call for tests/UI overrides.
    static let defaultMinSamplePerGroup = 7

    /// Build all insights for the given entries. Sorted by strength descending,
    /// then by absolute rateDelta. Insights below `minRateDelta` are dropped to
    /// avoid noise (coffee → headaches at 41% vs 39% is not interesting).
    ///
    /// - Parameters:
    ///   - entries: All DailyEntries to consider. Pass the full history; the
    ///     engine doesn't filter by date itself.
    ///   - userSex: Used to gate cycle-related triggers.
    ///   - minSamplePerGroup: Minimum days in each group. Default 7.
    ///   - minRateDelta: Minimum |rate difference| to surface (0…1). Default 0.10.
    static func insights(
        entries: [DailyEntry],
        userSex: UserSex = .undisclosed,
        minSamplePerGroup: Int = defaultMinSamplePerGroup,
        minRateDelta: Double = 0.10
    ) -> [CorrelationInsight] {
        // Pre-compute which categories appear at all, with display name.
        // We key by slug because that's the stable analytics identity (same
        // slug = same conceptual symptom even if the category was renamed).
        var categoryNameBySlug: [String: String] = [:]
        for entry in entries {
            for symptom in entry.symptoms {
                let slug = symptom.analyticsKey
                if categoryNameBySlug[slug] == nil {
                    categoryNameBySlug[slug] = symptom.displayName
                }
            }
        }
        guard !categoryNameBySlug.isEmpty else { return [] }

        // Pre-compute, per entry, the set of category slugs present that day.
        // A symptom can only count once per day even if logged multiple times.
        let slugsByEntry: [(entry: DailyEntry, slugs: Set<String>)] = entries.map { e in
            var slugs = Set<String>()
            for s in e.symptoms { slugs.insert(s.analyticsKey) }
            return (e, slugs)
        }

        var results: [CorrelationInsight] = []

        for trigger in CorrelationTrigger.allCases where trigger.isApplicable(for: userSex) {
            // Partition days by whether trigger matched.
            var withDays: [Set<String>] = []
            var withoutDays: [Set<String>] = []
            for (entry, slugs) in slugsByEntry {
                if trigger.matches(entry) {
                    withDays.append(slugs)
                } else {
                    withoutDays.append(slugs)
                }
            }

            guard withDays.count >= minSamplePerGroup,
                  withoutDays.count >= minSamplePerGroup else { continue }

            for (slug, name) in categoryNameBySlug {
                let withSymptom = withDays.reduce(0) { $0 + ($1.contains(slug) ? 1 : 0) }
                let withoutSymptom = withoutDays.reduce(0) { $0 + ($1.contains(slug) ? 1 : 0) }

                let insight = CorrelationInsight(
                    id: "\(trigger.rawValue)|\(slug)",
                    trigger: trigger,
                    categorySlug: slug,
                    categoryDisplayName: name,
                    withTriggerTotal: withDays.count,
                    withTriggerSymptomDays: withSymptom,
                    withoutTriggerTotal: withoutDays.count,
                    withoutTriggerSymptomDays: withoutSymptom
                )

                if abs(insight.rateDelta) >= minRateDelta {
                    results.append(insight)
                }
            }
        }

        // Sort: strongest first; break ties by larger sample size (more reliable).
        results.sort { lhs, rhs in
            if abs(lhs.rateDelta) != abs(rhs.rateDelta) {
                return abs(lhs.rateDelta) > abs(rhs.rateDelta)
            }
            return (lhs.withTriggerTotal + lhs.withoutTriggerTotal)
                 > (rhs.withTriggerTotal + rhs.withoutTriggerTotal)
        }

        return results
    }
}
