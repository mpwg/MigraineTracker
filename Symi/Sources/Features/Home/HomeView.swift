import SwiftUI

struct HomeView: View {
    let appContainer: AppContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var displayedMonth = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var calendarMonthData = HistoryMonthData(month: Calendar.current.startOfMonth(for: .now), episodesByDay: [:])
    @State private var patternPreviewData = HomePatternPreviewData(totalPainEpisodeCount: 0, cards: [])
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
        .task(id: displayedMonth) {
            await reloadAll()
        }
        .refreshable {
            await reloadAll()
        }
        .fullScreenCover(isPresented: $isPresentingEpisodeEditor) {
            EntryFlowCoordinatorView(appContainer: appContainer, initialStartedAt: defaultStartDateForSelectedDay()) {
                isPresentingEpisodeEditor = false
                Task { await reloadAll() }
            }
        }
    }

    private var compactDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.xl) {
                HomeMonthCalendarView(
                    month: displayedMonth,
                    selectedDay: selectedDay,
                    episodesByDay: calendarMonthData.episodesByDay,
                    onSelectDay: selectDay,
                    onPrevious: showPreviousMonth,
                    onNext: showNextMonth
                )

                QuickEntryCard(selectedDay: selectedDay) {
                    isPresentingEpisodeEditor = true
                }

                HomePatternPreviewSection(data: patternPreviewData) {
                    HomeInsightsView(data: patternPreviewData)
                }

                FeelingCheckInCard()

                AdaptiveDashboardCard(title: "Vertrauen") {
                    VStack(alignment: .leading, spacing: SymiSpacing.sm) {
                        Label("Deine Daten gehören dir.", systemImage: "lock")
                            .font(.headline)
                        Text("Symi bleibt lokal nutzbar. Sync und Export passieren nur, wenn du sie aktiv nutzt.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.symiTextSecondary)
                    }
                }
            }
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.vertical, SymiSpacing.xl)
        }
        .brandScreen()
    }

    private var regularDashboard: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: SymiSize.dashboardWideColumnMinWidth), spacing: AppTheme.dashboardSpacing, alignment: .top),
                    GridItem(.flexible(minimum: SymiSize.dashboardColumnMinWidth), spacing: AppTheme.dashboardSpacing, alignment: .top)
                ],
                alignment: .leading,
                spacing: AppTheme.dashboardSpacing
            ) {
                VStack(alignment: .leading, spacing: AppTheme.dashboardSpacing) {
                    HomeMonthCalendarView(
                        month: displayedMonth,
                        selectedDay: selectedDay,
                        episodesByDay: calendarMonthData.episodesByDay,
                        onSelectDay: selectDay,
                        onPrevious: showPreviousMonth,
                        onNext: showNextMonth
                    )
                    QuickEntryCard(selectedDay: selectedDay) {
                        isPresentingEpisodeEditor = true
                    }
                    HomePatternPreviewSection(data: patternPreviewData) {
                        HomeInsightsView(data: patternPreviewData)
                    }
                    FeelingCheckInCard()
                }

                VStack(alignment: .leading, spacing: AppTheme.dashboardSpacing) {
                    AdaptiveDashboardCard(title: "Vertrauen") {
                        VStack(alignment: .leading, spacing: SymiSpacing.sm) {
                            Label("Deine Daten gehören dir.", systemImage: "lock")
                                .font(.headline)
                            Text("Website und Support: symiapp.com")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.symiTextSecondary)
                        }
                    }

                }
            }
            .padding(SymiSpacing.xxxl)
            .wideContent()
        }
        .brandScreen()
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
        patternPreviewData = (try? await LoadHomePatternPreviewUseCase(repository: appContainer.episodeRepository).execute()) ?? HomePatternPreviewData(totalPainEpisodeCount: 0, cards: [])
    }

    private func showPreviousMonth() {
        showMonth(offset: -1)
    }

    private func showNextMonth() {
        showMonth(offset: 1)
    }

    private func selectDay(_ day: Date) {
        selectedDay = Calendar.current.startOfDay(for: day)
    }

    private func showMonth(offset: Int) {
        let calendar = Calendar.current
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else {
            return
        }

        displayedMonth = newMonth
        selectedDay = calendar.startOfDay(for: newMonth)
    }

    private func defaultStartDateForSelectedDay() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let day = calendar.startOfDay(for: selectedDay)

        if day == today {
            return .now
        }

        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

}

