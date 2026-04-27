import SwiftUI

struct HomeView: View {
    let appContainer: AppContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var displayedMonth = Calendar.current.startOfMonth(for: .now)
    @State private var calendarMonthData = HistoryMonthData(month: Calendar.current.startOfMonth(for: .now), episodesByDay: [:])
    @State private var patternPreviewData = HomePatternPreviewData(totalPainEpisodeCount: 0, cards: [])
    @State private var quickEntryIntensity = 5
    @State private var isPresentingEpisodeEditor = false

    init(appContainer: AppContainer) {
        self.appContainer = appContainer
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactDashboard
            } else {
                regularDashboard
            }
        }
        .navigationTitle(ProductBranding.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: displayedMonth) {
            await reloadAll()
        }
        .refreshable {
            await reloadAll()
        }
        .fullScreenCover(isPresented: $isPresentingEpisodeEditor) {
            EntryFlowCoordinatorView(appContainer: appContainer, initialStartedAt: .now) {
                isPresentingEpisodeEditor = false
                Task { await reloadAll() }
            }
        }
    }

    private var compactDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.zero) {
                HomeHeaderView()
                    .padding(.bottom, SymiSpacing.lg)

                PainGaugeView(value: $quickEntryIntensity)
                    .padding(.bottom, SymiSpacing.lg)

                PrimaryEntryButton {
                    isPresentingEpisodeEditor = true
                }
                .padding(.bottom, SymiSpacing.lg)

                HomeAllEntriesLink(appContainer: appContainer)
                    .padding(.bottom, SymiSpacing.lg)

                HomeMonthCalendarView(
                    month: displayedMonth,
                    episodesByDay: calendarMonthData.episodesByDay,
                    onPrevious: showPreviousMonth,
                    onNext: showNextMonth
                )
                    .padding(.bottom, SymiSpacing.lg)

                HomePatternPreviewSection(data: patternPreviewData) {
                    InsightsView(appContainer: appContainer)
                }
                .padding(.bottom, SymiSpacing.xxxl + SymiSpacing.xxs)
            }
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.vertical, SymiSpacing.xl)
        }
        .homeScreen()
    }

    private var regularDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.zero) {
                HomeHeaderView()
                    .padding(.bottom, SymiSpacing.lg)

                PainGaugeView(value: $quickEntryIntensity)
                    .padding(.bottom, SymiSpacing.lg)

                PrimaryEntryButton {
                    isPresentingEpisodeEditor = true
                }
                .padding(.bottom, SymiSpacing.lg)

                HomeMonthCalendarView(
                    month: displayedMonth,
                    episodesByDay: calendarMonthData.episodesByDay,
                    onPrevious: showPreviousMonth,
                    onNext: showNextMonth
                )
                    .padding(.bottom, SymiSpacing.lg)

                HomeAllEntriesLink(appContainer: appContainer)
                    .padding(.bottom, SymiSpacing.lg)

                HomePatternPreviewSection(data: patternPreviewData) {
                    InsightsView(appContainer: appContainer)
                }
                .padding(.bottom, SymiSpacing.xxxl + SymiSpacing.xxs)
            }
            .padding(SymiSpacing.xxxl)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
        }
        .homeScreen()
        .refreshable {
            await reloadAll()
        }
    }

    private func reloadAll() async {
        await reloadCalendarMonth()
        await reloadPatternPreview()
    }

    private func reloadCalendarMonth() async {
        let month = displayedMonth
        calendarMonthData = (try? await LoadHistoryMonthUseCase(repository: appContainer.episodeRepository).execute(month: month)) ?? HistoryMonthData(month: month, episodesByDay: [:])
    }

    private func reloadPatternPreview() async {
        patternPreviewData = (try? await LoadHomePatternPreviewUseCase(
            repository: appContainer.episodeRepository,
            insightEngine: appContainer.insightEngine
        ).execute()) ?? HomePatternPreviewData(totalPainEpisodeCount: 0, cards: [])
    }

    private func showPreviousMonth() {
        showMonth(offset: -1)
    }

    private func showNextMonth() {
        showMonth(offset: 1)
    }

    private func showMonth(offset: Int) {
        let calendar = Calendar.current
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else {
            return
        }

        displayedMonth = newMonth
    }

}

