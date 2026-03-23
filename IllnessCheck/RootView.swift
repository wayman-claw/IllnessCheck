import SwiftUI
import SwiftData

struct RootView: View {
    @Query(sort: [SortDescriptor(\DailyEntry.date, order: .reverse)]) private var entries: [DailyEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewEntry = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Einträge",
                        systemImage: "heart.text.square",
                        description: Text("Starte mit deinem ersten Tages-Check-in und beobachte Muster über die Zeit.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    EntryEditorView(entry: entry)
                                } label: {
                                    DayRowView(entry: entry)
                                }
                            }
                            .onDelete(perform: deleteEntries)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("IllnessCheck")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ReminderSettingsView()
                    } label: {
                        Label("Reminder", systemImage: "bell.badge")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Label("Neuer Eintrag", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                EntryEditorView(entry: nil)
            }
        }
    }

    private func deleteEntries(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

private struct DayRowView: View {
    let entry: DailyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.date, style: .date)
                    .font(.headline)
                Spacer()
                Text(entry.foodCategory.title)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }

            HStack(spacing: 8) {
                SummaryBadge(title: "Getrunken", value: entry.overallHydration.title)
                SummaryBadge(title: "Kaffee", value: entry.hadCoffee ? "Ja" : "Nein")
                SummaryBadge(title: "Wasser", value: entry.waterLevel.title)
            }

            if !entry.symptoms.isEmpty {
                Text(entry.symptoms.map { "\($0.name) (\($0.severity.title))" }.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !entry.generalNote.isEmpty {
                Text(entry.generalNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
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
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
