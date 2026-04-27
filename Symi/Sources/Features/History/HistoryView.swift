import SwiftUI

struct HistoryView: View {
    let appContainer: AppContainer
    @State private var controller: HistoryController
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var isFilterSheetPresented = false
    @State private var filters = JournalFilters()

    init(appContainer: AppContainer) {
        self.appContainer = appContainer
        _controller = State(initialValue: appContainer.makeHistoryController())
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SymiSpacing.lg, pinnedViews: [.sectionHeaders]) {
                JournalHeader(
                    isSearchVisible: $isSearchVisible,
                    onFilter: { isFilterSheetPresented = true }
                )
                .padding(.horizontal, SymiSpacing.xxl)
                .padding(.top, SymiSpacing.xl)

                JournalActiveFilters(filters: $filters)
                    .padding(.horizontal, SymiSpacing.xxl)

                if isSearchVisible {
                    JournalSearchField(text: $searchText)
                        .padding(.horizontal, SymiSpacing.xxl)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Section {
                    JournalEntryGroups(
                        groupedEpisodes: groupedEpisodes,
                        appContainer: appContainer,
                        onEdit: { controller.editingEpisodeID = $0 },
                        onDelete: { controller.pendingDeletionID = $0 }
                    )
                    .padding(.horizontal, SymiSpacing.xxl)
                    .padding(.bottom, SymiSpacing.xxxl)
                } header: {
                    JournalFilterBar(
                        filters: $filters
                    )
                    .padding(.horizontal, SymiSpacing.xxl)
                    .padding(.vertical, SymiSpacing.sm)
                    .background(JournalPalette.background)
                }
            }
        }
        .background(JournalPalette.background.ignoresSafeArea())
        .tint(JournalPalette.ink)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.snappy(duration: SymiAnimation.quickDuration), value: isSearchVisible)
        .refreshable {
            await reloadJournal()
        }
        .task {
            await reloadJournal()
        }
        .sheet(isPresented: $isFilterSheetPresented) {
            JournalFilterSheet(filters: $filters)
                .presentationDetents([.medium, .large])
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

        return controller.allEpisodes.first(where: { $0.id == id })
    }

    private var filteredEpisodes: [EpisodeRecord] {
        controller.allEpisodes.filter { episode in
            filters.matches(episode) &&
                matchesSearch(episode)
        }
    }

    private var groupedEpisodes: [JournalDayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredEpisodes) { episode in
            calendar.startOfDay(for: episode.startedAt)
        }

        return groups
            .map { day, episodes in
                JournalDayGroup(day: day, episodes: episodes.sorted { $0.startedAt > $1.startedAt })
            }
            .sorted { $0.day > $1.day }
    }

    private func matchesSearch(_ episode: EpisodeRecord) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return true
        }

        return episode.notes.localizedCaseInsensitiveContains(query)
    }

    private func reloadJournal() async {
        do {
            try await controller.reloadJournalEntries()
            controller.errorMessage = nil
        } catch {
            controller.errorMessage = "Einträge konnten nicht geladen werden."
        }
    }
}

private enum JournalPalette {
    static let background = SymiColors.warmBackground.color
    static let card = SymiColors.onAccent.color
    static let accent = SymiColors.sage.color
    static let ink = SymiColors.journalInk.color
    static let secondary = SymiColors.journalTextSecondary.color
    static let border = Color.primary.opacity(SymiOpacity.journalBorder)
    static let chipFill = SymiColors.onAccent.color.opacity(SymiOpacity.journalChipFill)
    static let selectedChipFill = SymiColors.journalSelectedChipFill.color
    static let shadow = Color.primary.opacity(SymiOpacity.journalShadow)
}

private enum JournalDateRange: String, CaseIterable, Identifiable {
    case all = "Alle"
    case today = "Heute"
    case sevenDays = "7 Tage"
    case thirtyDays = "30 Tage"
    case custom = "Custom"

    var id: String { rawValue }
}

private enum JournalIntensityFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case light = "Leicht"
    case medium = "Mittel"
    case strong = "Stark"

    var id: String { rawValue }

    func matches(_ intensity: Int) -> Bool {
        switch self {
        case .all:
            true
        case .light:
            (1 ... 3).contains(intensity)
        case .medium:
            (4 ... 6).contains(intensity)
        case .strong:
            (7 ... 10).contains(intensity)
        }
    }
}

private struct JournalFilters: Equatable {
    var dateRange: JournalDateRange = .all
    var customStartDate = Calendar.current.startOfDay(for: .now)
    var intensity: JournalIntensityFilter = .all
    var requiresNotes = false
    var requiresMedication = false

    var hasActiveFilters: Bool {
        dateRange != .all || hasActivePrimaryFilters
    }

    var hasActivePrimaryFilters: Bool {
        intensity != .all || requiresNotes || requiresMedication
    }

