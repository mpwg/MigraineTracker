import SwiftUI

struct HistoryView: View {
    let appContainer: AppContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var controller: HistoryController

    init(appContainer: AppContainer) {
        self.appContainer = appContainer
        _controller = State(initialValue: appContainer.makeHistoryController())
    }

    var body: some View {
        ScrollView {
            if horizontalSizeClass == .compact {
                compactContent
            } else {
                regularContent
            }
        }
        .background(AppTheme.appBackground.ignoresSafeArea())
        .tint(AppTheme.ocean)
        .navigationTitle("Tagebuch")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    DataExportView(appContainer: appContainer)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    controller.isPresentingNewEpisode = true
                } label: {
                    Label("Neuer Eintrag", systemImage: "plus.circle.fill")
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    controller.isPresentingSettings = true
                } label: {
                    Label("Einstellungen", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $controller.isPresentingNewEpisode) {
            NavigationStack {
                EpisodeEditorView(
                    appContainer: appContainer,
                    initialStartedAt: controller.defaultStartDateForSelectedDay(),
                    onSaved: {
                        controller.isPresentingNewEpisode = false
                        controller.handleSavedEpisode()
                    }
                )
            }
        }
        .sheet(isPresented: $controller.isPresentingSettings) {
            NavigationStack {
                SettingsView(appContainer: appContainer)
            }
        }
        .sheet(item: editingEpisodeBinding) { episodeID in
            NavigationStack {
                EpisodeEditorView(
                    appContainer: appContainer,
                    episodeID: episodeID.id,
                    onSaved: {
                        controller.editingEpisodeID = nil
                        controller.handleSavedEpisode()
                    }
                )
            }
        }
        .confirmationDialog(
            "Eintrag löschen?",
            isPresented: Binding(
                get: { controller.pendingDeletionID != nil },
                set: { isPresented in
                    if !isPresented {
                        controller.pendingDeletionID = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: pendingEpisode
        ) { episode in
            Button("Bearbeiten") {
                controller.editingEpisodeID = episode.id
            }

            Button("Löschen", role: .destructive) {
                controller.deletePendingEpisode()
            }

            Button("Abbrechen", role: .cancel) {
                controller.pendingDeletionID = nil
            }
        } message: { episode in
            Text("\(episode.startedAt.formatted(date: .abbreviated, time: .shortened)) wird in den Papierkorb verschoben.")
        }
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            insightSection
            calendarSection

            Button {
                controller.isPresentingNewEpisode = true
            } label: {
                Text("Eintrag erstellen")
            }
            .buttonStyle(SymiPrimaryButtonStyle())
            .accessibilityHint("Öffnet einen neuen Tagebuch-Eintrag mit dem aktuell ausgewählten Kalendertag.")

            selectedDaySection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    private var regularContent: some View {
        HStack(alignment: .top, spacing: AppTheme.dashboardSpacing) {
            VStack(alignment: .leading, spacing: AppTheme.dashboardSpacing) {
                insightSection
                calendarSection
            }
            .frame(minWidth: 420, maxWidth: 560, alignment: .top)

            selectedDaySection
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .padding(24)
        .wideContent()
    }

    private var calendarSection: some View {
        contentSection(
            title: "Kalender",
            footer: "Weiche Punkte zeigen Tage mit Einträgen. Wähle einen Tag, um Details zu sehen."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                MonthHeader(
                    month: controller.displayedMonth,
                    onPrevious: controller.goToPreviousMonth,
                    onNext: controller.goToNextMonth
                )

                MonthGrid(
                    month: controller.displayedMonth,
                    selectedDay: Binding(
                        get: { controller.selectedDay },
                        set: { controller.selectDay($0) }
                    ),
                    episodesByDay: controller.episodesByDay
                )
            }
        }
    }

    private var insightSection: some View {
        contentSection(title: "Verstehen") {
            VStack(alignment: .leading, spacing: 14) {
                Text(insightTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.symiPetrol)
                Text(insightDetail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.symiTextSecondary)

                Picker("Zeitraum", selection: .constant("Woche")) {
                    Text("Woche").tag("Woche")
                    Text("Monat").tag("Monat")
                }
                .pickerStyle(.segmented)

                SoftTrendChart(values: recentIntensityValues)
                    .frame(height: 88)
                    .accessibilityLabel("Sanfte Verlaufsgrafik deiner letzten Einträge")
            }
        }
    }

    private var selectedDaySection: some View {
        contentSection(title: "Ausgewählter Tag") {
            VStack(alignment: .leading, spacing: 12) {
                daySummary

                if controller.selectedDayEpisodes.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Einträge an diesem Tag",
                        systemImage: "calendar",
                        description: Text("Für \(controller.selectedDay.formatted(date: .complete, time: .omitted)) ist noch nichts dokumentiert.")
                    )
                } else {
                    ForEach(controller.selectedDayEpisodes) { episode in
                        episodeLink(for: episode)
                    }
                }
            }
        }
    }

    private var editingEpisodeBinding: Binding<IdentifiedEpisodeID?> {
        Binding(
            get: { controller.editingEpisodeID.map(IdentifiedEpisodeID.init) },
            set: { controller.editingEpisodeID = $0?.id }
        )
    }

    private var pendingEpisode: EpisodeRecord? {
        guard let id = controller.pendingDeletionID else {
            return nil
        }

        return controller.selectedDayEpisodes.first(where: { $0.id == id })
    }

    @ViewBuilder
    private func contentSection<Content: View>(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var daySummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(controller.daySummary.date.formatted(date: .complete, time: .omitted))
                .font(.headline)

            if controller.daySummary.episodeCount == 0 {
                Text("Noch kein Eintrag für diesen Tag.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(controller.daySummary.episodeCount) Eintrag\(controller.daySummary.episodeCount == 1 ? "" : "e") · Höchste Intensität \(controller.daySummary.highestIntensity)/10")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var insightTitle: String {
        controller.daySummary.episodeCount == 0 ? "Mehr gute Tage beginnen mit Überblick." : "Wir sehen ein Muster."
    }

    private var insightDetail: String {
        if controller.daySummary.episodeCount == 0 {
            return "Noch kein Eintrag an diesem Tag. Deine nächsten Notizen machen den Kalender hilfreicher."
        }

        return "\(controller.daySummary.episodeCount) Eintrag\(controller.daySummary.episodeCount == 1 ? "" : "e") an diesem Tag, höchste Intensität \(controller.daySummary.highestIntensity)/10."
    }

    private var recentIntensityValues: [Int] {
        let values = controller.selectedDayEpisodes.map(\.intensity)
        return values.isEmpty ? [2, 4, 3, 6, 4, 5, 3] : values
    }

    @ViewBuilder
    private func episodeLink(for episode: EpisodeRecord) -> some View {
        NavigationLink {
            EpisodeDetailView(appContainer: appContainer, episodeID: episode.id)
        } label: {
            EpisodeRow(episode: episode)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Löschen", role: .destructive) {
                controller.pendingDeletionID = episode.id
            }

            Button("Bearbeiten") {
                controller.editingEpisodeID = episode.id
            }
            .tint(.accentColor)
        }
        .contextMenu {
            Button("Bearbeiten", systemImage: "pencil") {
                controller.editingEpisodeID = episode.id
            }

            Button("Löschen", systemImage: "trash", role: .destructive) {
                controller.pendingDeletionID = episode.id
            }
        }
    }
}

private struct EpisodeRow: View {
    let episode: EpisodeRecord

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
        .accessibilityHint("Öffnet die Detailansicht des Eintrags.")
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
            .padding(10)
            .background(AppTheme.secondaryFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("Vorheriger Monat")

            Spacer()

            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
            .padding(10)
            .background(AppTheme.secondaryFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("Nächster Monat")
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

private struct MonthGrid: View {
    let month: Date
    @Binding var selectedDay: Date
    let episodesByDay: [Date: [EpisodeRecord]]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, cell in
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
                Circle()
                    .fill(intensityColor)
                    .frame(width: 9, height: 9)
            } else {
                Spacer()
                    .frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(.vertical, 6)
        .background(isSelected ? AppTheme.selectedFill : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
        .accessibilityHint("Zeigt die Episoden dieses Tages darunter an.")
    }

    private var intensityColor: Color {
        switch peakIntensity {
        case 8...10: AppTheme.symiCoral
        case 5...7: AppTheme.symiSage
        default: AppTheme.seaGlass
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

private struct SoftTrendChart: View {
    let values: [Int]

    var body: some View {
        GeometryReader { proxy in
            let points = chartPoints(in: proxy.size)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.symiSage.opacity(0.16))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(AppTheme.symiPetrol, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(AppTheme.symiCard)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(AppTheme.symiPetrol, lineWidth: 2))
                        .position(point)
                }
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else {
            return [CGPoint(x: size.width / 2, y: size.height / 2)]
        }

        let maxValue = max(values.max() ?? 10, 10)
        return values.enumerated().map { index, value in
            let progressX = CGFloat(index) / CGFloat(values.count - 1)
            let progressY = CGFloat(value) / CGFloat(maxValue)
            return CGPoint(
                x: progressX * size.width,
                y: size.height - (progressY * (size.height - 18)) - 9
            )
        }
    }
}

private struct IdentifiedEpisodeID: Identifiable {
    let id: UUID
}

extension Calendar {
    nonisolated func startOfMonth(for inputDate: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: inputDate)) ?? inputDate
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
