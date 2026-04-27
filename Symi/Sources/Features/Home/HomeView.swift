import SwiftUI

struct HomeView: View {
    let appContainer: AppContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var displayedMonth = Calendar.current.startOfMonth(for: .now)
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

                HomeMonthCalendarView(
                    month: displayedMonth,
                    episodesByDay: calendarMonthData.episodesByDay,
                    onPrevious: showPreviousMonth,
                    onNext: showNextMonth
                )
                .padding(.bottom, SymiSpacing.lg)

                PrimaryEntryButton {
                    isPresentingEpisodeEditor = true
                }
                .padding(.bottom, SymiSpacing.md)

                HomeAllEntriesLink(appContainer: appContainer)
                    .padding(.bottom, SymiSpacing.xxxl)

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

                HomeMonthCalendarView(
                    month: displayedMonth,
                    episodesByDay: calendarMonthData.episodesByDay,
                    onPrevious: showPreviousMonth,
                    onNext: showNextMonth
                )
                .padding(.bottom, SymiSpacing.lg)

                PrimaryEntryButton {
                    isPresentingEpisodeEditor = true
                }
                .padding(.bottom, SymiSpacing.md)

                HomeAllEntriesLink(appContainer: appContainer)
                    .padding(.bottom, SymiSpacing.xxxl)

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
        patternPreviewData = (try? await LoadHomePatternPreviewUseCase(repository: appContainer.episodeRepository).execute()) ?? HomePatternPreviewData(totalPainEpisodeCount: 0, cards: [])
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
            AppTheme.coral(for: colorScheme).opacity(0.72)
        case 5 ... 7:
            AppTheme.sage(for: colorScheme).opacity(0.72)
        default:
            AppTheme.petrol(for: colorScheme).opacity(0.62)
        }
    }

    private var dayTextColor: Color {
        if isToday {
            return AppTheme.symiOnAccent
        }

        return AppTheme.textPrimary(for: colorScheme).opacity(0.6)
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
            .frame(width: 140, height: 68, alignment: .leading)
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
                    .frame(width: 48, height: 48)
                    .background(AppTheme.coral(for: colorScheme), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                    Text("Eintrag erstellen")
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
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        }
        .buttonStyle(HomePrimaryActionButtonStyle(colorScheme: colorScheme))
        .keyboardShortcut("n", modifiers: .command)
        .hoverEffect(.highlight)
        .accessibilityIdentifier("home-quick-entry")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Eintrag erstellen")
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
                HomePatternEmptyState(recordedCount: data.totalPainEpisodeCount)
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

    private var emptyIconSize: CGFloat {
        SymiSize.homePatternEmptyIcon - SymiSpacing.xxs
    }
}

struct InsightsView: View {
    let appContainer: AppContainer
    @State private var data = HomePatternPreviewData(totalPainEpisodeCount: 0, cards: [])

    var body: some View {
        ScrollView {
            HomeInsightsContent(data: data)
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.vertical, SymiSpacing.xl)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
        }
        .brandScreen()
        .navigationTitle("Insights")
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    private func reload() async {
        data = (try? await LoadHomePatternPreviewUseCase(repository: appContainer.episodeRepository).execute()) ?? HomePatternPreviewData(
            totalPainEpisodeCount: 0,
            cards: []
        )
    }
}

private struct HomeInsightsContent: View {
    let data: HomePatternPreviewData

    var body: some View {
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
    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(buttonBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .shadow(
                color: AppTheme.petrol(for: colorScheme).opacity(colorScheme == .dark ? 0.05 : 0.10),
                radius: 16,
                x: SymiShadow.cardXOffset,
                y: 5
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
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
            .background(AppTheme.warmBackground(for: colorScheme).ignoresSafeArea())
    }
}

private struct HomeSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(
                color: AppTheme.petrol(for: colorScheme).opacity(colorScheme == .dark ? SymiOpacity.clearAccent : 0.05),
                radius: 10,
                x: SymiShadow.cardXOffset,
                y: 4
            )
    }

    private var cardBackground: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    AppTheme.cardBackground(for: colorScheme),
                    AppTheme.sage(for: colorScheme).opacity(SymiOpacity.clearAccent),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white,
                AppTheme.sage(for: colorScheme).opacity(0.03),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
