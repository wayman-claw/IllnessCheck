//
//  HomeView.swift
//  IllnessCheck / DayTrace
//
//  The "Heute" home screen content. RootView wraps this in a NavigationStack
//  with toolbar and sheets; HomeView itself is presentation-only and pushes
//  intent back up via callbacks.
//
//  Layout (top to bottom):
//    1. HeroCard              — today's check-in CTA + quick stats
//    2. Stats banner          — streak, total, this month progress
//    3. Calendar card         — month view with day markers (gamification)
//    4. Achievements strip    — earned badges, horizontal scroll
//    5. Overview tiles        — entries, mood Ø, good days, etc.
//    6. Recent days           — list of recent entries with edit/delete
//

import SwiftUI

struct HomeView: View {
    let entries: [DailyEntry]
    let insights: AppInsights

    let onStartTodayCheckIn: () -> Void
    let onSelectDay: (Date) -> Void
    let onEditEntry: (DailyEntry) -> Void
    let onDeleteEntry: (DailyEntry) -> Void
    let onExport: () -> Void

    private var latestEntry: DailyEntry? {
        entries.first
    }

    private var entriesThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        return entries.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }.count
    }

    private var daysInCurrentMonth: Int {
        let calendar = Calendar.current
        return calendar.range(of: .day, in: .month, for: .now)?.count ?? 30
    }

    var body: some View {
        VStack(spacing: 20) {
            HeroCardView(latestEntry: latestEntry, appName: "DayTrace") {
                onStartTodayCheckIn()
            }

            statsBanner

            MonthCalendarView(entries: entries, onSelectDay: onSelectDay)

            achievementsSection

            overviewSection

            if entries.isEmpty {
                ContentUnavailableView(
                    "Noch keine Einträge",
                    systemImage: "heart.text.square",
                    description: Text("Starte mit deinem ersten Tages-Check-in und beobachte Muster über die Zeit.")
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                recentDaysSection
            }
        }
    }

    // MARK: - Stats banner

    private var statsBanner: some View {
        HStack(spacing: 12) {
            StatsBannerTile(
                symbol: "flame.fill",
                tint: .orange,
                value: "\(insights.streakDays)",
                label: "Streak"
            )
            StatsBannerTile(
                symbol: "checkmark.seal.fill",
                tint: .teal,
                value: "\(entries.count)",
                label: "Total"
            )
            StatsBannerTile(
                symbol: "calendar",
                tint: .blue,
                value: "\(entriesThisMonth)/\(daysInCurrentMonth)",
                label: "Diesen Monat"
            )
        }
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Motivation", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(insights.earnedAchievements.count)/\(Achievement.allCases.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Achievement.allCases) { achievement in
                        AchievementBadge(
                            achievement: achievement,
                            earned: insights.earnedAchievements.contains(achievement)
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Overview tiles

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Überblick", systemImage: "square.grid.2x2.fill")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MiniStat(title: "Einträge", value: "\(entries.count)")
                MiniStat(title: "Streak", value: "\(insights.streakDays) Tage")
                MiniStat(title: "Mood Ø", value: entries.isEmpty ? "–" : String(format: "%.1f/5", insights.averageMood))
                MiniStat(title: "Gute Tage", value: entries.isEmpty ? "–" : "\(Int((insights.goodDayShare * 100).rounded()))%")
                MiniStat(title: "Symptomfrei", value: "\(insights.symptomFreeDays)")
                MiniStat(title: "Beschwerden/Tag", value: entries.isEmpty ? "–" : String(format: "%.1f", insights.averageSymptomsPerDay))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Recent days

    private var recentDaysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Letzte Tage", systemImage: "clock.arrow.circlepath")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Export", action: onExport)
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(entries) { entry in
                NavigationLink {
                    DayDetailView(entry: entry) {
                        onEditEntry(entry)
                    }
                } label: {
                    DayRowCard(entry: entry)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Bearbeiten") { onEditEntry(entry) }
                        .tint(.blue)
                    Button("Löschen", role: .destructive) { onDeleteEntry(entry) }
                }
                .contextMenu {
                    Button {
                        onEditEntry(entry)
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onDeleteEntry(entry)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
    }
}

// MARK: - Stats banner tile

private struct StatsBannerTile: View {
    let symbol: String
    let tint: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Achievement badge (locked-or-earned variant)

private struct AchievementBadge: View {
    let achievement: Achievement
    let earned: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(earned ? tintColor.opacity(0.16) : Color(.tertiarySystemBackground))
                    .frame(width: 56, height: 56)
                Image(systemName: achievement.symbol)
                    .font(.title3)
                    .foregroundStyle(earned ? tintColor : .secondary.opacity(0.55))
                    .symbolRenderingMode(.hierarchical)
            }
            .overlay(
                Circle()
                    .stroke(earned ? tintColor.opacity(0.4) : .clear, lineWidth: 1.5)
            )

            VStack(spacing: 2) {
                Text(achievement.title)
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(earned ? .primary : .secondary)
                Text(achievement.hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 92)
        }
        .padding(.vertical, 6)
        .opacity(earned ? 1 : 0.65)
        .accessibilityElement()
        .accessibilityLabel("\(achievement.title), \(earned ? "freigeschaltet" : "noch nicht freigeschaltet")")
    }

    private var tintColor: Color {
        switch achievement {
        case .firstEntry: return .purple
        case .streak3, .streak7, .streak14, .streak30: return .orange
        case .hydrationWin: return .blue
        case .reflectionPro: return .indigo
        case .perfectWeek: return .yellow
        case .symptomFree7: return .pink
        case .monthExplorer: return .green
        case .firstCorrelation: return .mint
        }
    }
}