private struct HomeMonthCalendarView: View {
    let month: Date
    let episodesByDay: [Date: [EpisodeRecord]]
    let onPrevious: () -> Void
    let onNext: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SymiSpacing.compact), count: 7)
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.compact) {
            HStack(alignment: .center, spacing: SymiSpacing.xs) {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.petrol(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(SymiTypography.compactScaleFactor)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: SymiSpacing.xs)

                HStack(spacing: SymiSpacing.xs) {
                    calendarNavigationButton(systemImage: "chevron.left", label: "Vorheriger Monat", action: onPrevious)
                    calendarNavigationButton(systemImage: "chevron.right", label: "Nächster Monat", action: onNext)
                }
            }

            LazyVGrid(columns: columns, spacing: SymiSpacing.xxs) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme).opacity(SymiOpacity.disabledContent))
                        .frame(maxWidth: .infinity, minHeight: SymiSize.homeCalendarWeekdayHeight)
                        .accessibilityHidden(true)
                }

                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, cell in
                    if let date = cell.date {
                        HomeCalendarDayCell(
                            date: date,
                            isToday: calendar.isDateInToday(date),
                            entries: episodesByDay[calendar.startOfDay(for: date)] ?? []
                        )
                    } else {
                        Color.clear
                            .frame(height: SymiSize.calendarWeekdayHeight)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.horizontal, SymiSpacing.xxs)
        .padding(.vertical, SymiSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Monatskalender \(month.formatted(.dateTime.month(.wide).year()))")
        .accessibilityIdentifier("home-calendar")
    }

    private func calendarNavigationButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.petrol(for: colorScheme))
                .frame(width: SymiSize.minInteractiveHeight + 2, height: SymiSize.minInteractiveHeight + 2)
                .background(AppTheme.sage(for: colorScheme).opacity(SymiOpacity.faintSurface), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint("Wechselt den angezeigten Monat im Home-Kalender.")
        .accessibilityIdentifier(label == "Vorheriger Monat" ? "home-calendar-previous-month" : "home-calendar-next-month")
    }

    private var weekdaySymbols: [String] {
        ["MO", "DI", "MI", "DO", "FR", "SA", "SO"]
    }

    private var dayCells: [HomeCalendarDay] {
        let startOfMonth = calendar.startOfMonth(for: month)
        let range = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1 ..< 1
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let leadingEmptyDays = (weekday + 5) % 7

        var cells = Array(repeating: HomeCalendarDay(date: nil), count: leadingEmptyDays)
        cells += range.compactMap { day -> HomeCalendarDay? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else {
                return nil
            }
            return HomeCalendarDay(date: date)
        }

        while cells.count < 42 {
            cells.append(HomeCalendarDay(date: nil))
        }

        return cells
    }
}

private struct HomeCalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let entries: [EpisodeRecord]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: SymiSpacing.xxs) {
            Text(date.formatted(.dateTime.day()))
                .font(dayNumberFont)
                .foregroundStyle(dayTextColor)
                .frame(width: dayNumberSize, height: dayNumberSize)
                .background(isToday ? AppTheme.petrol(for: colorScheme) : Color.clear, in: Circle())

            if entries.isEmpty {
                Circle()
                    .fill(Color.clear)
                    .frame(width: calendarDotSize, height: calendarDotSize)
                    .frame(maxWidth: .infinity, minHeight: calendarDotRowHeight, alignment: .center)
            } else {
                HStack(spacing: SymiSpacing.micro) {
                    ForEach(Array(entries.prefix(3).enumerated()), id: \.element.id) { _, entry in
                        Circle()
                            .fill(dotColor(for: entry))
                            .frame(width: calendarDotSize, height: calendarDotSize)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: calendarDotRowHeight, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: calendarDayMinHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("home-calendar-day-\(date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))")
    }

    private func dotColor(for entry: EpisodeRecord) -> Color {
        switch entry.intensity {
        case 8 ... 10:
            AppTheme.coral(for: colorScheme).opacity(SymiOpacity.calendarHighIntensityDot)
        case 5 ... 7:
            AppTheme.sage(for: colorScheme).opacity(SymiOpacity.calendarMediumIntensityDot)
        default:
            AppTheme.petrol(for: colorScheme).opacity(SymiOpacity.calendarLowIntensityDot)
        }
    }

    private var dayTextColor: Color {
        if isToday {
            return AppTheme.symiOnAccent
        }

        return AppTheme.textPrimary(for: colorScheme).opacity(SymiOpacity.calendarInactiveDayText)
    }

    private var dayNumberFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .body.weight(isToday ? .semibold : .regular) : .body.weight(isToday ? .semibold : .regular)
    }

    private var dayNumberSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? SymiSize.homeCalendarDayNumber + SymiSize.homeCalendarAccessibilityGrowth : SymiSize.homeCalendarDayNumber
    }

