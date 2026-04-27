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
            VStack(alignment: .leading, spacing: SymiSpacing.xxxl) {
                EntryDetailHeader(
                    title: headerTitle,
                    onBack: { dismiss() },
                    onEdit: { isEditing = true }
                )

                if let episode {
                    EntryDetailHeroCard(episode: episode)

                    EntryDetailContextCard(episode: episode)

                    if episode.hasVisibleTriggers {
                        EntryDetailTriggerSection(triggers: episode.triggers)
                    }

                    EntryDetailMedicationCard(episode: episode)

                    EntryDetailDeleteAction(onDelete: { isShowingDeleteConfirmation = true })
                } else {
                    EntryDetailLoadingState(isLoading: isLoading)
                }
            }
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.top, SymiSpacing.xl)
            .padding(.bottom, SymiSpacing.entryDetailBottomPadding)
        }
        .background(ColorToken.Surface.appBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            ColorToken.Surface.topFade
            .frame(height: SymiSize.entryDetailTopFadeHeight)
            .allowsHitTesting(false)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .tint(ColorToken.Brand.primary)
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
                    .foregroundStyle(ColorToken.Text.onSurface)
                    .frame(width: SymiSize.minInteractiveHeight, height: SymiSize.minInteractiveHeight)
                    .background(ColorToken.Surface.headerControlBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zurück")

            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(ColorToken.Text.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(SymiTypography.compactScaleFactor)
                .frame(maxWidth: .infinity, alignment: .center)

            Button("Bearbeiten", action: onEdit)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(ColorToken.Brand.primary)
                .frame(minHeight: SymiSize.minInteractiveHeight)
                .buttonStyle(.plain)
        }
    }
}

private enum EntryDetailSurface {
    static let cornerRadius: CGFloat = 28
    static let shadowColor = ColorToken.Shadow.card
    static let shadowRadius: CGFloat = 24
    static let shadowYOffset: CGFloat = 10
    static let cardFill = ColorToken.Surface.primary
    static let highlight = ColorToken.Surface.cardHighlight
    static let iconFill = ColorToken.Surface.iconBackground
}

private struct EntryDetailHeroCard: View {
    let episode: EpisodeRecord

    private var painLevel: PainLevel {
        PainLevel(intensity: episode.intensity)
    }

    private var painToken: PainToken {
        ColorToken.Pain.token(for: painLevel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.entryDetailHeroSpacing) {
            HStack(alignment: .top, spacing: SymiSpacing.lg) {
                VStack(alignment: .leading, spacing: SymiSpacing.compact) {
                    Text("Intensität")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(ColorToken.Text.label)

                    VStack(alignment: .leading, spacing: SymiSpacing.zero) {
                        Text(JournalEntryContext.intensityLabel(for: episode.intensity))
                            .font(SymiTypography.entryDetailIntensityTitle)
                            .foregroundStyle(painToken.emphasizedText)
                            .minimumScaleFactor(SymiTypography.compactScaleFactor)

                        Text("\(episode.intensity)/10")
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(ColorToken.Text.label)
                            .monospacedDigit()
                    }
                }

                Spacer(minLength: SymiSpacing.md)

                EntryDetailFaceBadge(painLevel: painLevel, painToken: painToken)
            }

            EntryDetailProgressBar(value: Double(episode.intensity) / 10, painToken: painToken)
                .accessibilityLabel("Intensität")
                .accessibilityValue("\(episode.intensity) von 10")

            Text(intensityDescription)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(painToken.descriptionText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SymiSpacing.entryDetailHeroPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EntryDetailSurface.cardFill, in: RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous)
                .stroke(EntryDetailSurface.highlight, lineWidth: SymiStroke.hairline)
        )
        .shadow(
            color: EntryDetailSurface.shadowColor,
            radius: EntryDetailSurface.shadowRadius,
            x: SymiShadow.journalCardXOffset,
            y: EntryDetailSurface.shadowYOffset
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
    let painLevel: PainLevel
    let painToken: PainToken

    var body: some View {
        ZStack {
            Circle()
                .fill(painToken.faceBackground)

            CalmFaceIcon(painLevel: painLevel)
                .stroke(
                    painToken.icon,
                    style: StrokeStyle(lineWidth: SymiStroke.entryDetailFaceIcon, lineCap: .round, lineJoin: .round)
                )
                .frame(width: SymiSize.entryDetailFaceIcon, height: SymiSize.entryDetailFaceIcon)
        }
        .frame(width: SymiSize.entryDetailFaceBadge, height: SymiSize.entryDetailFaceBadge)
        .accessibilityHidden(true)
    }
}

private struct CalmFaceIcon: Shape {
    let painLevel: PainLevel

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.addEllipse(in: CGRect(x: width * 0.06, y: height * 0.04, width: width * 0.88, height: height * 0.90))

        path.move(to: CGPoint(x: width * 0.34, y: leftEyeStartY * height))
        path.addLine(to: CGPoint(x: width * 0.34, y: leftEyeEndY * height))

        path.move(to: CGPoint(x: width * 0.66, y: rightEyeStartY * height))
        path.addLine(to: CGPoint(x: width * 0.66, y: rightEyeEndY * height))

        path.move(to: CGPoint(x: width * 0.36, y: mouthY * height))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.64, y: mouthY * height),
            control: CGPoint(x: width * 0.50, y: mouthControlY * height)
        )

