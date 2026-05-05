//
//  SymptomCategoriesSettingsView.swift
//  IllnessCheck / DayTrace
//
//  Settings UI for managing the catalogue of SymptomCategory entries.
//  Built-ins can be renamed but not archived. User-created categories can be
//  renamed, archived (soft-delete) and reactivated. Sort order is editable
//  via the standard Edit-mode reorder controls.
//

import SwiftUI
import SwiftData

struct SymptomCategoriesSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: [SortDescriptor(\SymptomCategory.sortOrder), SortDescriptor(\SymptomCategory.displayName)]
    )
    private var categories: [SymptomCategory]

    @State private var showingAddSheet = false
    @State private var editingCategory: SymptomCategory?
    @State private var showArchived = false

    var body: some View {
        let active = categories.filter { !$0.isArchived }
        let archived = categories.filter { $0.isArchived }

        List {
            Section {
                if active.isEmpty {
                    Text("Noch keine aktiven Kategorien.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(active) { category in
                        Button {
                            editingCategory = category
                        } label: {
                            CategoryRow(category: category)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !category.isBuiltIn {
                                Button(role: .destructive) {
                                    archive(category)
                                } label: {
                                    Label("Archivieren", systemImage: "archivebox")
                                }
                            }
                        }
                    }
                    .onMove(perform: moveActive)
                }
            } header: {
                HStack {
                    Text("Aktiv")
                    Spacer()
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                }
            } footer: {
                Text("Tippe eine Kategorie zum Umbenennen. Vordefinierte Kategorien können umbenannt, aber nicht archiviert werden.")
                    .font(.caption)
            }

            if !archived.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showArchived) {
                        ForEach(archived) { category in
                            HStack {
                                CategoryRow(category: category)
                                Spacer()
                                Button("Wiederherstellen") {
                                    unarchive(category)
                                }
                                .font(.footnote)
                                .buttonStyle(.borderless)
                            }
                        }
                    } label: {
                        Label("Archiviert (\(archived.count))", systemImage: "archivebox")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Symptom-Kategorien")
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showingAddSheet) {
            CategoryEditorSheet(mode: .create) { name in
                createCategory(displayName: name)
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditorSheet(mode: .edit(category)) { name in
                rename(category, to: name)
            }
        }
    }

    // MARK: actions

    private func createCategory(displayName: String) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let slug = SymptomCategorySlug.normalize(trimmed)
        // Dedupe: if an existing category with the same slug exists, just unarchive
        // and return — never create a duplicate slug.
        if let existing = categories.first(where: { $0.slug == slug }) {
            if existing.isArchived {
                existing.isArchived = false
            }
            try? modelContext.save()
            return
        }

        let nextSort = (categories.map(\.sortOrder).max() ?? 0) + 1
        let category = SymptomCategory(
            slug: slug,
            displayName: trimmed,
            symbolName: "cross.case.fill",
            isBuiltIn: false,
            sortOrder: nextSort,
            isArchived: false
        )
        modelContext.insert(category)
        try? modelContext.save()
    }

    private func rename(_ category: SymptomCategory, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != category.displayName else { return }
        category.displayName = trimmed
        try? modelContext.save()
    }

    private func archive(_ category: SymptomCategory) {
        guard !category.isBuiltIn else { return }
        category.isArchived = true
        try? modelContext.save()
    }

    private func unarchive(_ category: SymptomCategory) {
        category.isArchived = false
        try? modelContext.save()
    }

    private func moveActive(from source: IndexSet, to destination: Int) {
        var ordered = categories.filter { !$0.isArchived }
        ordered.move(fromOffsets: source, toOffset: destination)
        for (idx, category) in ordered.enumerated() {
            category.sortOrder = idx
        }
        try? modelContext.save()
    }
}

// MARK: - Row

private struct CategoryRow: View {
    let category: SymptomCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbolName)
                .frame(width: 24)
                .foregroundStyle(category.isArchived ? .secondary : Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.body)
                    .foregroundStyle(category.isArchived ? .secondary : .primary)
                if category.isBuiltIn {
                    Text("Vordefiniert")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Add / Rename sheet

private struct CategoryEditorSheet: View {
    enum Mode {
        case create
        case edit(SymptomCategory)

        var navTitle: String {
            switch self {
            case .create: return "Neue Kategorie"
            case .edit: return "Kategorie umbenennen"
            }
        }

        var initialName: String {
            switch self {
            case .create: return ""
            case .edit(let category): return category.displayName
            }
        }
    }

    let mode: Mode
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name der Kategorie", text: $name)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                } footer: {
                    Text("Nur einmalig nötig — danach reicht ein Tap im Tageseintrag, um diese Kategorie auszuwählen.")
                        .font(.caption)
                }
            }
            .navigationTitle(mode.navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if name.isEmpty { name = mode.initialName }
                nameFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        dismiss()
    }
}