    private var calendarDayMinHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? SymiSize.calendarDayMinHeight + SymiSize.homeCalendarDayAccessibilityGrowth : SymiSize.calendarDayMinHeight - SymiSpacing.xs
    }

    private var calendarDotSize: CGFloat {
        max(6, SymiSize.calendarDot - 2)
    }

    private var calendarDotRowHeight: CGFloat {
        calendarDotSize
    }

    private var accessibilityLabel: String {
        let dateText = date.formatted(date: .complete, time: .omitted)
        let stateText = isToday ? "heute" : "Kalendertag"

        guard entries.isEmpty == false else {
            return "\(dateText), \(stateText), keine Einträge"
        }

        let entryText = "\(entries.count) Eintrag\(entries.count == 1 ? "" : "e")"
        let highestIntensity = entries.map(\.intensity).max() ?? 0
        return "\(dateText), \(stateText), \(entryText), höchste Intensität \(highestIntensity) von 10"
    }
}

private struct HomeHeaderView: View {
    var body: some View {
        Image("HomeBrandLogo")
            .resizable()
            .scaledToFit()
            .frame(width: SymiSize.homeBrandLogoWidth, height: SymiSize.homeBrandLogoHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(ProductBranding.displayName)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct PrimaryEntryButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: SymiSpacing.md) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.symiOnAccent)
                    .frame(width: SymiSize.homeQuickEntryIcon, height: SymiSize.homeQuickEntryIcon)
                    .background(AppTheme.coral(for: colorScheme), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                    Text("Neuer Eintrag")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.symiOnAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(SymiTypography.buttonScaleFactor)

                    Text("Starte einen neuen Eintrag")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.symiOnAccent.opacity(SymiOpacity.heroSecondaryWave))
                        .lineLimit(1)
                        .minimumScaleFactor(SymiTypography.compactScaleFactor)
                }

                Spacer(minLength: SymiSpacing.xs)
            }
            .padding(.horizontal, SymiSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: SymiSize.homeQuickEntryButtonMinHeight, alignment: .leading)
        }
        .buttonStyle(HomePrimaryActionButtonStyle(colorScheme: colorScheme))
        .keyboardShortcut("n", modifiers: .command)
        .hoverEffect(.highlight)
        .accessibilityIdentifier("home-quick-entry")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Neuer Eintrag")
        .accessibilityHint("Startet einen neuen Eintrag.")
    }
}

private struct HomeAllEntriesLink: View {
    let appContainer: AppContainer
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationLink {
            HistoryView(appContainer: appContainer)
        } label: {
            HStack(spacing: SymiSpacing.sm) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.petrol(for: colorScheme))
                    .accessibilityHidden(true)

                Text("Alle Einträge")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.petrol(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(SymiTypography.buttonScaleFactor)

                Spacer(minLength: SymiSpacing.xs)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, SymiSpacing.md)
            .frame(maxWidth: .infinity, minHeight: SymiSize.minInteractiveHeight, alignment: .leading)
            .background(
                AppTheme.sage(for: colorScheme).opacity(SymiOpacity.faintSurface),
                in: RoundedRectangle(cornerRadius: SymiRadius.button, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-all-entries")
        .accessibilityHint("Öffnet die Liste aller Einträge.")
    }
}

private struct HomeCalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
}

private struct HomePatternPreviewSection<Destination: View>: View {
    let data: HomePatternPreviewData
    @ViewBuilder let destination: Destination

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: SymiSpacing.md) {
                Text("Deine Muster")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: SymiSpacing.sm)

                NavigationLink {
                    destination
                } label: {
                    Label("Mehr ansehen", systemImage: "chevron.right")
                        .labelStyle(.titleOnly)
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityHint("Öffnet die Insights-Ansicht.")
                .accessibilityIdentifier("home-patterns-show-more")
            }

            if data.hasEnoughData, !data.cards.isEmpty {
                VStack(alignment: .leading, spacing: SymiSpacing.md) {
                    ForEach(Array(data.cards.prefix(2))) { card in
                        HomePatternCard(card: card)
                    }
                }
            } else {
                HomePatternEmptyState(recordedCount: data.totalPainEpisodeCount, emptyState: data.emptyState)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("home-patterns-section")
    }
}