    func matches(_ episode: EpisodeRecord) -> Bool {
        guard matchesDateRange(episode.startedAt) else {
            return false
        }

        if !intensity.matches(episode.intensity) {
            return false
        }

        if requiresNotes, episode.notes.trimmed.isEmpty {
            return false
        }

        if requiresMedication, episode.medications.isEmpty && episode.continuousMedicationChecks.isEmpty {
            return false
        }

        return true
    }

    private func matchesDateRange(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let day = calendar.startOfDay(for: date)

        switch dateRange {
        case .all:
            return true
        case .today:
            return day == today
        case .sevenDays:
            guard let startDate = calendar.date(byAdding: .day, value: -7, to: today) else {
                return true
            }
            return date >= startDate
        case .thirtyDays:
            guard let startDate = calendar.date(byAdding: .day, value: -30, to: today) else {
                return true
            }
            return date >= startDate
        case .custom:
            return date >= calendar.startOfDay(for: customStartDate)
        }
    }
}

private struct JournalDayGroup: Identifiable {
    let day: Date
    let episodes: [EpisodeRecord]

    var id: Date { day }
}

private struct JournalHeader: View {
    @Binding var isSearchVisible: Bool
    let onFilter: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: SymiSpacing.md) {
            Text("Alle Einträge")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(JournalPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(SymiTypography.compactScaleFactor)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: SymiSpacing.md)

            Button(action: onFilter) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.headline.weight(.semibold))
                    .frame(width: SymiSize.minInteractiveHeight, height: SymiSize.minInteractiveHeight)
                    .background(JournalPalette.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter")

            Button {
                isSearchVisible.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.headline.weight(.semibold))
                    .frame(width: SymiSize.minInteractiveHeight, height: SymiSize.minInteractiveHeight)
                    .background(JournalPalette.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Suche")
        }
    }
}

private struct JournalSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Notizen durchsuchen", text: $text)
            .font(.system(.body, design: .rounded))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, SymiSpacing.md)
            .frame(minHeight: SymiSize.minInteractiveHeight)
            .background(JournalPalette.card, in: RoundedRectangle(cornerRadius: SymiRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SymiRadius.button, style: .continuous)
                    .stroke(JournalPalette.border, lineWidth: SymiStroke.hairline)
            )
            .focused($isFocused)
            .task {
                isFocused = true
            }
    }
}

private struct JournalActiveFilters: View {
    @Binding var filters: JournalFilters

    var body: some View {
        if filters.hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SymiSpacing.xs) {
                    if filters.dateRange != .all {
                        JournalRemovableChip(title: dateRangeTitle) {
                            filters.dateRange = .all
                        }
                    }

                    if filters.intensity != .all {
                        JournalRemovableChip(title: filters.intensity.rawValue) {
                            filters.intensity = .all
                        }
                    }

                    if filters.requiresNotes {
                        JournalRemovableChip(title: "Mit Notizen") {
                            filters.requiresNotes = false
                        }
                    }

                    if filters.requiresMedication {
                        JournalRemovableChip(title: "Medikation") {
                            filters.requiresMedication = false
                        }
                    }
                }
            }
        }
    }

    private var dateRangeTitle: String {
        if filters.dateRange == .custom {
            return filters.customStartDate.formatted(date: .abbreviated, time: .omitted)
        }

        return filters.dateRange.rawValue
    }
}

private struct JournalFilterBar: View {
    @Binding var filters: JournalFilters

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SymiSpacing.xs) {
                ForEach(JournalIntensityFilter.allCases) { intensity in
                    JournalChip(
                        title: intensity.rawValue,
                        isSelected: filters.intensity == intensity
                    ) {
                        filters.intensity = intensity
                    }
                }

                JournalChip(
                    title: "Mit Notizen",
                    isSelected: filters.requiresNotes
                ) {
                    filters.requiresNotes.toggle()
                }

                JournalChip(
                    title: "Medikation",
                    isSelected: filters.requiresMedication
                ) {
                    filters.requiresMedication.toggle()
                }
            }
        }
    }
}

private struct JournalChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(JournalPalette.ink)
                .padding(.horizontal, SymiSpacing.md)
                .frame(minHeight: SymiSize.minInteractiveHeight)
                .background(isSelected ? JournalPalette.selectedChipFill : JournalPalette.chipFill, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? JournalPalette.accent.opacity(SymiOpacity.journalSelectedStroke) : JournalPalette.border,
                            lineWidth: SymiStroke.hairline
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
    }
}

private struct JournalRemovableChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: SymiSpacing.compact) {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))

                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(JournalPalette.ink)
            .padding(.horizontal, SymiSpacing.md)
            .frame(minHeight: SymiSize.journalActiveFilterChipMinHeight)
            .background(JournalPalette.selectedChipFill, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(JournalPalette.accent.opacity(SymiOpacity.journalSelectedStroke), lineWidth: SymiStroke.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) entfernen")
    }
}

