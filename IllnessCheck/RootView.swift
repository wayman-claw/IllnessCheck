import SwiftUI
import SwiftData

struct RootView: View {
    @Query(sort: [SortDescriptor(\DailyEntry.date, order: .reverse)]) private var entries: [DailyEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewEntry = false

    private var latestEntry: DailyEntry? { entries.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HeroCardView(latestEntry: latestEntry) {
                        showingNewEntry = true
                    }

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
                            Text("Letzte Tage")
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(entries) { entry in
                                NavigationLink {
                                    DayDetailView(entry: entry)
                                } label: {
                                    DayRowCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
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
            .navigationTitle("IllnessCheck")
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
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                EntryEditorView(entry: nil)
            }
        }
    }

    private func delete(_ entry: DailyEntry) {
        modelContext.delete(entry)
    }
}

private struct HeroCardView: View {
    let latestEntry: DailyEntry?
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Health Check")
                .font(.largeTitle.bold())
            Text("Schneller Abend-Check-in mit klarer Struktur statt großem Tagebuch.")
                .foregroundStyle(.secondary)

            if let latestEntry {
                HStack(spacing: 10) {
                    MiniStat(title: "Letzter Eintrag", value: latestEntry.date.formatted(date: .abbreviated, time: .omitted))
                    MiniStat(title: "Getrunken", value: latestEntry.overallHydration.title)
                    MiniStat(title: "Beschwerden", value: latestEntry.symptoms.isEmpty ? "Keine" : "\(latestEntry.symptoms.count)")
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

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                SummaryBadge(title: "Getrunken", value: entry.overallHydration.title)
                SummaryBadge(title: "Wasser", value: entry.waterLevel.title)
                SummaryBadge(title: "Kaffee", value: entry.hadCoffee ? "Ja" : "Nein")
            }

            if !entry.symptoms.isEmpty {
                Text(entry.symptoms.map { "\($0.name) (\($0.severity.title))" }.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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

private struct DayDetailView: View {
    let entry: DailyEntry
    @State private var showingEdit = false

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
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EntryEditorView(entry: entry)
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