private struct HomePatternCard: View {
    let card: HomePatternPreviewCard
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xs) {
            Image(systemName: card.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.petrol(for: colorScheme))
                .frame(width: patternIconSize, height: patternIconSize)
                .background(AppTheme.secondaryFill(for: colorScheme), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                Text(card.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                    .textCase(.uppercase)

                Text(card.value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                    .lineLimit(2)
                    .minimumScaleFactor(SymiTypography.compactScaleFactor)
            }

            Text(card.detail)
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SymiSpacing.md)
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
        .homeSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.title), \(card.value). \(card.detail)")
        .accessibilityIdentifier("home-pattern-card-\(card.title)")
    }

    private var cardMinHeight: CGFloat {
        let baseHeight = card.isWide ? SymiSize.homePatternWideMinHeight : SymiSize.homePatternMinHeight
        let refinedHeight = baseHeight - SymiSpacing.md
        return dynamicTypeSize.isAccessibilitySize ? refinedHeight + SymiSize.homePatternAccessibilityHeightGrowth : refinedHeight
    }

    private var patternIconSize: CGFloat {
        SymiSize.homePatternIcon - SymiSpacing.xxs
    }
}

private struct HomePatternEmptyState: View {
    let recordedCount: Int
    let emptyState: InsightEmptyState?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: SymiSpacing.md) {
            Image(systemName: "sparkles")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.coral(for: colorScheme))
                .frame(width: emptyIconSize, height: emptyIconSize)
                .background(AppTheme.coral(for: colorScheme).opacity(SymiOpacity.clearAccent), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                Text(emptyStateText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SymiSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeSurface()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home-patterns-empty-state")
    }

    private var emptyStateText: String {
        if let emptyState {
            return emptyState.message
        }

        if recordedCount >= HomePatternPreviewData.minimumEpisodeCount {
            return "Es gibt schon genug Einträge, aber noch nichts, das in deinen Einträgen auffällig genug ist."
        }

        if recordedCount == 0 {
            return "Wenn du einige Schmerz- oder Migräneeinträge erfasst hast, zeigt Symi hier vorsichtige Hinweise."
        }

        return "\(recordedCount) von \(HomePatternPreviewData.minimumEpisodeCount) nötigen Schmerz- oder Migräneeinträgen sind vorhanden. Sobald mehr Daten da sind, sucht Symi nach vorsichtigen Mustern."
    }

    private var title: String {
        if let emptyState {
            return emptyState.title
        }

        return recordedCount >= HomePatternPreviewData.minimumEpisodeCount ? "Noch kein vorsichtiges Muster sichtbar" : "Noch nicht genug Einträge für Muster"
    }

    private var emptyIconSize: CGFloat {
        SymiSize.homePatternEmptyIcon - SymiSpacing.xxs
    }
}

struct InsightsView: View {
    let appContainer: AppContainer
    @State private var data = InsightResult(totalQualifiedEpisodeCount: 0, insights: [])
    @State private var selectedPeriod: InsightPeriod = .thirtyDays

    var body: some View {
        ScrollView {
            HomeInsightsContent(
                data: data,
                selectedPeriod: $selectedPeriod
            )
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.vertical, SymiSpacing.xl)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
        }
        .brandScreen()
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reload()
        }
        .onChange(of: selectedPeriod) { _, _ in
            Task {
                await reload()
            }
        }
        .refreshable {
            await reload()
        }
    }

    private func reload() async {
        data = (try? await LoadInsightResultUseCase(
            repository: appContainer.episodeRepository,
            insightEngine: appContainer.insightEngine
        ).execute(period: selectedPeriod)) ?? InsightResult(
            period: selectedPeriod,
            totalQualifiedEpisodeCount: 0,
            insights: []
        )
    }
}