private struct HomeMonthCalendarView: View {
    let month: Date
    let selectedDay: Date
    let episodesByDay: [Date: [EpisodeRecord]]
    let onSelectDay: (Date) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SymiSpacing.xs), count: 7)
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            HStack(alignment: .center, spacing: SymiSpacing.md) {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.system(.largeTitle, design: .serif).weight(.regular))
                    .foregroundStyle(AppTheme.petrol(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(SymiTypography.compactScaleFactor)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: SymiSpacing.sm)

                HStack(spacing: SymiSpacing.sm) {
                    calendarNavigationButton(systemImage: "chevron.left", label: "Vorheriger Monat", action: onPrevious)
                    calendarNavigationButton(systemImage: "chevron.right", label: "Nächster Monat", action: onNext)
                }
            }

            LazyVGrid(columns: columns, spacing: SymiSpacing.compact) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.petrol(for: colorScheme).opacity(SymiOpacity.heroSecondaryText))
                        .frame(maxWidth: .infinity, minHeight: SymiSize.homeCalendarWeekdayHeight)
                        .accessibilityHidden(true)
                }

                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, cell in
                    if let date = cell.date {
                        HomeCalendarDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDay),
                            isToday: calendar.isDateInToday(date),
                            entries: episodesByDay[calendar.startOfDay(for: date)] ?? []
                        ) {
                            onSelectDay(date)
                        }
                    } else {
                        Color.clear
                            .frame(height: SymiSize.calendarWeekdayHeight)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.horizontal, SymiSpacing.xl)
        .padding(.vertical, SymiSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Monatskalender \(month.formatted(.dateTime.month(.wide).year()))")
        .accessibilityIdentifier("home-calendar")
    }

    private func calendarNavigationButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.petrol(for: colorScheme))
                .frame(width: SymiSize.homeCalendarNavigationButton, height: SymiSize.homeCalendarNavigationButton)
                .background(AppTheme.cardBackground(for: colorScheme), in: Circle())
                .shadow(
                    color: AppTheme.shadowColor(for: colorScheme).opacity(SymiOpacity.hairline),
                    radius: SymiShadow.calendarButtonRadius,
                    y: SymiShadow.calendarButtonYOffset
                )
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
    let isSelected: Bool
    let isToday: Bool
    let entries: [EpisodeRecord]
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            VStack(spacing: SymiSpacing.xxs) {
                Text(date.formatted(.dateTime.day()))
                    .font(dayNumberFont)
                    .foregroundStyle(isSelected ? AppTheme.symiOnAccent : AppTheme.textPrimary(for: colorScheme))
                    .frame(width: dayNumberSize, height: dayNumberSize)
                    .background(isSelected ? AppTheme.petrol(for: colorScheme) : Color.clear, in: Circle())
                    .overlay {
                        if isToday && !isSelected {
                            Circle()
                                .stroke(AppTheme.petrol(for: colorScheme).opacity(SymiOpacity.selectedFill), lineWidth: SymiStroke.hairline)
                                .frame(width: dayNumberSize, height: dayNumberSize)
                        }
                    }

                if entries.isEmpty {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: SymiSize.calendarDot, height: SymiSize.calendarDot)
                } else {
                    HStack(spacing: SymiSpacing.micro) {
                        ForEach(Array(entries.prefix(3).enumerated()), id: \.element.id) { _, entry in
                            Circle()
                                .fill(dotColor(for: entry))
                                .frame(width: SymiSize.calendarDot, height: SymiSize.calendarDot)
                        }
                    }
                    .frame(height: SymiSize.calendarDot)
                }
            }
            .frame(maxWidth: .infinity, minHeight: calendarDayMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
        .accessibilityHint("Wählt diesen Tag für den Schnelleintrag aus.")
        .accessibilityIdentifier("home-calendar-day-\(date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))")
    }

    private func dotColor(for entry: EpisodeRecord) -> Color {
        switch entry.intensity {
        case 8...10:
            AppTheme.coral(for: colorScheme)
        case 5...7:
            AppTheme.sage(for: colorScheme)
        default:
            AppTheme.petrol(for: colorScheme).opacity(SymiOpacity.heroSecondaryText)
        }
    }

    private var dayNumberFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .body.weight(isSelected ? .semibold : .regular) : .title3.weight(isSelected ? .semibold : .regular)
    }

    private var dayNumberSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? SymiSize.homeCalendarDayNumber + SymiSize.homeCalendarAccessibilityGrowth : SymiSize.homeCalendarDayNumber
    }

    private var calendarDayMinHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? SymiSize.calendarDayMinHeight + SymiSize.homeCalendarDayAccessibilityGrowth : SymiSize.calendarDayMinHeight
    }

    private var accessibilityLabel: String {
        let dateText = date.formatted(date: .complete, time: .omitted)
        let selectionText: String
        if isSelected {
            selectionText = "ausgewählt"
        } else if isToday {
            selectionText = "heute"
        } else {
            selectionText = "nicht ausgewählt"
        }

        guard entries.isEmpty == false else {
            return "\(dateText), \(selectionText), keine Einträge"
        }

        let entryText = "\(entries.count) Eintrag\(entries.count == 1 ? "" : "e")"
        let highestIntensity = entries.map(\.intensity).max() ?? 0
        return "\(dateText), \(selectionText), \(entryText), höchste Intensität \(highestIntensity) von 10"
    }
}

