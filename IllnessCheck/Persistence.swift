//
//  Persistence.swift
//  IllnessCheck / DayTrace
//
//  Migration foundation + safe store backup/restore for SwiftData.
//
//  Goals (Step 0):
//  - Versioned schema (SchemaV1) so future @Model changes can be migrated cleanly.
//  - Pre-migration auto-backups of the SwiftData store before any container init that
//    might trigger a migration.
//  - Aggressive auto-recovery: if the container fails to initialize (incompatible store,
//    failed migration, etc.) we restore the most recent backup automatically. The user
//    never sees a wiped database. They get an unobtrusive banner instead.
//  - Pending-restore logic that survives across app updates: if a restore can't be
//    completed today (e.g. backup written by a future schema), the marker is kept and
//    we retry on every subsequent launch.
//  - The old "silently delete the whole store" reset path is gone.
//
//  Storage layout (inside the app sandbox):
//
//    Application Support/Backups/
//      auto-2026-05-04T11-40-03Z/
//        default.store
//        default.store-shm
//        default.store-wal
//        meta.json
//
//  Retention: the most recent 3 successful auto-backups are kept. A backup that is
//  referenced by a PendingRestore marker is never deleted, even if older.
//

import Foundation
import SwiftData
import os

// MARK: - Logger

enum PersistenceLog {
    static let logger = Logger(subsystem: "app.daytrace.persistence", category: "store")
}

// MARK: - Versioned schema (V1)

/// SchemaV1 is the original shape of the data model: free-text symptom names, no
/// SymptomCategory entity. We keep it declared here so SwiftData can still open
/// V1 stores and migrate them to V2.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [DailyEntry.self, SymptomEntry.self]
    }
}

/// SchemaV2 introduces SymptomCategory and adds a `category` relationship on
/// SymptomEntry. The legacy `name` stays on SymptomEntry as an audit field.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [DailyEntry.self, SymptomEntry.self, SymptomCategory.self]
    }
}

/// Migration plan: V1 -> V2. The custom stage seeds built-in categories and
/// rewires every existing SymptomEntry to point at a category.
enum DayTraceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [v1ToV2] }

    static let v1ToV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let logger = Logger(subsystem: "app.daytrace.persistence", category: "migration")
            logger.notice("V1->V2: starting symptom-category migration")

            // 1. Seed built-ins idempotently. Look for an existing slug first;
            //    if not present, create. We never overwrite a user-renamed built-in.
            let existingCategories = (try? context.fetch(FetchDescriptor<SymptomCategory>())) ?? []
            var bySlug: [String: SymptomCategory] = Dictionary(uniqueKeysWithValues: existingCategories.map { ($0.slug, $0) })

            for (idx, preset) in SymptomPreset.orderedSeed.enumerated() {
                if bySlug[preset.slug] == nil {
                    let cat = SymptomCategory(
                        slug: preset.slug,
                        displayName: preset.title,
                        symbolName: preset.symbol,
                        isBuiltIn: true,
                        sortOrder: idx,
                        isArchived: false
                    )
                    context.insert(cat)
                    bySlug[preset.slug] = cat
                    logger.info("V1->V2: seeded built-in \(preset.slug, privacy: .public)")
                }
            }

            // 2. Walk every SymptomEntry, attach a category. Map by normalized name.
            //    If a normalized name doesn't match a built-in, create a user category
            //    on the fly and reuse it for any further entries with the same name.
            let allEntries = (try? context.fetch(FetchDescriptor<SymptomEntry>())) ?? []
            var nextSortOrder = SymptomPreset.orderedSeed.count
            var migrated = 0
            var newUserCategories = 0

            for entry in allEntries {
                if entry.category != nil { continue } // already linked, skip
                let raw = entry.name
                let slug = SymptomCategorySlug.normalize(raw)
                if let existing = bySlug[slug] {
                    entry.category = existing
                } else {
                    let displayName = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    let safeName = displayName.isEmpty ? "Unbenannt" : displayName
                    let cat = SymptomCategory(
                        slug: slug,
                        displayName: safeName,
                        symbolName: "cross.case.fill",
                        isBuiltIn: false,
                        sortOrder: nextSortOrder,
                        isArchived: false
                    )
                    context.insert(cat)
                    bySlug[slug] = cat
                    entry.category = cat
                    nextSortOrder += 1
                    newUserCategories += 1
                    logger.info("V1->V2: created user category \(slug, privacy: .public)")
                }
                migrated += 1
            }

            do {
                try context.save()
                logger.notice("V1->V2: linked \(migrated, privacy: .public) entries; created \(newUserCategories, privacy: .public) user categories")
            } catch {
                logger.error("V1->V2: save failed: \(String(describing: error), privacy: .public)")
                throw error
            }
        }
    )
}