private struct HomeInsightsContent: View {
    let data: InsightResult
    @Binding var selectedPeriod: InsightPeriod
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.insightsContentSpacing) {
            InsightsHeader()

            InsightsPeriodFilter(selectedPeriod: $selectedPeriod)
                .accessibilityIdentifier("insights-period-picker")

            if data.hasEnoughData, let heroInsight = data.heroInsight {
                VStack(alignment: .leading, spacing: SymiSpacing.md) {
                    InsightHeroCard(
                        insight: heroInsight,
                        trendPoints: data.metrics.dailyIntensityTrend,
                        entryCount: data.totalQualifiedEpisodeCount
                    )

                    VStack(alignment: .leading, spacing: SymiSpacing.md) {
                        if let averageIntensity {
                            AverageIntensityInsightCard(
                                averageIntensity: averageIntensity,
                                entryCount: data.totalQualifiedEpisodeCount
                            )
                        }

                        if !topTriggers.isEmpty {
                            FrequencyInsightCard(
                                title: "Häufige Auslöser",
                                systemImage: "tag",
                                summaries: topTriggers,
                                tint: AppTheme.coral(for: colorScheme),
                                detail: "in deinen Einträgen auffällig"
                            )
                        }

                        if !topMedications.isEmpty {
                            FrequencyInsightCard(
                                title: "Medikation",
                                systemImage: "pills",
                                summaries: topMedications,
                                tint: AppTheme.petrol(for: colorScheme),
                                detail: "in diesem Zeitraum dokumentiert"
                            )
                        }
                    }
                }
            } else {
                HomePatternEmptyState(recordedCount: data.totalQualifiedEpisodeCount, emptyState: data.emptyState)
            }
        }
    }

    private var averageIntensity: Double? {
        let trend = data.metrics.dailyIntensityTrend
        let entryCount = trend.reduce(0) { $0 + $1.entryCount }
        guard entryCount > 0 else {
            return nil
        }

        let weightedSum = trend.reduce(0) { partialResult, point in
            partialResult + point.averageIntensity * Double(point.entryCount)
        }
        return weightedSum / Double(entryCount)
    }

    private var topTriggers: [InsightFrequencySummary] {
        Array(data.metrics.triggerSummaries.prefix(3))
    }

    private var topMedications: [InsightFrequencySummary] {
        Array(data.metrics.acuteMedicationSummaries.prefix(3))
    }
}

private struct InsightsHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xs) {
            Text("Insights")
                .font(SymiTypography.largeRoundedTitle)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                .accessibilityAddTraits(.isHeader)

            Text("Deine Muster im Überblick")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
        }
        .padding(.top, SymiSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InsightsPeriodFilter: View {
    @Binding var selectedPeriod: InsightPeriod
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: SymiSpacing.xs) {
            ForEach(InsightPeriod.allCases) { period in
                Button {
                    selectedPeriod = period
                } label: {
                    Text(period.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedPeriod == period ? AppTheme.symiOnAccent : AppTheme.petrol(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(SymiTypography.tightChipScaleFactor)
                        .frame(maxWidth: .infinity, minHeight: SymiSize.minInteractiveHeight)
                        .background(chipBackground(for: period), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(period.displayTitle)
                .accessibilityValue(selectedPeriod == period ? "Ausgewählt" : "")
                .accessibilityIdentifier("insights-period-\(period.rawValue)")
            }
        }
    }

    private func chipBackground(for period: InsightPeriod) -> Color {
        selectedPeriod == period ? AppTheme.petrol(for: colorScheme) : AppTheme.sage(for: colorScheme).opacity(SymiOpacity.faintSurface)
    }
}

private struct InsightHeroCard: View {
    let insight: Insight
    let trendPoints: [InsightDailyIntensityPoint]
    let entryCount: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            HStack(alignment: .top, spacing: SymiSpacing.md) {
                Image(systemName: insight.systemImage ?? insight.category.fallbackSystemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.petrol(for: colorScheme))
                    .frame(width: SymiSize.insightHeroIcon, height: SymiSize.insightHeroIcon)
                    .background(AppTheme.sage(for: colorScheme).opacity(SymiOpacity.secondaryFill), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                    Text("Muster erkannt")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.coral(for: colorScheme))
                        .textCase(.uppercase)

                    Text(insight.title)
                        .font(SymiTypography.insightHeroTitle)
                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(insight.description)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            if trendPoints.count >= 2 {
                InsightTrendStrip(points: trendPoints)
                    .frame(height: SymiSize.insightTrendStripHeight)
                    .accessibilityLabel("Ruhiger Verlauf der dokumentierten Stärke")
            } else {
                InsightDotPattern(entryCount: entryCount)
                    .frame(height: SymiSize.insightDotPatternHeight)
                    .accessibilityLabel("\(entryCount) Einträge im gewählten Zeitraum")
            }
        }
        .padding(SymiSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeSurface()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("insights-hero")
    }
}

private struct AverageIntensityInsightCard: View {
    let averageIntensity: Double
    let entryCount: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.md) {
            InsightCardHeader(title: "Durchschnittliche Stärke", systemImage: "gauge.medium", tint: AppTheme.sage(for: colorScheme))

            Text("\(formattedAverage) / 10")
                .font(SymiTypography.insightMetric)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

            Text(intensityDescription)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.sage(for: colorScheme).opacity(SymiOpacity.faintTrack))

                    Capsule()
                        .fill(AppTheme.coral(for: colorScheme).opacity(SymiOpacity.heroPrimaryWave))
                        .frame(width: geometry.size.width * min(max(averageIntensity / 10, 0), 1))
                }
            }
            .frame(height: SymiSize.insightAverageTrackHeight)
            .accessibilityHidden(true)
        }
        .padding(SymiSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeSurface()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("insights-card-average")
    }

    private var formattedAverage: String {
        averageIntensity.formatted(.number.precision(.fractionLength(1)))
    }

    private var intensityDescription: String {
        if averageIntensity < 4 {
            return "meist leicht in \(entryCount) Einträgen"
        }

        if averageIntensity < 7 {
            return "meist leicht bis mittel in \(entryCount) Einträgen"
        }

        return "häufiger stärker in \(entryCount) Einträgen"
    }
}

