import SwiftUI

struct EpisodeDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let appContainer: AppContainer
    let episodeID: UUID
    let onChanged: () -> Void

    @State private var episode: EpisodeRecord?
    @State private var isEditing = false
    @State private var isLoading = true
    @State private var isShowingDeleteConfirmation = false

    private let loadEpisodeDetailUseCase: LoadEpisodeDetailUseCase
    private let deleteEpisodeUseCase: DeleteEpisodeUseCase

    init(
        appContainer: AppContainer,
        episodeID: UUID,
        onChanged: @escaping () -> Void = {}
    ) {
        self.appContainer = appContainer
        self.episodeID = episodeID
        self.onChanged = onChanged
        self.loadEpisodeDetailUseCase = LoadEpisodeDetailUseCase(repository: appContainer.episodeRepository)
        self.deleteEpisodeUseCase = DeleteEpisodeUseCase(repository: appContainer.episodeRepository)
        _episode = State(initialValue: nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.xl) {
                EntryDetailHeader(
                    title: headerTitle,
                    onBack: { dismiss() },
                    onEdit: { isEditing = true }
                )

                if let episode {
                    EntryDetailHeroCard(episode: episode)

                    if !detailRows.isEmpty {
                        EntryDetailSectionCard(rows: detailRows)
                    }

                    EntryDetailActions(
                        onEdit: { isEditing = true },
                        onDelete: { isShowingDeleteConfirmation = true }
                    )
                } else {
                    EntryDetailLoadingState(isLoading: isLoading)
                }
            }
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.top, SymiSpacing.xl)
            .padding(.bottom, SymiSpacing.xxxl)
        }
        .background(SymiColors.warmBackground.color.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .tint(SymiColors.primaryPetrol.color)
        .task {
            await reload()
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                EpisodeEditorView(
                    appContainer: appContainer,
                    episodeID: episodeID,
                    onSaved: handleSavedEpisode
                )
            }
        }
        .confirmationDialog(
            "Eintrag löschen?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive, action: deleteEpisode)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Dieser Eintrag wird in den Papierkorb verschoben.")
        }
    }

    private var headerTitle: String {
        guard let episode else {
            return "Eintrag"
        }

        return episode.startedAt.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var detailRows: [EntryDetailRowModel] {
        guard let episode else {
            return []
        }

        var rows: [EntryDetailRowModel] = [
            EntryDetailRowModel(
                title: "Zeitpunkt",
                value: JournalEntryContext.timeOfDay(for: episode.startedAt)
            )
        ]

        if !episode.painLocation.trimmed.isEmpty {
            rows.insert(
                EntryDetailRowModel(title: "Ort", value: episode.painLocation.trimmed),
                at: 0
            )
        }

        if let medicationDetail = JournalEntryContext.medicationDetail(for: episode) {
            rows.append(EntryDetailRowModel(title: "Medikation", value: medicationDetail))
        }

        if !episode.painCharacter.trimmed.isEmpty {
            rows.append(EntryDetailRowModel(title: "Charakter", value: episode.painCharacter.trimmed))
        }

        if !episode.functionalImpact.trimmed.isEmpty {
            rows.append(EntryDetailRowModel(title: "Verlauf", value: episode.functionalImpact.trimmed))
        }

        if !episode.notes.trimmed.isEmpty {
            rows.append(EntryDetailRowModel(title: "Notiz", value: episode.notes.trimmed, isMultiline: true))
        }

        return rows
    }

    private func handleSavedEpisode() {
        isEditing = false
        Task {
            await reload()
            onChanged()
        }
    }

    private func deleteEpisode() {
        Task {
            do {
                try await deleteEpisodeUseCase.execute(id: episodeID)
                onChanged()
                dismiss()
            } catch {
                assertionFailure("Löschen fehlgeschlagen: \(error)")
            }
        }
    }

    private func reload() async {
        isLoading = true
        episode = try? await loadEpisodeDetailUseCase.execute(id: episodeID)
        isLoading = false
    }
}

