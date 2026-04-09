import SwiftData
import SwiftUI

struct HistoryView: View {
    private enum HistoryMode: String, CaseIterable, Identifiable {
        case list = "Liste"
        case calendar = "Kalender"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Episode.startedAt, order: .reverse)]) private var episodes: [Episode]
    @State private var mode: HistoryMode = .list
    @State private var selectedDay: Date = .now
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: .now)

    var body: some View {
        List {
            if episodes.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Noch keine Episoden",
                        systemImage: "calendar.badge.plus",
                        description: Text("Lege zuerst eine Episode an, um den Verlauf aufzubauen.")
                    )
                }
            } else {
                Section {
                    Picker("Ansicht", selection: $mode) {
                        ForEach(HistoryMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .list {
                    Section("Letzte Episoden") {
                        ForEach(episodes) { episode in
                            episodeLink(for: episode)
                        }
                        .onDelete(perform: deleteEpisodes)
                    }
                } else {
                    Section {
                        MonthHeader(
                            month: displayedMonth,
                            onPrevious: { displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth },
                            onNext: { displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth }
                        )

                        MonthGrid(
                            month: displayedMonth,
                            selectedDay: $selectedDay,
                            episodesByDay: episodesByDay
                        )
                    } header: {
                        Text("Kalender")
                    } footer: {
                        Text("Wähle einen Tag, um die dokumentierten Episoden direkt darunter zu sehen.")
                    }

                    Section("Ausgewählter Tag") {
                        if episodesForSelectedDay.isEmpty {
                            ContentUnavailableView(
                                "Keine Episoden an diesem Tag",
                                systemImage: "calendar",
                                description: Text("Für \(selectedDay.formatted(date: .complete, time: .omitted)) sind keine Episoden gespeichert.")
                            )
                        } else {
                            ForEach(episodesForSelectedDay) { episode in
                                episodeLink(for: episode)
                            }
                            .onDelete(perform: deleteEpisodesForSelectedDay)
                        }
                    }
                }
            }
        }
        .navigationTitle("Verlauf")
    }

    private var episodesByDay: [Date: [Episode]] {
        Dictionary(grouping: episodes) { Calendar.current.startOfDay(for: $0.startedAt) }
    }

    private var episodesForSelectedDay: [Episode] {
        let day = Calendar.current.startOfDay(for: selectedDay)
        return (episodesByDay[day] ?? []).sorted { $0.startedAt > $1.startedAt }
    }

    @ViewBuilder
    private func episodeLink(for episode: Episode) -> some View {
        NavigationLink {
            EpisodeDetailView(episode: episode)
        } label: {
            EpisodeRow(episode: episode)
        }
    }

    private func deleteEpisodes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(episodes[index])
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Löschen fehlgeschlagen: \(error)")
        }
    }

    private func deleteEpisodesForSelectedDay(at offsets: IndexSet) {
        let dayEpisodes = episodesForSelectedDay

        for index in offsets {
            modelContext.delete(dayEpisodes[index])
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Löschen fehlgeschlagen: \(error)")
        }
    }
}

private struct EpisodeRow: View {
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(episode.startedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)

            Text(episode.startedAt.formatted(date: .omitted, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(episode.type.rawValue) · Intensität \(episode.intensity)/10")
                .foregroundStyle(.secondary)

            if !episode.medications.isEmpty || !episode.symptoms.isEmpty {
                Text(episodeMetaLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Öffnet die Detailansicht der Episode.")
    }

    private var episodeMetaLine: String {
        var parts: [String] = []

        if !episode.medications.isEmpty {
            parts.append("\(episode.medications.count) Medikament(e)")
        }

        if !episode.symptoms.isEmpty {
            parts.append(episode.symptoms.joined(separator: ", "))
        }

        return parts.joined(separator: " · ")
    }

    private var accessibilitySummary: String {
        var parts = [
            episode.startedAt.formatted(date: .complete, time: .shortened),
            episode.type.rawValue,
            "Intensität \(episode.intensity) von 10"
        ]

        if !episodeMetaLine.isEmpty {
            parts.append(episodeMetaLine)
        }

        return parts.joined(separator: ", ")
    }
}

private struct MonthHeader: View {
    let month: Date
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Vorheriger Monat")

            Spacer()

            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Nächster Monat")
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

private struct MonthGrid: View {
    let month: Date
    @Binding var selectedDay: Date
    let episodesByDay: [Date: [Episode]]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ForEach(dayCells) { cell in
                    if let date = cell.date {
                        Button {
                            selectedDay = date
                        } label: {
                            DayCell(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDay),
                                episodeCount: episodesByDay[Calendar.current.startOfDay(for: date)]?.count ?? 0,
                                peakIntensity: episodesByDay[Calendar.current.startOfDay(for: date)]?.map(\.intensity).max() ?? 0
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var dayCells: [CalendarDay] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: month)
        let range = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1 ..< 1
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let leadingEmptyDays = (weekday - calendar.firstWeekday + 7) % 7

        var cells = Array(repeating: CalendarDay(date: nil), count: leadingEmptyDays)
        cells += range.compactMap { day -> CalendarDay? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else {
                return nil
            }
            return CalendarDay(date: date)
        }

        while cells.count % 7 != 0 {
            cells.append(CalendarDay(date: nil))
        }

        return cells
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let episodeCount: Int
    let peakIntensity: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.day()))
                .font(.subheadline.weight(.semibold))

            if episodeCount > 0 {
                Text("\(episodeCount)x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Circle()
                    .fill(intensityColor)
                    .frame(width: 8, height: 8)
            } else {
                Spacer()
                    .frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
        .accessibilityHint("Zeigt die Episoden dieses Tages darunter an.")
    }

    private var intensityColor: Color {
        switch peakIntensity {
        case 8...10: .red
        case 5...7: .orange
        default: .yellow
        }
    }

    private var accessibilityLabel: String {
        if episodeCount == 0 {
            return "\(date.formatted(date: .complete, time: .omitted)), keine Episoden"
        }

        return "\(date.formatted(date: .complete, time: .omitted)), \(episodeCount) Episode\(episodeCount == 1 ? "" : "n"), höchste Intensität \(peakIntensity) von 10"
    }
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
}

private extension Calendar {
    func startOfMonth(for inputDate: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: inputDate)) ?? inputDate
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