// MARK: - Pending-restore marker (UserDefaults)

/// Persistent marker telling the app, on the *next* launch, that a restore from a
/// specific backup is pending. Used when the container init fails. Survives app
/// updates because UserDefaults is part of the sandbox.
private enum PendingRestoreDefaultsKey {
    static let backupFolderName = "DayTrace.PendingRestore.BackupFolderName"
    static let recordedSchemaIdentifier = "DayTrace.PendingRestore.SchemaIdentifier"
    static let lastSuccessfulSchemaIdentifier = "DayTrace.LastSuccessfulSchemaIdentifier"
    static let lastSuccessfulAppVersion = "DayTrace.LastSuccessfulAppVersion"
    static let lastRestoredBannerToken = "DayTrace.LastRestoredBannerToken"
}

// MARK: - Backup metadata

struct StoreBackupMeta: Codable {
    let createdAt: Date
    let appVersion: String
    let appBuild: String
    let schemaIdentifier: String
    let folderName: String
}

// MARK: - Bootstrap result

/// Outcome surfaced to the UI, so we can show a banner after a recovery happened.
enum StoreBootstrapEvent: Equatable {
    /// Nothing notable happened. Fresh launch, schema already at current version.
    case clean
    /// We restored from `backupName` automatically because the prior init failed.
    case restoredFromBackup(folderName: String, createdAt: Date)
    /// A previous launch left a pending-restore marker but the backup is for a
    /// schema we cannot read yet. We're keeping the marker for a future update.
    case pendingRestoreWaiting(folderName: String, recordedSchemaIdentifier: String)
    /// Last-resort: container could not be created at all and recovery did not
    /// succeed either. We're running on an in-memory container so the app is at
    /// least usable, but the user's data is currently unavailable. The on-disk
    /// store is untouched (we never wipe).
    case fellBackToInMemory(reason: String)
}

// MARK: - Store paths

private enum StorePaths {
    /// Default SwiftData store filename. SwiftData uses "default.store" when no
    /// explicit URL is passed in the ModelConfiguration.
    static let defaultStoreFileName = "default.store"
    static let storeFileSuffixes = ["", "-shm", "-wal"]

    static func applicationSupportDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    /// Where SwiftData itself places `default.store` when no URL override is given.
    static func defaultStoreURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent(defaultStoreFileName)
    }

    static func backupsRoot() throws -> URL {
        let url = try applicationSupportDirectory().appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Returns existing store-related files for a given base store URL.
    /// We don't construct paths blindly — we list the parent dir and match by prefix
    /// so we also catch SwiftData's incidental sidecar files cleanly.
    static func existingStoreFiles(baseStoreURL: URL) -> [URL] {
        let dir = baseStoreURL.deletingLastPathComponent()
        let baseName = baseStoreURL.lastPathComponent
        let candidates = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )) ?? []
        return candidates.filter { $0.lastPathComponent.hasPrefix(baseName) }
    }
}

// MARK: - Schema identity

private enum SchemaIdentity {
    /// The currently-active versioned schema. Update this constant when a new
    /// schema version is introduced.
    static let activeVersionedSchema: any VersionedSchema.Type = SchemaV2.self

    /// Stable, deterministic identifier for the current compiled schema, derived from
    /// the model type names + the active version. Any version bump rotates the
    /// identifier automatically, which in turn triggers a pre-migration backup on
    /// the next launch.
    static var current: String {
        let v = activeVersionedSchema.versionIdentifier
        let names = activeVersionedSchema.models.map { String(describing: $0) }.sorted().joined(separator: ",")
        return "v\(v.major).\(v.minor).\(v.patch)|models=\(names)"
    }

    static var currentAppVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    static var currentAppShort: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    static var currentAppBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}

// MARK: - Backup engine