        return path
    }

    private var leftEyeStartY: CGFloat {
        switch painLevel {
        case .high:
            0.38
        case .none, .low, .medium:
            0.40
        }
    }

    private var leftEyeEndY: CGFloat {
        switch painLevel {
        case .high:
            0.42
        case .none, .low, .medium:
            0.42
        }
    }

    private var rightEyeStartY: CGFloat {
        switch painLevel {
        case .high:
            0.38
        case .none, .low, .medium:
            0.40
        }
    }

    private var rightEyeEndY: CGFloat {
        switch painLevel {
        case .high:
            0.42
        case .none, .low, .medium:
            0.42
        }
    }

    private var mouthY: CGFloat {
        switch painLevel {
        case .none:
            0.63
        case .low:
            0.64
        case .medium:
            0.63
        case .high:
            0.64
        }
    }

    private var mouthControlY: CGFloat {
        switch painLevel {
        case .none:
            0.68
        case .low:
            0.62
        case .medium:
            0.67
        case .high:
            0.59
        }
    }
}

private struct EntryDetailProgressBar: View {
    let value: Double
    let painToken: PainToken

    var body: some View {
        GeometryReader { proxy in
            let clampedValue = min(max(value, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ColorToken.Surface.progressTrack)

                Capsule()
                    .fill(painToken.progressGradient)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(ColorToken.Surface.progressHighlight)
                            .frame(height: SymiSize.entryDetailProgressHighlightHeight)
                            .padding(.horizontal, SymiSize.accessibilityMarker)
                    }
                    .frame(width: proxy.size.width * clampedValue)
            }
        }
        .frame(height: SymiSize.entryDetailProgressBarHeight)
    }
}

private struct EntryDetailContextCard: View {
    let episode: EpisodeRecord

    private var painLevel: PainLevel {
        PainLevel(intensity: episode.intensity)
    }

    private var rows: [EntryDetailContextRowModel] {
        [
            EntryDetailContextRowModel(systemImage: "clock", title: JournalEntryContext.timeOfDay(for: episode.startedAt)),
            EntryDetailContextRowModel(
                systemImage: "brain.head.profile",
                title: painLocationText,
                hierarchy: .secondary,
                category: .pain(painLevel)
            ),
            EntryDetailContextRowModel(systemImage: "note.text", title: noteText, hierarchy: .tertiary, category: .note)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.entryDetailContextRowSpacing) {
            ForEach(rows) { row in
                EntryDetailContextRow(row: row)
            }
        }
        .padding(.horizontal, SymiSpacing.entryDetailContextHorizontalPadding)
        .padding(.vertical, SymiSpacing.entryDetailContextVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EntryDetailSurface.cardFill, in: RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous)
                .stroke(EntryDetailSurface.highlight, lineWidth: SymiStroke.hairline)
        )
        .shadow(
            color: EntryDetailSurface.shadowColor,
            radius: EntryDetailSurface.shadowRadius,
            x: SymiShadow.cardXOffset,
            y: EntryDetailSurface.shadowYOffset
        )
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
        HStack(alignment: .center, spacing: SymiSpacing.lg) {
            EntryDetailContextIcon(systemImage: row.systemImage, category: row.category)

            Text(row.title)
                .font(row.hierarchy.font)
                .foregroundStyle(row.hierarchy.color)
                .lineLimit(row.hierarchy.lineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, SymiSpacing.entryDetailContextRowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct EntryDetailContextIcon: View {
    let systemImage: String
    let category: EntryDetailContextCategory

    var body: some View {
        Image(systemName: systemImage)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: iconSize, weight: .medium, design: .rounded))
            .foregroundStyle(category.iconColor)
            .frame(width: SymiSize.entryDetailContextIcon, height: SymiSize.entryDetailContextIcon)
            .offset(iconOffset)
            .background(EntryDetailSurface.iconFill, in: Circle())
    }

    private var iconSize: CGFloat {
        switch systemImage {
        case "brain.head.profile":
            15.5
        case "note.text":
            15.8
        default:
            16
        }
    }

    private var iconOffset: CGSize {
        switch systemImage {
        case "brain.head.profile":
            CGSize(width: -0.5, height: 0.2)
        case "note.text":
            CGSize(width: 0, height: 0.4)
        default:
            .zero
        }
    }
}

private struct EntryDetailTriggerSection: View {
    let triggers: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.entryDetailTriggerSectionSpacing) {
            Text("Mögliche Auslöser")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(ColorToken.Text.onSurface)

            LazyVGrid(columns: columns, alignment: chipAlignment, spacing: SymiSpacing.entryDetailTriggerGridSpacing) {
                ForEach(visibleTriggers, id: \.self) { trigger in
                    EntryDetailTriggerChip(title: trigger)
                }
            }
            .padding(SymiSpacing.entryDetailTriggerCardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EntryDetailSurface.cardFill, in: RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous)
                    .stroke(EntryDetailSurface.highlight, lineWidth: SymiStroke.hairline)
            )
            .shadow(
                color: EntryDetailSurface.shadowColor,
                radius: EntryDetailSurface.shadowRadius,
                x: SymiShadow.cardXOffset,
                y: EntryDetailSurface.shadowYOffset
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visibleTriggers: [String] {
        triggers.map(\.trimmed).filter { !$0.isEmpty }
    }

    private var chipAlignment: HorizontalAlignment {
        visibleTriggers.count == 1 ? .center : .leading
    }

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: SymiSize.entryDetailTriggerGridMinWidth),
                spacing: SymiSpacing.entryDetailTriggerGridColumnSpacing,
                alignment: .leading
            )
        ]
    }
}