private struct FrequencyInsightCard: View {
    let title: String
    let systemImage: String
    let summaries: [InsightFrequencySummary]
    let tint: Color
    let detail: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.md) {
            InsightCardHeader(title: title, systemImage: systemImage, tint: tint)

            Text(statement)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                ForEach(summaries, id: \.name) { summary in
                    InsightFrequencyRow(summary: summary, tint: tint)
                }
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
        }
        .padding(SymiSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeSurface()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("insights-card-\(title)")
    }

    private var statement: String {
        guard let first = summaries.first else {
            return ""
        }

        return "\(first.name) ist am häufigsten dokumentiert"
    }
}

private struct InsightCardHeader: View {
    let title: String
    let systemImage: String
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: SymiSpacing.sm) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: SymiSize.insightCardHeaderIcon, height: SymiSize.insightCardHeaderIcon)
                .background(tint.opacity(SymiOpacity.clearAccent), in: Circle())
                .accessibilityHidden(true)

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                .textCase(.uppercase)
        }
    }
}

private struct InsightFrequencyRow: View {
    let summary: InsightFrequencySummary
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.compact) {
            HStack(spacing: SymiSpacing.xs) {
                Text(summary.name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                    .lineLimit(1)

                Spacer(minLength: SymiSpacing.xs)

                Text(summary.share.formatted(.percent.precision(.fractionLength(0))))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(tint.opacity(SymiOpacity.faintSurface))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint.opacity(SymiOpacity.heroPrimaryWave))
                            .frame(width: geometry.size.width * min(max(summary.share, 0), 1))
                    }
            }
            .frame(height: SymiSize.insightShareTrackHeight)
            .accessibilityHidden(true)
        }
    }
}