enum StoreBackup {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Snapshot the live store files into a fresh `auto-<timestamp>` folder.
    /// Returns the folder name (relative to backupsRoot) on success, or nil if
    /// there were no store files to back up (i.e. fresh install).
    @discardableResult
    static func snapshotCurrentStore() throws -> String? {
        let baseStoreURL = try StorePaths.defaultStoreURL()
        let files = StorePaths.existingStoreFiles(baseStoreURL: baseStoreURL)
        guard !files.isEmpty else {
            PersistenceLog.logger.info("snapshot: no store files present, skipping")
            return nil
        }

        let stamp = isoFormatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let folderName = "auto-\(stamp)"
        let folderURL = try StorePaths.backupsRoot().appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        for fileURL in files {
            let dest = folderURL.appendingPathComponent(fileURL.lastPathComponent)
            try FileManager.default.copyItem(at: fileURL, to: dest)
        }

        let meta = StoreBackupMeta(
            createdAt: Date(),
            appVersion: SchemaIdentity.currentAppShort,
            appBuild: SchemaIdentity.currentAppBuild,
            schemaIdentifier: SchemaIdentity.current,
            folderName: folderName
        )
        let metaURL = folderURL.appendingPathComponent("meta.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(meta).write(to: metaURL, options: [.atomic])

        PersistenceLog.logger.info("snapshot: created backup \(folderName, privacy: .public)")
        return folderName
    }

    /// All auto-backups, newest first, ignoring anything that doesn't have a meta.json.
    static func listBackups() -> [StoreBackupMeta] {
        guard let root = try? StorePaths.backupsRoot() else { return [] }
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        )) ?? []

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var metas: [StoreBackupMeta] = []
        for folder in folders {
            let metaURL = folder.appendingPathComponent("meta.json")
            guard let data = try? Data(contentsOf: metaURL),
                  var meta = try? decoder.decode(StoreBackupMeta.self, from: data) else { continue }
            // If a backup got renamed on disk, trust the directory name we found.
            meta = StoreBackupMeta(
                createdAt: meta.createdAt,
                appVersion: meta.appVersion,
                appBuild: meta.appBuild,
                schemaIdentifier: meta.schemaIdentifier,
                folderName: folder.lastPathComponent
            )
            metas.append(meta)
        }
        return metas.sorted(by: { $0.createdAt > $1.createdAt })
    }

    /// Restore the given backup by overwriting current store files. The container
    /// must NOT be open while this runs.
    static func restore(folderName: String) throws {
        let backupFolder = try StorePaths.backupsRoot().appendingPathComponent(folderName, isDirectory: true)
        let baseStoreURL = try StorePaths.defaultStoreURL()
        let parentDir = baseStoreURL.deletingLastPathComponent()

        // 1. Remove any current store sidecar files (they belong to the broken state we're undoing).
        let liveFiles = StorePaths.existingStoreFiles(baseStoreURL: baseStoreURL)
        for url in liveFiles {
            try? FileManager.default.removeItem(at: url)
        }

        // 2. Copy backup contents back over.
        let backupFiles = (try? FileManager.default.contentsOfDirectory(
            at: backupFolder,
            includingPropertiesForKeys: nil
        )) ?? []

        for fileURL in backupFiles {
            // Don't restore meta.json into the live store dir.
            if fileURL.lastPathComponent == "meta.json" { continue }
            let dest = parentDir.appendingPathComponent(fileURL.lastPathComponent)
            try FileManager.default.copyItem(at: fileURL, to: dest)
        }

        PersistenceLog.logger.notice("restore: restored backup \(folderName, privacy: .public)")
    }

    /// Trim auto-backups to at most `keep` entries, newest first. Never delete a
    /// backup whose folder name matches `protectedFolderName` (e.g. one referenced
    /// by a pending-restore marker).
    static func prune(keep: Int = 3, protectedFolderName: String? = nil) {
        let metas = listBackups() // newest first
        guard metas.count > keep else { return }
        let toRemove = metas.dropFirst(keep)
        for meta in toRemove {
            if meta.folderName == protectedFolderName { continue }
            if let folderURL = try? StorePaths.backupsRoot().appendingPathComponent(meta.folderName) {
                try? FileManager.default.removeItem(at: folderURL)
                PersistenceLog.logger.info("prune: removed backup \(meta.folderName, privacy: .public)")
            }
        }
    }
}

// MARK: - Bootstrap

