//
//  CorrelationTests.swift
//  DayTraceTests
//
//  Pure-engine tests for CorrelationEngine. No SwiftData container is created
//  here — `@Model` classes can be instantiated transient as long as we never
//  persist or fetch. The engine reads scalar fields + the `symptoms` array
//  only, so transient instances are sufficient.
//

import Testing
import Foundation
@testable import DayTrace

// MARK: - Helpers

private func makeEntry(
    date: Date = .now,
    coffee: Bool = false,
    softdrinks: Bool = false,
    alcohol: OptionalIntakeLevel = .none,
    water: OptionalIntakeLevel = .medium,
    food: FoodCategory = .regular,
    cycle: CyclePhase = .notSet,
    symptomSlugs: [String] = []
) -> DailyEntry {
    let symptoms: [SymptomEntry] = symptomSlugs.map { slug in
        let cat = SymptomCategory(
            slug: slug,
            displayName: slug.capitalized,
            symbolName: "circle",
            isBuiltIn: false,
            sortOrder: 0
        )
        return SymptomEntry(name: slug, severity: .medium, note: "", category: cat)
    }
    return DailyEntry(
        date: date,
        foodCategory: food,
        hadCoffee: coffee,
        hadSoftdrinks: softdrinks,
        alcoholLevel: alcohol,
        waterLevel: water,
        cyclePhase: cycle,
        symptoms: symptoms
    )
}

// MARK: - Tests

struct CorrelationEngineTests {

    @Test("Empty input yields no insights")
    func empty() {
        let result = CorrelationEngine.insights(entries: [])
        #expect(result.isEmpty)
    }

