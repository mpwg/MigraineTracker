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
            VStack(alignment: .leading, spacing: 22) {
                EntryDetailHeader(
                    title: headerTitle,
                    onBack: { dismiss() },
                    onEdit: { isEditing = true }
                )

                if let episode {
                    EntryDetailHeroCard(episode: episode)

                    EntryDetailContextCard(episode: episode)

                    EntryDetailTriggerSection(triggers: episode.triggers)

                    EntryDetailMedicationCard(episode: episode)

                    EntryDetailDeleteAction(onDelete: { isShowingDeleteConfirmation = true })
                } else {
                    EntryDetailLoadingState(isLoading: isLoading)
                }
            }
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.top, 18)
            .padding(.bottom, 34)
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
                .frame(maxWidth: .infinity, alignment: .center)

            Button("Bearbeiten", action: onEdit)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(SymiColors.primaryPetrol.color)
                .frame(minHeight: SymiSize.minInteractiveHeight)
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
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .top, spacing: SymiSpacing.lg) {
                VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                    Text("Intensität")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(SymiColors.textSecondary.color)

                    Text(JournalEntryContext.intensityLabel(for: episode.intensity))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(SymiColors.textPrimary.color)
                        .minimumScaleFactor(SymiTypography.compactScaleFactor)

                    Text("\(episode.intensity)/10")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(SymiColors.textSecondary.color)
                        .monospacedDigit()
                }

                Spacer(minLength: SymiSpacing.md)

                EntryDetailFaceBadge()
            }

            EntryDetailProgressBar(value: Double(episode.intensity) / 10)
                .accessibilityLabel("Intensität")
                .accessibilityValue("\(episode.intensity) von 10")

            Text(intensityDescription)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(SymiColors.textPrimary.color.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SymiColors.onAccent.color, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: SymiStroke.hairline)
        )
        .shadow(
            color: SymiColors.primaryPetrol.color.opacity(0.06),
            radius: 24,
            x: SymiShadow.journalCardXOffset,
            y: 12
        )
    }

    private var intensityDescription: String {
        switch episode.intensity {
        case 1 ... 3:
            "Die Schmerzen waren leicht und gut im Alltag einzuordnen."
        case 4 ... 6:
            "Die Schmerzen waren spürbar, aber noch gut auszuhalten."
        case 7 ... 10:
            "Die Schmerzen waren deutlich und haben viel Aufmerksamkeit gebraucht."
        default:
            "Die Intensität wurde für diesen Eintrag nicht bewertet."
        }
    }
}

private struct EntryDetailFaceBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.95, green: 0.91, blue: 0.84))

            CalmFaceIcon()
                .stroke(SymiColors.textPrimary.color.opacity(0.70), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 30, height: 30)
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }
}

private struct CalmFaceIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.addEllipse(in: CGRect(x: width * 0.06, y: height * 0.04, width: width * 0.88, height: height * 0.90))

        path.move(to: CGPoint(x: width * 0.34, y: height * 0.40))
        path.addLine(to: CGPoint(x: width * 0.34, y: height * 0.42))

        path.move(to: CGPoint(x: width * 0.66, y: height * 0.40))
        path.addLine(to: CGPoint(x: width * 0.66, y: height * 0.42))

        path.move(to: CGPoint(x: width * 0.36, y: height * 0.63))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.64, y: height * 0.63),
            control: CGPoint(x: width * 0.50, y: height * 0.70)
        )

        return path
    }
}

private struct EntryDetailProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedValue = min(max(value, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.78, green: 0.54, blue: 0.27),
                                SymiColors.sage.color.opacity(0.88)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * clampedValue)
            }
        }
        .frame(height: 8)
    }
}

private struct EntryDetailContextCard: View {
    let episode: EpisodeRecord

    private var rows: [EntryDetailContextRowModel] {
        [
            EntryDetailContextRowModel(systemImage: "clock", title: JournalEntryContext.timeOfDay(for: episode.startedAt)),
            EntryDetailContextRowModel(systemImage: "head.profile", title: painLocationText),
            EntryDetailContextRowModel(systemImage: "note.text", title: noteText, isMultiline: true)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                EntryDetailContextRow(row: row)

                if index < rows.count - 1 {
                    Divider()
                        .overlay(Color.primary.opacity(0.06))
                        .padding(.leading, 48)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SymiColors.onAccent.color, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: SymiStroke.hairline)
        )
        .shadow(color: SymiColors.primaryPetrol.color.opacity(0.035), radius: 16, x: 0, y: 8)
    }

    private var painLocationText: String {
        episode.painLocation.trimmed.isEmpty ? "Kein Ort dokumentiert" : episode.painLocation.trimmed
    }

    private var noteText: String {
        episode.notes.trimmed.isEmpty ? "Keine Notiz dokumentiert." : episode.notes.trimmed
    }
}

private struct EntryDetailContextRow: View {
    let row: EntryDetailContextRowModel

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: row.systemImage)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(SymiColors.primaryPetrol.color.opacity(0.72))
                .frame(width: 32, height: 32)
                .background(SymiColors.sage.color.opacity(0.16), in: Circle())

            Text(row.title)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(SymiColors.textPrimary.color)
                .lineLimit(row.isMultiline ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct EntryDetailTriggerSection: View {
    let triggers: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mögliche Auslöser")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(SymiColors.textPrimary.color)

            if visibleTriggers.isEmpty {
                Text("Keine Auslöser dokumentiert.")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(SymiColors.textSecondary.color)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 9) {
                    ForEach(visibleTriggers, id: \.self) { trigger in
                        EntryDetailTriggerChip(title: trigger)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visibleTriggers: [String] {
        triggers.map(\.trimmed).filter { !$0.isEmpty }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 118), spacing: 9, alignment: .leading)]
    }
}

private struct EntryDetailTriggerChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(SymiColors.textPrimary.color.opacity(0.84))
            .lineLimit(1)
            .minimumScaleFactor(SymiTypography.tightChipScaleFactor)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(SymiColors.sage.color.opacity(0.26), in: Capsule())
    }
}

private struct EntryDetailMedicationCard: View {
    let episode: EpisodeRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eingenommen")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(SymiColors.textPrimary.color)

            Text(medicationText)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(SymiColors.textSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SymiColors.onAccent.color, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: SymiStroke.hairline)
        )
        .shadow(color: SymiColors.primaryPetrol.color.opacity(0.03), radius: 14, x: 0, y: 6)
    }

    private var medicationText: String {
        JournalEntryContext.medicationDetail(for: episode) ?? "Keine Medikation dokumentiert."
    }
}

private struct EntryDetailDeleteAction: View {
    let onDelete: () -> Void

    var body: some View {
        Button("Löschen", role: .destructive, action: onDelete)
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(SymiColors.intensityStrong.color)
            .frame(maxWidth: .infinity, minHeight: 54)
            .buttonStyle(.plain)
            .padding(.top, 2)
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

private struct EntryDetailContextRowModel: Identifiable {
    let id = UUID()
    let systemImage: String
    let title: String
    var isMultiline = false
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