private struct EntryDetailHeader: View {
    let title: String
    let onBack: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: SymiSpacing.md) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(SymiColors.textPrimary.color)
                    .frame(width: SymiSize.minInteractiveHeight, height: SymiSize.minInteractiveHeight)
                    .background(SymiColors.onAccent.color, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zurück")

            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(SymiColors.textPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(SymiTypography.compactScaleFactor)

            Spacer(minLength: SymiSpacing.md)

            Button("Bearbeiten", action: onEdit)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(SymiColors.primaryPetrol.color)
                .padding(.horizontal, SymiSpacing.md)
                .frame(minHeight: SymiSize.minInteractiveHeight)
                .background(SymiColors.onAccent.color, in: Capsule())
                .buttonStyle(.plain)
        }
    }
}

private struct EntryDetailHeroCard: View {
    let episode: EpisodeRecord

    private var intensityColor: Color {
        JournalEntryContext.intensityColor(for: episode.intensity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xl) {
            VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                Text(JournalEntryContext.intensityLabel(for: episode.intensity))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(SymiColors.textPrimary.color)

                Text("\(episode.intensity)/10")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(SymiColors.textSecondary.color)
                    .monospacedDigit()
            }

            ProgressView(value: Double(episode.intensity), total: 10)
                .tint(intensityColor)
                .accessibilityLabel("Intensität")
                .accessibilityValue("\(episode.intensity) von 10")
        }
        .padding(SymiSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SymiColors.onAccent.color, in: RoundedRectangle(cornerRadius: SymiRadius.journalCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SymiRadius.journalCard, style: .continuous)
                .stroke(Color.primary.opacity(SymiOpacity.journalBorder), lineWidth: SymiStroke.hairline)
        )
        .shadow(
            color: Color.primary.opacity(SymiOpacity.journalShadow),
            radius: SymiShadow.journalCardRadius,
            x: SymiShadow.journalCardXOffset,
            y: SymiShadow.journalCardYOffset
        )
    }
}

private struct EntryDetailSectionCard: View {
    let rows: [EntryDetailRowModel]

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            ForEach(rows) { row in
                EntryDetailRow(row: row)
            }
        }
        .padding(SymiSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SymiColors.onAccent.color, in: RoundedRectangle(cornerRadius: SymiRadius.journalCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SymiRadius.journalCard, style: .continuous)
                .stroke(Color.primary.opacity(SymiOpacity.journalBorder), lineWidth: SymiStroke.hairline)
        )
    }
}

private struct EntryDetailRow: View {
    let row: EntryDetailRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
            Text(row.title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(SymiColors.textSecondary.color)

            Text(row.value)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(SymiColors.textPrimary.color)
                .lineLimit(row.isMultiline ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct EntryDetailActions: View {
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: SymiSpacing.sm) {
            Button("Bearbeiten", action: onEdit)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(SymiColors.onAccent.color)
                .frame(maxWidth: .infinity, minHeight: SymiSize.primaryButtonHeight)
                .background(SymiColors.primaryPetrol.color, in: Capsule())

            Button("Löschen", role: .destructive, action: onDelete)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(SymiColors.intensityStrong.color)
                .frame(maxWidth: .infinity, minHeight: SymiSize.primaryButtonHeight)
        }
        .buttonStyle(.plain)
    }
}

private struct EntryDetailLoadingState: View {
    let isLoading: Bool

    var body: some View {
        VStack(spacing: SymiSpacing.md) {
            if isLoading {
                ProgressView()
            } else {
                ContentUnavailableView("Eintrag nicht gefunden", systemImage: "exclamationmark.triangle")
            }
        }
        .frame(maxWidth: .infinity, minHeight: SymiSize.emptyStateMinHeight)
    }
}

private struct EntryDetailRowModel: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    var isMultiline = false
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
