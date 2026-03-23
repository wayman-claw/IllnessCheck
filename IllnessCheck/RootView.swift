import SwiftUI
import SwiftData
import Charts

struct RootView: View {
    @Query(sort: [SortDescriptor(\DailyEntry.date, order: .reverse)]) private var entries: [DailyEntry]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @State private var showingNewEntry = false
    @State private var exportJSON: String = ""
    @State private var showingExport = false
    @State private var selectedEntryForEditing: DailyEntry?

    private var latestEntry: DailyEntry? { entries.first }
    private var insights: AppInsights { InsightsBuilder.build(from: entries) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HeroCardView(latestEntry: latestEntry, appName: "DayTrace") {
                        openTodayCheckIn()
                    }

                    analyticsOverview
                    chartSection
                    achievementsSection

                    if entries.isEmpty {
                        ContentUnavailableView(
                            "Noch keine Einträge",
                            systemImage: "heart.text.square",
                            description: Text("Starte mit deinem ersten Tages-Check-in und beobachte Muster über die Zeit.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Letzte Tage")
                                    .font(.title3.weight(.semibold))
                                Spacer()
                                Button("Export") {
                                    exportJSON = ExportFactory.makeJSON(from: entries)
                                    showingExport = true
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(entries) { entry in
                                NavigationLink {
                                    DayDetailView(entry: entry) {
                                        selectedEntryForEditing = entry
                                    }
                                } label: {
                                    DayRowCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Bearbeiten") {
                                        selectedEntryForEditing = entry
                                    }
                                    .tint(.blue)

                                    Button("Löschen", role: .destructive) {
                                        delete(entry)
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        selectedEntryForEditing = entry
                                    } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        delete(entry)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("DayTrace")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ReminderSettingsView()
                    } label: {
                        Image(systemName: "bell.badge")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openTodayCheckIn()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                EntryEditorView(entry: todayEntry)
            }
            .sheet(item: $selectedEntryForEditing) { entry in
                EntryEditorView(entry: entry)
            }
            .sheet(isPresented: $showingExport) {
                ExportPreviewView(json: exportJSON)
            }
            .onChange(of: deepLinkManager.pendingRoute) { _, route in
                guard route == .todayCheckIn else { return }
                openTodayCheckIn()
                deepLinkManager.consume(route: .todayCheckIn)
            }
        }
    }

    private var todayEntry: DailyEntry? {
        let calendar = Calendar.current
        return entries.first(where: { calendar.isDateInToday($0.date) })
    }

    private var analyticsOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dashboard")
                .font(.headline)

            HStack(spacing: 10) {
                MiniStat(title: "Einträge", value: "\(entries.count)")
                MiniStat(title: "Streak", value: "\(insights.streakDays) Tage")
                MiniStat(title: "Mood", value: entries.isEmpty ? "–" : String(format: "%.1f/5", insights.averageMood))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verlauf")
                .font(.headline)

            Chart(recentEntries) { entry in
                LineMark(
                    x: .value("Tag", entry.date),
                    y: .value("Tagesgefühl", entry.moodScore)
                )
                .foregroundStyle(.pink)

                BarMark(
                    x: .value("Tag", entry.date),
                    y: .value("Hydration", entry.overallHydration.fillFraction * 5)
                )
                .foregroundStyle(.blue.opacity(0.35))
            }
            .frame(height: 220)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Motivation")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(insights.earnedAchievements) { achievement in
                        AchievementCard(achievement: achievement)
                    }

                    if insights.earnedAchievements.isEmpty {
                        AchievementPlaceholderCard()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentEntries: [DailyEntry] {
        Array(entries.sorted { $0.date < $1.date }.suffix(10))
    }

    private func delete(_ entry: DailyEntry) {
        modelContext.delete(entry)
    }

    private func openTodayCheckIn() {
        showingNewEntry = true
    }
}

private struct HeroCardView: View {
    let latestEntry: DailyEntry?
    let appName: String
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appName)
                .font(.largeTitle.bold())
            Text("Dein täglicher Health-Check mit Struktur, Verlauf und kleinen Motivationshilfen.")
                .foregroundStyle(.secondary)

            if let latestEntry {
                HStack(spacing: 10) {
                    MiniStat(title: "Letzter Eintrag", value: latestEntry.date.formatted(date: .abbreviated, time: .omitted))
                    MiniStat(title: "Getrunken", value: latestEntry.overallHydration.title)
                    MiniStat(title: "Mood", value: "\(latestEntry.moodScore)/5")
                }
            }

            Button(action: onCreate) {
                Label("Heutigen Check-in starten", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.18), Color.teal.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }
}

private struct MiniStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DayRowCard: View {
    let entry: DailyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date, style: .date)
                        .font(.headline)
                    Text(entry.foodCategory.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(entry.moodScore)/5")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.pink.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 10) {
                SummaryBadge(title: "Getrunken", value: entry.overallHydration.title)
                SummaryBadge(title: "Wasser", value: entry.waterLevel.title)
                SummaryBadge(title: "Kaffee", value: entry.hadCoffee ? "Ja" : "Nein")
            }

            if !entry.symptoms.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.symptoms) { symptom in
                            SymptomBadge(symptom: symptom)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SummaryBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SymptomBadge: View {
    let symptom: SymptomEntry

    var body: some View {
        let preset = SymptomPreset.preset(for: symptom.name)

        HStack(spacing: 6) {
            if let preset {
                Image(systemName: preset.symbol)
            }
            Text(symptom.name)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemBackground), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct DayDetailView: View {
    let entry: DailyEntry
    let onEdit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailHeader(entry: entry)

                DetailSection(title: "Trinken") {
                    DetailRow(label: "Insgesamt", value: entry.overallHydration.title)
                    DetailRow(label: "Kaffee", value: entry.hadCoffee ? "Ja" : "Nein")
                    DetailRow(label: "Softdrinks", value: entry.hadSoftdrinks ? "Ja" : "Nein")
                    DetailRow(label: "Alkohol", value: entry.alcoholLevel.title)
                    DetailRow(label: "Wasser", value: entry.waterLevel.title)
                    if !entry.otherDrinksNote.isEmpty {
                        DetailRow(label: "Anderes", value: entry.otherDrinksNote)
                    }
                }

                DetailSection(title: "Essen") {
                    DetailRow(label: "Kategorie", value: entry.foodCategory.title)
                    if !entry.foodNote.isEmpty {
                        DetailRow(label: "Notiz", value: entry.foodNote)
                    }
                }

                DetailSection(title: "Tagesgefühl") {
                    DetailRow(label: "Score", value: "\(entry.moodScore)/5")
                }

                DetailSection(title: "Beschwerden") {
                    if entry.symptoms.isEmpty {
                        Text("Keine Beschwerden erfasst")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entry.symptoms) { symptom in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(symptom.name) · \(symptom.severity.title)")
                                    .font(.subheadline.weight(.semibold))
                                if !symptom.note.isEmpty {
                                    Text(symptom.note)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if symptom.id != entry.symptoms.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                if !entry.generalNote.isEmpty {
                    DetailSection(title: "Notizen") {
                        Text(entry.generalNote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(entry.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten") {
                    onEdit()
                }
            }
        }
    }
}

private struct DetailHeader: View {
    let entry: DailyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.date, style: .date)
                .font(.largeTitle.bold())
            Text("\(entry.foodCategory.title) · Getrunken: \(entry.overallHydration.title)")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

private struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: achievement.symbol)
                .font(.title2)
                .foregroundStyle(.yellow)
            Text(achievement.title)
                .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .frame(width: 150, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AchievementPlaceholderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "target")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Badges folgen bald")
                .font(.subheadline.weight(.semibold))
            Text("Mit mehr Einträgen schaltest du kleine Erfolge frei.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 180, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ExportPreviewView: View {
    let json: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("JSON Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
padding()
            }
            .navigationTitle("JSON Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
