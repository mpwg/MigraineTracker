import SwiftUI

struct HistoryView: View {
    let appContainer: AppContainer
    @State private var controller: HistoryController
    @State private var selectedCategory: JournalCategory = .all
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
                        selectedCategory: $selectedCategory,
                        filters: filters
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
            selectedCategory.matches(episode) &&
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

private enum JournalCategory: String, CaseIterable, Identifiable {
    case all = "Alle"
    case pain = "Schmerz"
    case mood = "Stimmung"
    case medication = "Medikation"
    case notes = "Notizen"

    var id: String { rawValue }

    func matches(_ episode: EpisodeRecord) -> Bool {
        switch self {
        case .all:
            true
        case .pain:
            episode.type == .migraine || episode.type == .headache || episode.intensity > 0
        case .mood:
            !episode.painCharacter.trimmed.isEmpty || !episode.functionalImpact.trimmed.isEmpty
        case .medication:
            !episode.medications.isEmpty || !episode.continuousMedicationChecks.isEmpty
        case .notes:
            !episode.notes.trimmed.isEmpty
        }
    }
}

private enum JournalDateRange: String, CaseIterable, Identifiable {
    case all = "Alle"
    case sevenDays = "7 Tage"
    case thirtyDays = "30 Tage"
    case ninetyDays = "90 Tage"

    var id: String { rawValue }

    var startDate: Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        switch self {
        case .all:
            return nil
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -7, to: today)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: today)
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -90, to: today)
        }
    }
}

private enum JournalIntensityFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case light = "Leicht+"
    case medium = "Mittel+"
    case strong = "Stark"

    var id: String { rawValue }

    func matches(_ intensity: Int) -> Bool {
        switch self {
        case .all:
            true
        case .light:
            intensity >= 1
        case .medium:
            intensity >= 4
        case .strong:
            intensity >= 7
        }
    }
}

private struct JournalFilters: Equatable {
    var dateRange: JournalDateRange = .all
    var intensity: JournalIntensityFilter = .all
    var requiresNotes = false
    var requiresMedication = false

    var hasActiveFilters: Bool {
        dateRange != .all || intensity != .all || requiresNotes || requiresMedication
    }

    func matches(_ episode: EpisodeRecord) -> Bool {
        if let startDate = dateRange.startDate, episode.startedAt < startDate {
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

private struct JournalFilterBar: View {
    @Binding var selectedCategory: JournalCategory
    let filters: JournalFilters

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SymiSpacing.xs) {
                ForEach(JournalCategory.allCases) { category in
                    JournalChip(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }

                if filters.hasActiveFilters {
                    Text("Gefiltert")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(JournalPalette.ink)
                        .padding(.horizontal, SymiSpacing.md)
                        .frame(minHeight: SymiSize.minInteractiveHeight)
                        .background(JournalPalette.selectedChipFill, in: Capsule())
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
                .fill(JournalPalette.accent)
                .frame(width: SymiSize.journalAccentBarWidth)

            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: SymiSpacing.sm) {
                    Text(intensityTitle)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(JournalPalette.ink)
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
                    Picker("Zeitraum", selection: $filters.dateRange) {
                        ForEach(JournalDateRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                }

                Section("Intensität") {
                    Picker("Intensität", selection: $filters.intensity) {
                        ForEach(JournalIntensityFilter.allCases) { intensity in
                            Text(intensity.rawValue).tag(intensity)
                        }
                    }
                }

                Section {
                    Toggle("Notizen vorhanden", isOn: $filters.requiresNotes)
                    Toggle("Medikation", isOn: $filters.requiresMedication)
                }

                Section {
                    Button("Filter zurücksetzen") {
                        filters = JournalFilters()
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