/// Builds a SwiftData ModelContainer with safety nets:
///   1. If a previous launch left a pending-restore marker, attempt to restore first.
///   2. Snapshot the current store before any potentially-migrating init.
///   3. Try to open the container with the versioned schema + migration plan.
///   4. On failure, automatically restore the most recent backup and try again.
///   5. As a last resort, fall back to an in-memory container so the app still runs.
///      The on-disk data is never deleted by us.
enum StoreBootstrap {
    static func makeContainer(defaults: UserDefaults = .standard) -> (container: ModelContainer, event: StoreBootstrapEvent) {
        // Phase 1: any pending restore from a previous failed launch?
        let pendingRestoreEvent = applyPendingRestoreIfPossible(defaults: defaults)

        // Phase 2: pre-migration snapshot when schema has changed since last successful run.
        snapshotIfSchemaChanged(defaults: defaults)

        // Phase 3: try to open with current schema + migration plan.
        if let container = tryMakeOnDiskContainer() {
            recordSuccessfulLaunch(defaults: defaults)
            StoreBackup.prune(keep: 3, protectedFolderName: protectedBackupFolderName(defaults: defaults))
            // If we already restored above, surface that. Otherwise: clean.
            return (container, pendingRestoreEvent ?? .clean)
        }

        // Phase 4: container init failed. Try to auto-recover from the latest backup.
        let backups = StoreBackup.listBackups()
        if let latest = backups.first {
            do {
                try StoreBackup.restore(folderName: latest.folderName)
                if let container = tryMakeOnDiskContainer() {
                    recordSuccessfulLaunch(defaults: defaults)
                    clearPendingRestore(defaults: defaults)
                    PersistenceLog.logger.notice("auto-recovery: restored \(latest.folderName, privacy: .public) and reopened container")
                    return (container, .restoredFromBackup(folderName: latest.folderName, createdAt: latest.createdAt))
                } else {
                    // The backup itself can't be opened with the current schema — keep it as a pending restore.
                    setPendingRestore(folderName: latest.folderName, schemaIdentifier: latest.schemaIdentifier, defaults: defaults)
                    PersistenceLog.logger.error("auto-recovery: even backup \(latest.folderName, privacy: .public) cannot be opened with current schema; keeping pending marker")
                    return (makeInMemoryContainer(), .pendingRestoreWaiting(folderName: latest.folderName, recordedSchemaIdentifier: latest.schemaIdentifier))
                }
            } catch {
                PersistenceLog.logger.error("auto-recovery: restore threw: \(String(describing: error), privacy: .public)")
                setPendingRestore(folderName: latest.folderName, schemaIdentifier: latest.schemaIdentifier, defaults: defaults)
                return (makeInMemoryContainer(), .pendingRestoreWaiting(folderName: latest.folderName, recordedSchemaIdentifier: latest.schemaIdentifier))
            }
        }

        // Phase 5: no backups at all (e.g. very first launch where init still failed).
        // We do NOT delete the live store. Run in memory so the app is usable; user's
        // bytes stay on disk for a future fix.
        PersistenceLog.logger.error("auto-recovery: no backups available, falling back to in-memory")
        return (makeInMemoryContainer(), .fellBackToInMemory(reason: "no backups available"))
    }

    // MARK: helpers

