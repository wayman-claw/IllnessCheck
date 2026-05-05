//
//  MonthCalendarView.swift
//  IllnessCheck / DayTrace
//
//  Apple-Health-style month calendar card. Each day cell renders a marker
//  based on what was logged that day, so the user gets an at-a-glance view
//  of "which days are done, how good were they". Tapping a day fires a
//  callback so the host view can open the entry editor for that date.
//

import SwiftUI

// MARK: - Day classification

/// What kind of marker to render in a calendar cell.
enum CalendarDayState: Equatable {
    /// No DailyEntry for this day. Whether the cell is "missed" or "future"
    /// is decided in the cell view based on the date itself.
    case empty
    /// A normal logged day.
    case logged
    /// Logged with a high mood (>=4) AND no symptoms.
    case good
    /// Logged with top mood (>=5), no symptoms, and decent hydration.
    case perfect

    var symbolName: String? {
        switch self {
        case .empty: return nil
        case .logged: return "star.fill"
        case .good: return "sparkles"
        case .perfect: return "crown.fill"
        }
    }

    var tint: Color {
        switch self {
        case .empty: return .secondary
        case .logged: return .yellow
        case .good: return .pink
        case .perfect: return .orange
        }
    }
}

extension CalendarDayState {
    /// Classify a single DailyEntry into a CalendarDayState.
    init(entry: DailyEntry) {
        let symptomFree = entry.symptoms.isEmpty
        let highMood = entry.moodScore >= 4
        let topMood = entry.moodScore >= 5
        let goodHydration = entry.overallHydration == .medium || entry.overallHydration == .much

        if topMood && symptomFree && goodHydration {
            self = .perfect
        } else if highMood && symptomFree {
            self = .good
        } else {
            self = .logged
        }
    }
}

// MARK: - The calendar card