private struct QuickEntryCard: View {
    let selectedDay: Date
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: SymiSpacing.sm) {
                Text("Schnelleintrag")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Text("Neuer Flow")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.petrol(for: colorScheme))
                    .padding(.horizontal, SymiSpacing.sm)
                    .padding(.vertical, SymiSpacing.xxs)
                    .background(AppTheme.secondaryFill(for: colorScheme), in: Capsule())
                    .accessibilityLabel("Neuer Flow")
            }

            Button(action: action) {
                HStack(alignment: .center, spacing: SymiSpacing.lg) {
                    Image(systemName: "plus")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(AppTheme.symiOnAccent)
                        .frame(width: SymiSize.quickEntryIcon, height: SymiSize.quickEntryIcon)
                        .background(AppTheme.coral(for: colorScheme), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                        Text("Neuen Eintrag erstellen")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            .lineLimit(2)
                            .minimumScaleFactor(SymiTypography.compactScaleFactor)

                        Text("Startet mit \(selectedDay.formatted(date: .abbreviated, time: .omitted)) und führt dich Schritt für Schritt durch den Eintrag.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: SymiSpacing.xs)

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.petrol(for: colorScheme).opacity(SymiOpacity.heroSecondaryText))
                        .accessibilityHidden(true)
                }
                .padding(SymiSpacing.xl)
                .frame(maxWidth: .infinity, minHeight: SymiSize.quickEntryMinHeight, alignment: .leading)
                .background(AppTheme.cardGradient(for: colorScheme), in: RoundedRectangle(cornerRadius: SymiRadius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SymiRadius.card, style: .continuous)
                        .stroke(AppTheme.coral(for: colorScheme).opacity(SymiOpacity.selectedFill), lineWidth: SymiStroke.hairline)
                }
                .shadow(
                    color: AppTheme.shadowColor(for: colorScheme),
                    radius: SymiShadow.brandCardRadius,
                    x: SymiShadow.cardXOffset,
                    y: SymiShadow.brandCardYOffset
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .hoverEffect(.highlight)
            .accessibilityIdentifier("home-quick-entry")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Neuen Eintrag erstellen")
            .accessibilityHint("Startet den Schnelleintrag für \(selectedDay.formatted(date: .complete, time: .omitted)).")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeCalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
}

private struct HomePatternPreviewSection<Destination: View>: View {
    let data: HomePatternPreviewData
    @ViewBuilder let destination: Destination

    init(data: HomePatternPreviewData, @ViewBuilder destination: () -> Destination) {
        self.data = data
        self.destination = destination()
    }

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
                LazyVGrid(columns: columns, alignment: .leading, spacing: SymiSpacing.md) {
                    ForEach(data.cards) { card in
                        HomePatternCard(card: card)
                            .gridCellColumns(card.isWide ? 2 : 1)
                    }
                }
            } else {
                HomePatternEmptyState(recordedCount: data.totalPainEpisodeCount)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("home-patterns-section")
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(minimum: 140), spacing: SymiSpacing.md, alignment: .top),
            GridItem(.flexible(minimum: 140), spacing: SymiSpacing.md, alignment: .top)
        ]
    }
}