private struct EntryDetailTriggerChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(ColorToken.Trigger.foreground)
            .lineLimit(1)
            .minimumScaleFactor(SymiTypography.tightChipScaleFactor)
            .padding(.horizontal, SymiSpacing.entryDetailTriggerChipHorizontalPadding)
            .padding(.vertical, SymiSpacing.entryDetailTriggerChipVerticalPadding)
            .background(ColorToken.Trigger.background, in: Capsule())
    }
}

private struct EntryDetailMedicationCard: View {
    let episode: EpisodeRecord

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xs) {
            Text("Eingenommen")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(ColorToken.Medication.foreground)

            Text(medicationText)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(ColorToken.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SymiSpacing.entryDetailMedicationCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EntryDetailSurface.cardFill, in: RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous)
                .stroke(EntryDetailSurface.highlight, lineWidth: SymiStroke.hairline)
        )
        .shadow(
            color: EntryDetailSurface.shadowColor,
            radius: EntryDetailSurface.shadowRadius,
            x: SymiShadow.cardXOffset,
            y: EntryDetailSurface.shadowYOffset
        )
    }

    private var medicationText: String {
        JournalEntryContext.medicationDetail(for: episode) ?? "Keine Medikation"
    }
}

private struct EntryDetailDeleteAction: View {
    let onDelete: () -> Void

    var body: some View {
        Button("Löschen", role: .destructive, action: onDelete)
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(ColorToken.Text.destructive)
            .frame(maxWidth: .infinity, minHeight: SymiSize.entryDetailDeleteHeight)
            .buttonStyle(EntryDetailDestructiveTextButtonStyle())
            .padding(.top, SymiSpacing.micro)
            .padding(.bottom, SymiSpacing.entryDetailDeleteBottomPadding)
    }
}

private struct EntryDetailDestructiveTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? SymiOpacity.entryDetailDeletePressed : SymiOpacity.opaque)
            .scaleEffect(configuration.isPressed ? SymiOpacity.entryDetailDeleteScale : SymiOpacity.opaque)
            .animation(.easeOut(duration: SymiAnimation.quickDuration), value: configuration.isPressed)
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
    var hierarchy: EntryDetailContextHierarchy = .primary
    var category: EntryDetailContextCategory = .neutral
}

private enum EntryDetailContextHierarchy {
    case primary
    case secondary
    case tertiary

    var font: Font {
        switch self {
        case .primary:
            .system(.title3, design: .rounded).weight(.semibold)
        case .secondary:
            .system(.body, design: .rounded).weight(.medium)
        case .tertiary:
            .system(.subheadline, design: .rounded).weight(.medium)
        }
    }

    var color: Color {
        switch self {
        case .primary:
            ColorToken.Text.primary
        case .secondary:
            ColorToken.Text.secondary
        case .tertiary:
            ColorToken.Text.tertiary
        }
    }

    var lineLimit: Int {
        switch self {
        case .primary, .secondary:
            1
        case .tertiary:
            2
        }
    }
}

private enum EntryDetailContextCategory {
    case neutral
    case pain(PainLevel)
    case note

    var iconColor: Color {
        switch self {
        case .neutral:
            ColorToken.Neutral.icon
        case let .pain(level):
            ColorToken.Pain.token(for: level).icon
        case .note:
            ColorToken.Text.secondary
        }
    }
}

private extension EpisodeRecord {
    var hasVisibleTriggers: Bool {
        triggers.contains { !$0.trimmed.isEmpty }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
