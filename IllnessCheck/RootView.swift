import SwiftUI
import SwiftData
import Charts

struct RootView: View {
    @Query(sort: [SortDescriptor(\DailyEntry.date, order: .reverse)]) private var entries: [DailyEntry]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var storeRecoveryAnnouncer: StoreRecoveryAnnouncer
    @State private var showingNewEntry = false
    @State private var exportJSON: String = ""
    @State private var showingExport = false
    @State private var selectedEntryForEditing: DailyEntry?

    private var latestEntry: DailyEntry? { entries.first }
    private var insights: AppInsights {
        InsightsBuilder.build(from: entries, userSex: appSettings.userSex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    storeRecoveryBanner

                    HeroCardView(latestEntry: latestEntry, appName: "DayTrace") {
                        openTodayCheckIn()
                    }

                    analyticsOverview
                    moodChartSection
                    comparisonSection
                    correlationSection
                    symptomSection
                    insightsSection
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
                ToolbarItemGroup(placement: .topBarLeading) {
                    NavigationLink {
                        ProfileSettingsView()
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }

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
        entry(for: .now)
    }

    private func entry(for date: Date) -> DailyEntry? {
        let calendar = Calendar.current
        let normalized = calendar.startOfDay(for: date)
        return entries.first(where: { calendar.isDate($0.date, inSameDayAs: normalized) })
    }

    @ViewBuilder
    private var storeRecoveryBanner: some View {
        if let event = storeRecoveryAnnouncer.visibleEvent,
           let title = storeRecoveryAnnouncer.bannerTitle,
           let message = storeRecoveryAnnouncer.bannerMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: bannerSymbol(for: event))
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.92))
                }
                Spacer(minLength: 8)
                Button {
                    withAnimation { storeRecoveryAnnouncer.dismiss() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Schließen")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(bannerGradient(for: event))
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func bannerSymbol(for event: StoreBootstrapEvent) -> String {
        switch event {
        case .restoredFromBackup: return "arrow.counterclockwise.circle.fill"
        case .pendingRestoreWaiting: return "clock.arrow.circlepath"
        case .fellBackToInMemory: return "exclamationmark.triangle.fill"
        case .clean: return "checkmark.circle.fill"
        }
    }

    private func bannerGradient(for event: StoreBootstrapEvent) -> LinearGradient {
        switch event {
        case .restoredFromBackup:
            return LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pendingRestoreWaiting:
            return LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fellBackToInMemory:
            return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .clean:
            return LinearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var analyticsOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Überblick")
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

    private var moodChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wohlbefinden & Hydration")
                .font(.headline)

            Chart(recentEntries) { entry in
                LineMark(
                    x: .value("Tag", entry.date),
                    y: .value("Tagesgefühl", entry.moodScore)
                )
                .foregroundStyle(.pink)
                .lineStyle(StrokeStyle(lineWidth: 3))

                AreaMark(
                    x: .value("Tag", entry.date),
                    y: .value("Tagesgefühl", entry.moodScore)
                )
                .foregroundStyle(.pink.opacity(0.12))

                BarMark(
                    x: .value("Tag", entry.date),
                    y: .value("Hydration", entry.overallHydration.fillFraction * 5)
                )
                .foregroundStyle(.blue.opacity(0.25))
            }
            .frame(height: 240)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Einflussfaktoren")
                .font(.headline)

            if insights.comparisons.isEmpty {
                EmptyInsightCard(text: "Sobald genug Daten vorliegen, siehst du hier Vergleiche wie Kaffee vs. kein Kaffee oder viel Wasser vs. wenig Wasser.")
            } else {
                ForEach(insights.comparisons) { comparison in
                    ComparisonCard(comparison: comparison)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var correlationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mögliche Zusammenhänge")
                .font(.headline)

            if insights.correlations.isEmpty {
                EmptyInsightCard(text: "Sobald genug Tage erfasst sind (mindestens 7 mit und 7 ohne den jeweiligen Auslöser), siehst du hier Auffälligkeiten — z. B. ‚Kopfschmerzen treten an Kaffee-Tagen häufiger auf‘.")
            } else {
                ForEach(insights.correlations.prefix(6)) { insight in
                    CorrelationCard(insight: insight)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var symptomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Beschwerden")
                .font(.headline)

            if insights.topSymptoms.isEmpty {
                EmptyInsightCard(text: "Noch keine Beschwerden erfasst. Sobald Symptome eingetragen werden, erscheinen hier Häufigkeit und Stärke.")
            } else {
                ForEach(insights.topSymptoms) { symptom in
                    SymptomStatCard(stat: symptom)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)

            if insights.messages.isEmpty {
                EmptyInsightCard(text: "Sobald genug Daten gesammelt wurden, erscheinen hier automatisch formulierte Beobachtungen.")
            } else {
                ForEach(insights.messages) { message in
                    InsightMessageCard(message: message)
                }
            }
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
        Array(entries.sorted { $0.date < $1.date }.suffix(14))
    }

    private func delete(_ entry: DailyEntry) {
        modelContext.delete(entry)
    }

    private func openTodayCheckIn() {
        selectedEntryForEditing = nil
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
            Text("Dein täglicher Health-Check mit Struktur, Verlauf und echten Mustern.")
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

private struct ComparisonCard: View {
    let comparison: ComparisonInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(comparison.title)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                ComparisonValueCard(label: comparison.leftLabel, value: comparison.leftValue, tint: .blue)
                ComparisonValueCard(label: comparison.rightLabel, value: comparison.rightValue, tint: .teal)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ComparisonValueCard: View {
    let label: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", value))
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CorrelationCard: View {
    let insight: CorrelationInsight

    private var directionWord: String {
        insight.rateDelta >= 0 ? "häufiger" : "seltener"
    }

    private var triggerTint: Color {
        switch insight.strength {
        case .weak: return .gray
        case .moderate: return .orange
        case .strong: return insight.rateDelta >= 0 ? .red : .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(insight.categoryDisplayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StrengthBadge(strength: insight.strength)
            }

            Text("\(directionWord) bei „\(insight.trigger.presentLabel)“")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                CorrelationValueCard(
                    label: insight.trigger.presentLabel,
                    rate: insight.withTriggerRate,
                    sampleSize: insight.withTriggerTotal,
                    tint: triggerTint
                )
                CorrelationValueCard(
                    label: insight.trigger.absentLabel,
                    rate: insight.withoutTriggerRate,
                    sampleSize: insight.withoutTriggerTotal,
                    tint: .secondary
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CorrelationValueCard: View {
    let label: String
    let rate: Double
    let sampleSize: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(Int((rate * 100).rounded()))%")
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
            Text("\(sampleSize) Tage")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct StrengthBadge: View {
    let strength: CorrelationInsight.Strength

    private var label: String {
        switch strength {
        case .weak: return "schwach"
        case .moderate: return "mittel"
        case .strong: return "stark"
        }
    }

    private var tint: Color {
        switch strength {
        case .weak: return .gray
        case .moderate: return .orange
        case .strong: return .red
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}

private struct SymptomStatCard: View {
    let stat: SymptomStat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(stat.count)x")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.12), in: Capsule())
            }

            HStack {
                Text("Ø Stärke")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f / 3", stat.averageSeverity))
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct InsightMessageCard: View {
    let message: InsightMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.title)
                .font(.subheadline.weight(.semibold))
            Text(message.body)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct EmptyInsightCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        HStack(spacing: 6) {
            if let symbol = symptom.category?.symbolName {
                Image(systemName: symbol)
            }
            Text(symptom.displayName)
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
    @EnvironmentObject private var appSettings: AppSettings
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

                if appSettings.shouldShowCycleSection && (entry.cyclePhase != .notSet || entry.cycleDay != nil || !entry.cycleNote.isEmpty) {
                    DetailSection(title: "Zyklus") {
                        DetailRow(label: "Phase", value: entry.cyclePhase.title)
                        if let cycleDay = entry.cycleDay {
                            DetailRow(label: "Zyklustag", value: "\(cycleDay)")
                        }
                        if !entry.cycleNote.isEmpty {
                            DetailRow(label: "Notiz", value: entry.cycleNote)
                        }
                    }
                }

                DetailSection(title: "Beschwerden") {
                    if entry.symptoms.isEmpty {
                        Text("Keine Beschwerden erfasst")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entry.symptoms) { symptom in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    if let symbol = symptom.category?.symbolName {
                                        Image(systemName: symbol)
                                            .foregroundStyle(.orange)
                                    }
                                    Text("\(symptom.displayName) · \(symptom.severity.title)")
                                        .font(.subheadline.weight(.semibold))
                                }
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