private struct InsightTrendStrip: View {
    let points: [InsightDailyIntensityPoint]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: SymiRadius.flowBanner, style: .continuous)
                    .fill(AppTheme.sage(for: colorScheme).opacity(SymiOpacity.clearAccent))

                TrendLineShape(values: points.map(\.averageIntensity))
                    .stroke(
                        AppTheme.petrol(for: colorScheme).opacity(SymiOpacity.heroPrimaryWave),
                        style: StrokeStyle(lineWidth: SymiStroke.trendLine, lineCap: .round, lineJoin: .round)
                    )
                    .padding(.horizontal, SymiSpacing.md)
                    .padding(.vertical, SymiSpacing.xl)

                ForEach(Array(points.enumerated()), id: \.element.day) { index, point in
                    Circle()
                        .fill(AppTheme.coral(for: colorScheme).opacity(SymiOpacity.heroAccentWave))
                        .frame(width: SymiSize.insightTrendPoint, height: SymiSize.insightTrendPoint)
                        .position(dotPosition(for: index, value: point.averageIntensity, in: geometry.size))
                }
            }
        }
    }

    private func dotPosition(for index: Int, value: Double, in size: CGSize) -> CGPoint {
        let horizontalPadding = SymiSpacing.md
        let verticalPadding = SymiSpacing.xl
        let availableWidth = max(size.width - horizontalPadding * 2, 1)
        let availableHeight = max(size.height - verticalPadding * 2, 1)
        let denominator = max(points.count - 1, 1)
        let x = horizontalPadding + availableWidth * CGFloat(index) / CGFloat(denominator)
        let normalizedValue = min(max(value / 10, 0), 1)
        let y = verticalPadding + availableHeight * CGFloat(1 - normalizedValue)
        return CGPoint(x: x, y: y)
    }
}

private struct TrendLineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count >= 2 else {
            return path
        }

        for (index, value) in values.enumerated() {
            let denominator = max(values.count - 1, 1)
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(denominator)
            let normalizedValue = min(max(value / 10, 0), 1)
            let y = rect.minY + rect.height * CGFloat(1 - normalizedValue)
            let point = CGPoint(x: x, y: y)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

private struct InsightDotPattern: View {
    let entryCount: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: SymiSpacing.md) {
            ForEach(0 ..< visibleDotCount, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? AppTheme.sage(for: colorScheme).opacity(SymiOpacity.secondaryFill) : AppTheme.coral(for: colorScheme).opacity(SymiOpacity.faintSurface))
                    .frame(width: SymiSize.insightPatternDot, height: SymiSize.insightPatternDot)
            }
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.sage(for: colorScheme).opacity(SymiOpacity.clearAccent), in: RoundedRectangle(cornerRadius: SymiRadius.flowBanner, style: .continuous))
    }

    private var visibleDotCount: Int {
        min(max(entryCount, 1), 7)
    }
}

struct AdaptiveDashboardCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.secondaryButtonVerticalPadding) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: SymiSpacing.md) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SymiSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeSurface()
    }
}

private struct HomePrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(buttonBackground, in: RoundedRectangle(cornerRadius: SymiRadius.homeActionButton, style: .continuous))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .shadow(
                color: AppTheme.petrol(for: colorScheme).opacity(colorScheme == .dark ? SymiOpacity.homeActionShadowDark : SymiOpacity.homeActionShadowLight),
                radius: 16,
                x: SymiShadow.cardXOffset,
                y: 5
            )
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }

    private var buttonBackground: LinearGradient {
        LinearGradient(
            colors: [
                SymiColors.primaryPetrol.color,
                SymiColorValue(hex: 0x134A4B).color,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct HomeScreenModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .tint(AppTheme.petrol(for: colorScheme))
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    AppTheme.appBackground(for: colorScheme)
                    AppTheme.sage(for: colorScheme)
                        .opacity(colorScheme == .dark ? SymiOpacity.homeBackgroundPrimaryDark : SymiOpacity.homeBackgroundPrimaryLight)
                        .blur(radius: SymiSize.homeLiquidBackgroundPrimaryBlur)
                        .offset(x: SymiSpacing.homeLiquidBackgroundPrimaryOffsetX, y: SymiSpacing.homeLiquidBackgroundPrimaryOffsetY)
                    AppTheme.coral(for: colorScheme)
                        .opacity(colorScheme == .dark ? SymiOpacity.homeBackgroundSecondaryDark : SymiOpacity.homeBackgroundSecondaryLight)
                        .blur(radius: SymiSize.homeLiquidBackgroundSecondaryBlur)
                        .offset(x: SymiSpacing.homeLiquidBackgroundSecondaryOffsetX, y: SymiSpacing.homeLiquidBackgroundSecondaryOffsetY)
                }
                .ignoresSafeArea()
            }
    }
}

private struct HomeSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .symiGlass(.regular, cornerRadius: SymiRadius.homeActionButton)
    }
}

private extension View {
    func homeScreen() -> some View {
        modifier(HomeScreenModifier())
    }

    func homeSurface() -> some View {
        modifier(HomeSurfaceModifier())
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
