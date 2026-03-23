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
                        "No Entries Yet",
                        systemImage: "heart.text.square",
                        description: Text("Create your first daily check-in to start tracking patterns.")
                    )
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink {
                                EntryEditorView(entry: entry)
                            } label: {
                                DayRowView(entry: entry)
                            }
                        }
                        .onDelete(perform: deleteEntries)
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
                        Label("Reminders", systemImage: "bell.badge")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Label("New Entry", systemImage: "plus")
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
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.date, style: .date)
                .font(.headline)

            Text(entry.foodCategory.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !entry.symptoms.isEmpty {
                Text(entry.symptoms.map { "\($0.name) (\($0.severity.title))" }.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