private struct HomePatternCard: View {
    let card: HomePatternPreviewCard
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.sm) {
            Image(systemName: card.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.petrol(for: colorScheme))
                .frame(width: SymiSize.homePatternIcon, height: SymiSize.homePatternIcon)
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
        .padding(SymiSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
        .background(AppTheme.cardGradient(for: colorScheme), in: RoundedRectangle(cornerRadius: SymiRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SymiRadius.card, style: .continuous)
                .stroke(AppTheme.petrol(for: colorScheme).opacity(SymiOpacity.hairline), lineWidth: SymiStroke.hairline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.title), \(card.value). \(card.detail)")
        .accessibilityIdentifier("home-pattern-card-\(card.title)")
    }

    private var cardMinHeight: CGFloat {
        let baseHeight = card.isWide ? SymiSize.homePatternWideMinHeight : SymiSize.homePatternMinHeight
        return dynamicTypeSize.isAccessibilitySize ? baseHeight + SymiSize.homePatternAccessibilityHeightGrowth : baseHeight
    }
}

private struct HomePatternEmptyState: View {
    let recordedCount: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: SymiSpacing.md) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.coral(for: colorScheme))
                .frame(width: SymiSize.homePatternEmptyIcon, height: SymiSize.homePatternEmptyIcon)
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
        .padding(SymiSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: SymiRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SymiRadius.card, style: .continuous)
                .stroke(AppTheme.sage(for: colorScheme).opacity(SymiOpacity.selectedFill), lineWidth: SymiStroke.hairline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home-patterns-empty-state")
    }

    private var emptyStateText: String {
        if recordedCount >= HomePatternPreviewData.minimumEpisodeCount {
            return "Es gibt schon genug Einträge, aber noch keinen wiederkehrenden Hinweis, den wir ruhig anzeigen würden."
        }

        if recordedCount == 0 {
            return "Wenn du ein paar Schmerz- oder Migräneeinträge erfasst hast, zeigen wir hier vorsichtige Hinweise."
        }

        return "\(recordedCount) von 3 nötigen Schmerz- oder Migräneeinträgen sind vorhanden."
    }

    private var title: String {
        recordedCount >= HomePatternPreviewData.minimumEpisodeCount ? "Noch kein ruhiger Hinweis" : "Noch nicht genug Einträge"
    }
}

private struct HomeInsightsView: View {
    let data: HomePatternPreviewData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.xxl) {
                Text("Diese Hinweise basieren nur auf deinen bisherigen Schmerz- und Migräneeinträgen. Sie ersetzen keine medizinische Einschätzung.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.symiTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if data.hasEnoughData, !data.cards.isEmpty {
                    VStack(alignment: .leading, spacing: SymiSpacing.md) {
                        ForEach(data.cards) { card in
                            HomePatternCard(card: card)
                        }
                    }
                } else {
                    HomePatternEmptyState(recordedCount: data.totalPainEpisodeCount)
                }
            }
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.vertical, SymiSpacing.xl)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
        }
        .brandScreen()
        .navigationTitle("Deine Muster")
    }
}

struct AdaptiveDashboardCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

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
        .brandCard()
    }
}

private struct FeelingCheckInCard: View {
    @State private var currentState = 4.0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AdaptiveDashboardCard(title: "Wie geht es dir heute?") {
            VStack(alignment: .leading, spacing: SymiSpacing.secondaryButtonVerticalPadding) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(currentState))")
                        .font(SymiTypography.homeMetric)
                        .foregroundStyle(AppTheme.petrol(for: colorScheme))
                    Text(feelingLabel)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                }

                Slider(value: $currentState, in: 0 ... 10, step: 1)
                    .tint(AppTheme.coral(for: colorScheme))
                    .accessibilityLabel("Aktueller Zustand")
                    .accessibilityValue("\(Int(currentState)) von 10")
                    .accessibilityIdentifier("home-feeling-slider")

                Text("Eine schnelle Einschätzung reicht. Details kannst du im Eintrag ergänzen.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
            }
        }
    }

    private var feelingLabel: String {
        switch Int(currentState) {
        case 0 ... 2:
            return "ruhig"
        case 3 ... 5:
            return "mittel"
        case 6 ... 8:
            return "spürbar"
        default:
            return "stark"
        }
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
