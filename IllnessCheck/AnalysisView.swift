//
//  AnalysisView.swift
//  IllnessCheck / DayTrace
//
//  Dedicated analytics screen, pushed from the home view's toolbar. Houses
//  all interpretive content: correlations, mood + hydration trend, factor
//  comparisons, top symptoms, and natural-language insights. Keeps the
//  home view focused on "today + streak motivation".
//

import SwiftUI
import SwiftData
import Charts

struct AnalysisView: View {
    @Query(sort: [SortDescriptor(\DailyEntry.date, order: .reverse)]) private var entries: [DailyEntry]
    @EnvironmentObject private var appSettings: AppSettings

    private var insights: AppInsights {
        InsightsBuilder.build(from: entries, userSex: appSettings.userSex)
    }

    private var recentEntries: [DailyEntry] {
        Array(entries.sorted { $0.date < $1.date }.suffix(14))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Daten",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Sobald du ein paar Check-ins gemacht hast, erscheinen hier Muster, Trends und Auffälligkeiten.")
                    )
                    .padding(.top, 40)
                } else {
                    correlationSection
                    wellbeingSection
                    factorSection
                    symptomSection
                    insightSection
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analyse")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    private var correlationSection: some View {
        AnalysisSection(title: "Mögliche Zusammenhänge", systemImage: "sparkles") {
            if insights.correlations.isEmpty {
                EmptyInsightCard(text: "Sobald genug Tage erfasst sind (mindestens 7 mit und 7 ohne den jeweiligen Auslöser), siehst du hier Auffälligkeiten — z. B. „Kopfschmerzen treten an Kaffee-Tagen häufiger auf“.")
            } else {
                ForEach(insights.correlations.prefix(6)) { insight in
                    CorrelationCard(insight: insight)
                }
            }
        }
    }

    private var wellbeingSection: some View {
        AnalysisSection(title: "Wohlbefinden & Hydration", systemImage: "heart.text.square.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    WellbeingMetricCard(
                        title: "Stimmung Ø",
                        value: entries.isEmpty ? "–" : String(format: "%.1f / 5", insights.averageMood),
                        symbol: "face.smiling.fill",
                        tint: .pink
                    )
                    WellbeingMetricCard(
                        title: "Hydration Ø",
                        value: entries.isEmpty ? "–" : "\(Int((insights.hydrationScore * 100).rounded()))%",
                        symbol: "drop.fill",
                        tint: .blue
                    )
                }

                Chart(recentEntries) { entry in
                    LineMark(
                        x: .value("Tag", entry.date),
                        y: .value("Stimmung", entry.moodScore)
                    )
                    .foregroundStyle(.pink)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Tag", entry.date),
                        y: .value("Stimmung", entry.moodScore)
                    )
                    .foregroundStyle(.pink.opacity(0.12))
                    .interpolationMethod(.catmullRom)

                    BarMark(
                        x: .value("Tag", entry.date),
                        y: .value("Hydration", entry.overallHydration.fillFraction * 5)
                    )
                    .foregroundStyle(.blue.opacity(0.22))
                }
                .chartYScale(domain: 0...5)
                .frame(height: 200)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var factorSection: some View {
        AnalysisSection(title: "Einflussfaktoren", systemImage: "scalemass.fill") {
            if insights.comparisons.isEmpty {
                EmptyInsightCard(text: "Sobald genug Daten vorliegen, siehst du hier Vergleiche wie Kaffee vs. kein Kaffee oder viel Wasser vs. wenig Wasser.")
            } else {
                ForEach(insights.comparisons) { comparison in
                    ComparisonCard(comparison: comparison)
                }
            }
        }
    }

    private var symptomSection: some View {
        AnalysisSection(title: "Beschwerden", systemImage: "cross.case.fill") {
            if insights.topSymptoms.isEmpty {
                EmptyInsightCard(text: "Noch keine Beschwerden erfasst. Sobald Symptome eingetragen werden, erscheinen hier Häufigkeit und Stärke.")
            } else {
                ForEach(insights.topSymptoms) { symptom in
                    SymptomStatCard(stat: symptom)
                }
            }
        }
    }

    private var insightSection: some View {
        AnalysisSection(title: "Insights", systemImage: "lightbulb.fill") {
            if insights.messages.isEmpty {
                EmptyInsightCard(text: "Sobald genug Daten gesammelt wurden, erscheinen hier automatisch formulierte Beobachtungen.")
            } else {
                ForEach(insights.messages) { message in
                    InsightMessageCard(message: message)
                }
            }
        }
    }
}

// MARK: - Section wrapper

private struct AnalysisSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title)
                    .font(.title3.weight(.semibold))
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Wellbeing metric card

private struct WellbeingMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