struct MonthCalendarView: View {
    /// All entries the user has. The view filters down to the visible month.
    let entries: [DailyEntry]
    /// Called when the user taps a day cell. Receives the start-of-day date.
    var onSelectDay: (Date) -> Void

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: .now)

    private let calendar = Calendar.autoupdatingCurrent

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale.autoupdatingCurrent
        f.dateFormat = "LLLL yyyy"
        return f.string(from: displayedMonth).capitalized
    }

    private var weekdaySymbols: [String] {
        // Localized short weekday names, starting on the user's first weekday.
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstWeekday = calendar.firstWeekday  // 1 = Sunday
        // Rotate so symbols[0] matches firstWeekday.
        let rotated = Array(symbols[(firstWeekday - 1)...]) + Array(symbols[..<(firstWeekday - 1)])
        return rotated
    }

    /// Days to render in the grid. Includes leading/trailing days from
    /// adjacent months so the grid is always a full set of weeks.
    private var gridDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDayOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // Number of "padding" days before the 1st (so column count matches firstWeekday).
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: firstDayOfMonth) else { return [] }

        var days: [Date] = []
        // Always render 6 weeks * 7 days = 42 cells. Keeps the grid height stable.
        for i in 0..<42 {
            if let d = calendar.date(byAdding: .day, value: i, to: gridStart) {
                days.append(calendar.startOfDay(for: d))
            }
        }
        return days
    }

    /// Lookup table date -> entry for fast cell rendering.
    private var entryByDay: [Date: DailyEntry] {
        var dict: [Date: DailyEntry] = [:]
        for entry in entries {
            dict[calendar.startOfDay(for: entry.date)] = entry
        }
        return dict
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(gridDays, id: \.self) { day in
                    CalendarDayCell(
                        date: day,
                        isInDisplayedMonth: calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month),
                        isToday: calendar.isDateInToday(day),
                        state: entryByDay[day].map(CalendarDayState.init(entry:)) ?? .empty,
                        symptomMarkers: SymptomMarker.makeMarkers(for: entryByDay[day])
                    )
                    .onTapGesture { onSelectDay(day) }
                }
            }

            legend
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.systemBackground), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(monthLabel)
                    .font(.headline)
                if !calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month) {
                    Button("Heute") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            displayedMonth = calendar.startOfMonth(for: .now)
                        }
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.systemBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isAtCurrentOrFutureMonth)
            .opacity(isAtCurrentOrFutureMonth ? 0.35 : 1)
        }
    }

    private var isAtCurrentOrFutureMonth: Bool {
        // Disallow navigating into the future — there's nothing to log there yet.
        guard let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return true }
        return next > calendar.startOfMonth(for: .now)
    }

    private func shiftMonth(by delta: Int) {
        guard let new = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            displayedMonth = calendar.startOfMonth(for: new)
        }
    }

    // MARK: Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                LegendDot(state: .logged, label: "Erfasst")
                LegendDot(state: .good, label: "Guter Tag")
                LegendDot(state: .perfect, label: "Top-Tag")
                Spacer()
            }

            // Show a compact symptom legend if any symptoms are present
            // in the currently displayed entries — otherwise stay quiet.
            if !visibleSymptomMarkers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(visibleSymptomMarkers) { marker in
                            HStack(spacing: 4) {
                                SymptomMarkerDot(marker: marker)
                                Text(marker.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    /// Distinct symptom markers across the entries currently shown in the grid,
    /// so the legend reflects what the user actually sees this month.
    private var visibleSymptomMarkers: [SymptomMarker] {
        var seen = Set<String>()
        var result: [SymptomMarker] = []
        let visibleEntries = entries.filter { entry in
            calendar.isDate(entry.date, equalTo: displayedMonth, toGranularity: .month)
        }
        for entry in visibleEntries {
            for marker in SymptomMarker.makeMarkers(for: entry) {
                if seen.contains(marker.id) { continue }
                seen.insert(marker.id)
                result.append(marker)
            }
        }
        return result
    }
}

// MARK: - Day cell

private struct CalendarDayCell: View {
    let date: Date
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let state: CalendarDayState
    let symptomMarkers: [SymptomMarker]

    /// Maximum number of symptom dots we render before collapsing the rest into a +N pill.
    private static let maxVisibleMarkers = 3

    private var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private var visibleMarkers: [SymptomMarker] {
        Array(symptomMarkers.prefix(Self.maxVisibleMarkers))
    }

    private var hiddenMarkerCount: Int {
        max(0, symptomMarkers.count - Self.maxVisibleMarkers)
    }

    var body: some View {
        ZStack {
            // Background tile
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor, lineWidth: isToday ? 1.6 : 0)
                )

            VStack(spacing: 3) {
                Text(dayNumber)
                    .font(.caption.weight(isToday ? .bold : .medium))
                    .foregroundStyle(numberColor)

                if let symbol = state.symbolName {
                    Image(systemName: symbol)
                        .font(.caption2)
                        .foregroundStyle(state.tint)
                        .symbolRenderingMode(.hierarchical)
                } else {
                    // Reserve space so cells with/without symbol have same height.
                    Color.clear.frame(height: 12)
                }

                // Symptom marker row
                if symptomMarkers.isEmpty {
                    Color.clear.frame(height: 8)
                } else {
                    HStack(spacing: 2) {
                        ForEach(visibleMarkers) { marker in
                            SymptomMarkerDot(marker: marker)
                        }
                        if hiddenMarkerCount > 0 {
                            Text("+\(hiddenMarkerCount)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(.vertical, 4)
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(isInDisplayedMonth ? 1 : 0.32)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundFill: Color {
        if isToday { return Color.accentColor.opacity(0.12) }
        return Color(.systemBackground)
    }

    private var borderColor: Color {
        isToday ? .accentColor : .clear
    }

    private var numberColor: Color {
        if isToday { return .accentColor }
        return isInDisplayedMonth ? .primary : .secondary
    }

    private var accessibilityLabel: String {
        let dateText = date.formatted(date: .complete, time: .omitted)
        let stateDescription: String
        switch state {
        case .empty: stateDescription = "keine Eintragung"
        case .logged: stateDescription = "erfasst"
        case .good: stateDescription = "guter Tag"
        case .perfect: stateDescription = "Top-Tag"
        }
        if symptomMarkers.isEmpty {
            return "\(dateText), \(stateDescription)"
        }
        let symptomList = symptomMarkers.map(\.displayName).joined(separator: ", ")
        return "\(dateText), \(stateDescription), Symptome: \(symptomList)"
    }
}

// MARK: - Symptom markers

/// One symptom indicator rendered inside a calendar cell. We dedupe by slug
/// (each category counts once per day even if logged multiple times) and keep
/// a stable visual identity (color + symbol) that is consistent across days.
struct SymptomMarker: Identifiable, Equatable {
    /// We use the slug as id so the same symptom on different days keeps the
    /// same SwiftUI identity, which makes for nicer diffing/animations.
    let id: String        // == slug
    let symbolName: String
    let displayName: String
    let tint: Color

    /// Build markers from a DailyEntry, deduped by slug, ordered by
    /// the entry's symptom order (so it's stable across renders).
    static func makeMarkers(for entry: DailyEntry?) -> [SymptomMarker] {
        guard let entry, !entry.symptoms.isEmpty else { return [] }
        var seen = Set<String>()
        var result: [SymptomMarker] = []
        for symptom in entry.symptoms {
            let slug = symptom.analyticsKey
            if seen.contains(slug) { continue }
            seen.insert(slug)
            result.append(SymptomMarker(
                id: slug,
                symbolName: symptom.category?.symbolName ?? "cross.case.fill",
                displayName: symptom.displayName,
                tint: SymptomMarker.tint(forSlug: slug)
            ))
        }
        return result
    }

    /// Deterministic, stable color per slug. Built-in slugs get curated colors;
    /// everything else falls back to a hash-based pick from the same palette so
    /// user-added categories stay visually distinct from each other.
    static func tint(forSlug slug: String) -> Color {
        if let curated = curatedTint[slug] { return curated }
        let palette: [Color] = [.red, .orange, .yellow, .green, .mint, .teal, .blue, .indigo, .purple, .pink, .brown]
        // Stable hash: sum of unicode scalars mod palette count. Avoids
        // String.hashValue which is randomized per process launch.
        let h = slug.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(h) % palette.count]
    }

    /// Curated colors for the built-in symptom presets so they always look
    /// the same and feel intuitive (e.g. red for headache).
    private static let curatedTint: [String: Color] = [
        "kopfschmerzen": .red,
        "bauchschmerzen": .orange,
        "ubelkeit": .green,
        "mudigkeit": .indigo,
        "halsschmerzen": .pink,
        "ruckenschmerzen": .brown
    ]
}

private struct SymptomMarkerDot: View {
    let marker: SymptomMarker

    var body: some View {
        ZStack {
            Circle()
                .fill(marker.tint.opacity(0.22))
            Image(systemName: marker.symbolName)
                .font(.system(size: 5, weight: .bold))
                .foregroundStyle(marker.tint)
        }
        .frame(width: 9, height: 9)
        .accessibilityHidden(true) // already covered by the cell's accessibilityLabel
    }
}

// MARK: - Legend dot

private struct LegendDot: View {
    let state: CalendarDayState
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            if let symbol = state.symbolName {
                Image(systemName: symbol)
                    .font(.caption2)
                    .foregroundStyle(state.tint)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Calendar helpers

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