    @Test("Insufficient sample size suppresses insight")
    func tooFewSamples() {
        // Only 5 with, 5 without — below default minSamplePerGroup = 7.
        var entries: [DailyEntry] = []
        for i in 0..<10 {
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval(i * 86_400)),
                coffee: i < 5,
                symptomSlugs: i < 5 ? ["headache"] : []
            ))
        }
        let result = CorrelationEngine.insights(entries: entries)
        #expect(result.isEmpty)
    }

    @Test("Strong positive correlation surfaces")
    func strongPositive() {
        // 20 days: first 10 have coffee + headache, next 10 have neither.
        // Expected: coffee→headache rate 100% vs 0%, delta 1.0, strong.
        var entries: [DailyEntry] = []
        for i in 0..<20 {
            let hasCoffee = i < 10
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval(i * 86_400)),
                coffee: hasCoffee,
                symptomSlugs: hasCoffee ? ["headache"] : []
            ))
        }
        let result = CorrelationEngine.insights(entries: entries)
        let coffeeHeadache = result.first { $0.trigger == .coffee && $0.categorySlug == "headache" }
        #expect(coffeeHeadache != nil)
        #expect(coffeeHeadache?.withTriggerRate == 1.0)
        #expect(coffeeHeadache?.withoutTriggerRate == 0.0)
        #expect(coffeeHeadache?.strength == .strong)
    }

    @Test("Weak signal below minRateDelta is dropped")
    func belowThreshold() {
        // 10 with coffee: 5 headache (50%). 10 without: 4 headache (40%). Delta 0.10
        // — sits exactly on the default threshold, so should be kept (>=).
        // Use 4 vs 5 instead: 50% vs 40% = 0.10.
        var entries: [DailyEntry] = []
        for i in 0..<10 {
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval(i * 86_400)),
                coffee: true,
                symptomSlugs: i < 5 ? ["headache"] : []
            ))
        }
        for i in 0..<10 {
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval((i + 10) * 86_400)),
                coffee: false,
                symptomSlugs: i < 4 ? ["headache"] : []
            ))
        }
        let result = CorrelationEngine.insights(entries: entries, minRateDelta: 0.15)
        // Delta of 0.10 should NOT make it through a 0.15 threshold.
        #expect(result.first { $0.trigger == .coffee && $0.categorySlug == "headache" } == nil)
    }

    @Test("Negative correlation has negative delta")
    func negativeCorrelation() {
        // Healthy food → fewer headaches.
        var entries: [DailyEntry] = []
        for i in 0..<10 {
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval(i * 86_400)),
                food: .healthy,
                symptomSlugs: i < 1 ? ["headache"] : []  // 10% with healthy
            ))
        }
        for i in 0..<10 {
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval((i + 10) * 86_400)),
                food: .regular,
                symptomSlugs: i < 8 ? ["headache"] : []  // 80% without healthy
            ))
        }
        let result = CorrelationEngine.insights(entries: entries)
        let healthy = result.first { $0.trigger == .healthyFood && $0.categorySlug == "headache" }
        #expect(healthy != nil)
        #expect((healthy?.rateDelta ?? 0) < 0)
        #expect(healthy?.strength == .strong)
    }

    @Test("Cycle triggers are gated by user sex")
    func cycleGatedByMaleSex() {
        // 20 days, half in luteal phase, all with headache → strong cycle signal
        // would surface for female users. For male, must be filtered out.
        var entries: [DailyEntry] = []
        for i in 0..<20 {
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval(i * 86_400)),
                cycle: i < 10 ? .luteal : .notSet,
                symptomSlugs: i < 10 ? ["headache"] : []
            ))
        }
        let male = CorrelationEngine.insights(entries: entries, userSex: .male)
        #expect(male.first { $0.trigger == .cycleLuteal } == nil)

        let female = CorrelationEngine.insights(entries: entries, userSex: .female)
        #expect(female.first { $0.trigger == .cycleLuteal } != nil)
    }

    @Test("Same-day duplicate symptom counted once")
    func duplicateSymptomDeduped() {
        // 7 coffee days, each logging headache TWICE. Should still register
        // as 7/7, not 14.
        var entries: [DailyEntry] = []
        for i in 0..<7 {
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval(i * 86_400)),
                coffee: true,
                symptomSlugs: ["headache", "headache"]
            ))
        }
        for i in 0..<7 {
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval((i + 7) * 86_400)),
                coffee: false,
                symptomSlugs: []
            ))
        }
        let result = CorrelationEngine.insights(entries: entries)
        let coffeeHeadache = result.first { $0.trigger == .coffee && $0.categorySlug == "headache" }
        #expect(coffeeHeadache?.withTriggerSymptomDays == 7)
        #expect(coffeeHeadache?.withTriggerTotal == 7)
    }

    @Test("Results sorted strongest first")
    func sortingByStrength() {
        // Build two correlations of clearly different strength.
        // Strong: coffee → headache (90% vs 10%)
        // Weak  : softdrinks → headache (30% vs 20%)
        var entries: [DailyEntry] = []
        for i in 0..<10 {
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval(i * 86_400)),
                coffee: true, softdrinks: false,
                symptomSlugs: i < 9 ? ["headache"] : []
            ))
        }
        for i in 0..<10 {
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval((i + 10) * 86_400)),
                coffee: false, softdrinks: true,
                symptomSlugs: i < 3 ? ["headache"] : []
            ))
        }
        for i in 0..<10 {
            entries.append(makeEntry(
                date: Date(timeIntervalSinceReferenceDate: TimeInterval((i + 20) * 86_400)),
                coffee: false, softdrinks: false,
                symptomSlugs: i < 2 ? ["headache"] : []
            ))
        }
        let result = CorrelationEngine.insights(entries: entries)
        // Strongest absolute delta should come first.
        guard let first = result.first else {
            Issue.record("expected at least one result"); return
        }
        for other in result.dropFirst() {
            #expect(abs(first.rateDelta) >= abs(other.rateDelta))
        }
    }

    @Test("Insight strength buckets")
    func strengthBuckets() {
        let weak = CorrelationInsight(
            id: "x", trigger: .coffee, categorySlug: "h", categoryDisplayName: "H",
            withTriggerTotal: 10, withTriggerSymptomDays: 5,
            withoutTriggerTotal: 10, withoutTriggerSymptomDays: 4
        ) // delta 0.10
        #expect(weak.strength == .weak)

        let moderate = CorrelationInsight(
            id: "x", trigger: .coffee, categorySlug: "h", categoryDisplayName: "H",
            withTriggerTotal: 10, withTriggerSymptomDays: 6,
            withoutTriggerTotal: 10, withoutTriggerSymptomDays: 4
        ) // delta 0.20
        #expect(moderate.strength == .moderate)

        let strong = CorrelationInsight(
            id: "x", trigger: .coffee, categorySlug: "h", categoryDisplayName: "H",
            withTriggerTotal: 10, withTriggerSymptomDays: 9,
            withoutTriggerTotal: 10, withoutTriggerSymptomDays: 1
        ) // delta 0.80
        #expect(strong.strength == .strong)
    }
}