    private static func tryMakeOnDiskContainer() -> ModelContainer? {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, migrationPlan: DayTraceMigrationPlan.self, configurations: [config])
        } catch {
            PersistenceLog.logger.error("on-disk container init failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // If even an in-memory container fails, we're so far gone that crashing is the
        // only honest signal. But this is virtually impossible.
        do {
            return try ModelContainer(for: schema, migrationPlan: DayTraceMigrationPlan.self, configurations: [config])
        } catch {
            fatalError("in-memory ModelContainer creation failed: \(error)")
        }
    }

    private static func snapshotIfSchemaChanged(defaults: UserDefaults) {
        let currentIdentifier = SchemaIdentity.current
        let lastSuccessful = defaults.string(forKey: PendingRestoreDefaultsKey.lastSuccessfulSchemaIdentifier)
        if lastSuccessful != currentIdentifier {
            do {
                _ = try StoreBackup.snapshotCurrentStore()
            } catch {
                PersistenceLog.logger.error("pre-migration snapshot failed: \(String(describing: error), privacy: .public)")
                // Snapshot failure is logged but not fatal — the user might have a
                // brand-new install with no store yet, or a transient FS issue. Either
                // way we still try to open the container.
            }
        }
    }

    private static func applyPendingRestoreIfPossible(defaults: UserDefaults) -> StoreBootstrapEvent? {
        guard let folderName = defaults.string(forKey: PendingRestoreDefaultsKey.backupFolderName) else { return nil }
        let recordedIdentifier = defaults.string(forKey: PendingRestoreDefaultsKey.recordedSchemaIdentifier) ?? ""

        // Find the backup. It must still exist on disk.
        let allBackups = StoreBackup.listBackups()
        guard let target = allBackups.first(where: { $0.folderName == folderName }) else {
            PersistenceLog.logger.error("pending-restore: marker references missing backup \(folderName, privacy: .public); clearing marker")
            clearPendingRestore(defaults: defaults)
            return nil
        }

        // We try the restore; if the resulting store can't open with our current
        // schema, we leave the marker in place (the next app update may know the schema).
        do {
            try StoreBackup.restore(folderName: target.folderName)
        } catch {
            PersistenceLog.logger.error("pending-restore: restore threw \(String(describing: error), privacy: .public); keeping marker")
            return .pendingRestoreWaiting(folderName: folderName, recordedSchemaIdentifier: recordedIdentifier)
        }

        if let _ = tryMakeOnDiskContainer() {
            // Yay — the restore is good against the current schema. Clear the marker.
            clearPendingRestore(defaults: defaults)
            recordSuccessfulLaunch(defaults: defaults)
            PersistenceLog.logger.notice("pending-restore: succeeded with backup \(target.folderName, privacy: .public)")
            return .restoredFromBackup(folderName: target.folderName, createdAt: target.createdAt)
        } else {
            // Restoring put back data we still can't open. Keep marker, signal waiting.
            PersistenceLog.logger.notice("pending-restore: backup \(target.folderName, privacy: .public) still incompatible with current schema; keeping marker")
            return .pendingRestoreWaiting(folderName: folderName, recordedSchemaIdentifier: recordedIdentifier)
        }
    }

    private static func recordSuccessfulLaunch(defaults: UserDefaults) {
        defaults.set(SchemaIdentity.current, forKey: PendingRestoreDefaultsKey.lastSuccessfulSchemaIdentifier)
        defaults.set(SchemaIdentity.currentAppVersion, forKey: PendingRestoreDefaultsKey.lastSuccessfulAppVersion)
    }

    private static func setPendingRestore(folderName: String, schemaIdentifier: String, defaults: UserDefaults) {
        defaults.set(folderName, forKey: PendingRestoreDefaultsKey.backupFolderName)
        defaults.set(schemaIdentifier, forKey: PendingRestoreDefaultsKey.recordedSchemaIdentifier)
    }

    private static func clearPendingRestore(defaults: UserDefaults) {
        defaults.removeObject(forKey: PendingRestoreDefaultsKey.backupFolderName)
        defaults.removeObject(forKey: PendingRestoreDefaultsKey.recordedSchemaIdentifier)
    }

    private static func protectedBackupFolderName(defaults: UserDefaults) -> String? {
        defaults.string(forKey: PendingRestoreDefaultsKey.backupFolderName)
    }
}

// MARK: - UI banner state

/// Small ObservableObject the app reads to show a one-time banner when a recovery
/// happened. The banner is dismissable; once dismissed for a given event token it
/// won't reappear on future launches for the same event.
@MainActor
final class StoreRecoveryAnnouncer: ObservableObject {
    @Published var visibleEvent: StoreBootstrapEvent?

    private let defaults: UserDefaults

    init(event: StoreBootstrapEvent, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        switch event {
        case .clean:
            self.visibleEvent = nil
        case .restoredFromBackup(let folderName, _):
            let token = "restored:\(folderName)"
            if defaults.string(forKey: PendingRestoreDefaultsKey.lastRestoredBannerToken) != token {
                self.visibleEvent = event
                defaults.set(token, forKey: PendingRestoreDefaultsKey.lastRestoredBannerToken)
            }
        case .pendingRestoreWaiting(let folderName, let recordedSchemaIdentifier):
            // Always show waiting state until it's resolved.
            self.visibleEvent = .pendingRestoreWaiting(folderName: folderName, recordedSchemaIdentifier: recordedSchemaIdentifier)
        case .fellBackToInMemory:
            self.visibleEvent = event
        }
    }

    func dismiss() {
        visibleEvent = nil
    }

    /// Localized headline shown in the banner.
    var bannerTitle: String? {
        switch visibleEvent {
        case .restoredFromBackup:
            return "Daten wiederhergestellt"
        case .pendingRestoreWaiting:
            return "Daten warten auf Wiederherstellung"
        case .fellBackToInMemory:
            return "Daten temporär nicht verfügbar"
        case .clean, .none:
            return nil
        }
    }

    /// Body text for the banner.
    var bannerMessage: String? {
        switch visibleEvent {
        case .restoredFromBackup(_, let createdAt):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Deine Daten wurden aus dem automatischen Backup vom \(formatter.string(from: createdAt)) wiederhergestellt."
        case .pendingRestoreWaiting:
            return "Wir konnten dein Backup nicht in dieser App-Version öffnen. Es bleibt sicher gespeichert und wird mit dem nächsten Update automatisch eingespielt."
        case .fellBackToInMemory:
            return "Wir konnten deine Datenbank gerade nicht laden. Deine Daten sind nicht verloren – schließe und öffne die App nach einem Update erneut."
        case .clean, .none:
            return nil
        }
    }
}