private struct JournalEntryGroups: View {
    let groupedEpisodes: [JournalDayGroup]
    let appContainer: AppContainer
    let onEdit: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        if groupedEpisodes.isEmpty {
            JournalEmptyState()
        } else {
            VStack(alignment: .leading, spacing: SymiSpacing.xl) {
                ForEach(groupedEpisodes) { group in
                    VStack(alignment: .leading, spacing: SymiSpacing.md) {
                        Text(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(JournalPalette.ink)
                            .accessibilityAddTraits(.isHeader)

                        VStack(spacing: SymiSpacing.md) {
                            ForEach(group.episodes) { episode in
                                NavigationLink {
                                    EpisodeDetailView(appContainer: appContainer, episodeID: episode.id)
                                } label: {
                                    JournalEntryCard(episode: episode)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Bearbeiten", systemImage: "pencil") {
                                        onEdit(episode.id)
                                    }

                                    Button("Löschen", systemImage: "trash", role: .destructive) {
                                        onDelete(episode.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct JournalEntryCard: View {
    let episode: EpisodeRecord

    var body: some View {
        HStack(spacing: SymiSpacing.md) {
            RoundedRectangle(cornerRadius: SymiRadius.journalAccentBar, style: .continuous)
                .fill(intensityColor)
                .frame(width: SymiSize.journalAccentBarWidth)

            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: SymiSpacing.sm) {
                    Text(intensityTitle)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(intensityColor)
                        .lineLimit(1)
                        .minimumScaleFactor(SymiTypography.compactScaleFactor)

                    Spacer(minLength: SymiSpacing.sm)

                    Text(episode.startedAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(JournalPalette.secondary)
                        .monospacedDigit()
                }

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(JournalPalette.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(SymiSpacing.md)
        .frame(maxWidth: .infinity, minHeight: SymiSize.journalEntryCardMinHeight, alignment: .leading)
        .background(JournalPalette.card, in: RoundedRectangle(cornerRadius: SymiRadius.journalCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SymiRadius.journalCard, style: .continuous)
                .stroke(JournalPalette.border, lineWidth: SymiStroke.hairline)
        )
        .shadow(
            color: JournalPalette.shadow,
            radius: SymiShadow.journalCardRadius,
            x: SymiShadow.journalCardXOffset,
            y: SymiShadow.journalCardYOffset
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Öffnet die Detailansicht des Eintrags.")
    }

    private var intensityTitle: String {
        "\(intensityLabel) • \(episode.intensity)/10"
    }

    private var intensityLabel: String {
        switch episode.intensity {
        case 1 ... 3:
            "Leicht"
        case 4 ... 6:
            "Mittel"
        case 7 ... 10:
            "Stark"
        default:
            "Nicht bewertet"
        }
    }

    private var intensityColor: Color {
        switch episode.intensity {
        case 1 ... 3:
            return SymiColors.intensityLight.color
        case 4 ... 6:
            return SymiColors.intensityMedium.color
        case 7 ... 10:
            return SymiColors.intensityStrong.color
        default:
            return JournalPalette.ink
        }
    }

    private var subtitle: String {
        episode.notes.trimmed
    }

    private var accessibilityLabel: String {
        var parts = [
            intensityTitle,
            episode.startedAt.formatted(date: .complete, time: .shortened)
        ]

        if !subtitle.isEmpty {
            parts.append(subtitle)
        }

        return parts.joined(separator: ", ")
    }
}

private struct JournalEmptyState: View {
    var body: some View {
        VStack(spacing: SymiSpacing.zero) {
            Text("Keine Einträge")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(JournalPalette.ink)
        }
        .frame(maxWidth: .infinity, minHeight: SymiSize.journalEmptyStateMinHeight)
        .background(JournalPalette.card, in: RoundedRectangle(cornerRadius: SymiRadius.journalCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SymiRadius.journalCard, style: .continuous)
                .stroke(JournalPalette.border, lineWidth: SymiStroke.hairline)
        )
    }
}

private struct JournalFilterSheet: View {
    @Binding var filters: JournalFilters
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Zeitraum") {
                    ForEach(JournalDateRange.allCases) { range in
                        JournalDateRangeRow(
                            title: range.rawValue,
                            isSelected: filters.dateRange == range
                        ) {
                            filters.dateRange = range
                        }
                    }

                    if filters.dateRange == .custom {
                        DatePicker(
                            "Ab",
                            selection: $filters.customStartDate,
                            displayedComponents: [.date]
                        )
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct JournalDateRangeRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SymiSpacing.md) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(JournalPalette.ink)

                Spacer(minLength: SymiSpacing.md)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(JournalPalette.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
    }
}

private struct IdentifiedEpisodeID: Identifiable {
    let id: UUID
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Calendar {
    nonisolated func startOfMonth(for inputDate: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: inputDate)) ?? inputDate
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
