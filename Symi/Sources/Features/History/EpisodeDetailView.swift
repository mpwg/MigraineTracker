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
            VStack(alignment: .leading, spacing: 24) {
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
            .padding(.top, 18)
            .padding(.bottom, 76)
        }
        .background(SymiColors.warmBackground.color.ignoresSafeArea())
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [
                    SymiColors.warmBackground.color,
                    SymiColors.warmBackground.color.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 16)
            .allowsHitTesting(false)
        }
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

private enum EntryDetailSurface {
    static let cornerRadius: CGFloat = 28
    static let shadowColor = SymiColors.primaryPetrol.color.opacity(0.026)
    static let shadowRadius: CGFloat = 22
    static let shadowYOffset: CGFloat = 10
    static let cardFill = Color(red: 1.0, green: 0.996, blue: 0.982)
    static let highlight = Color.white.opacity(0.74)
    static let iconFill = Color(red: 0.91, green: 0.95, blue: 0.90)
}

private struct EntryDetailHeroCard: View {
    let episode: EpisodeRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack(alignment: .top, spacing: SymiSpacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Intensität")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(SymiColors.textSecondary.color)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(JournalEntryContext.intensityLabel(for: episode.intensity))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(SymiColors.textPrimary.color.opacity(0.98))
                            .minimumScaleFactor(SymiTypography.compactScaleFactor)

                        Text("\(episode.intensity)/10")
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(SymiColors.textSecondary.color)
                            .monospacedDigit()
                    }
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
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.965, green: 0.918, blue: 0.835))

            CalmFaceIcon()
                .stroke(SymiColors.primaryPetrol.color.opacity(0.60), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 32, height: 32)
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
            control: CGPoint(x: width * 0.50, y: height * 0.67)
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
                    .fill(Color.primary.opacity(0.075))

                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: SymiColors.noteAmber.color.opacity(0.98), location: 0),
                                .init(color: Color(red: 0.86, green: 0.69, blue: 0.43), location: 0.42),
                                .init(color: Color(red: 0.70, green: 0.78, blue: 0.58), location: 0.68),
                                .init(color: SymiColors.sage.color.opacity(0.98), location: 1)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 2)
                            .padding(.horizontal, 1)
                    }
                    .frame(width: proxy.size.width * clampedValue)
            }
        }
        .frame(height: 11)
    }
}

private struct EntryDetailContextCard: View {
    let episode: EpisodeRecord

    private var rows: [EntryDetailContextRowModel] {
        [
            EntryDetailContextRowModel(systemImage: "clock", title: JournalEntryContext.timeOfDay(for: episode.startedAt)),
            EntryDetailContextRowModel(systemImage: "brain.head.profile", title: painLocationText, hierarchy: .secondary),
            EntryDetailContextRowModel(systemImage: "note.text", title: noteText, hierarchy: .tertiary)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(rows) { row in
                EntryDetailContextRow(row: row)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EntryDetailSurface.cardFill, in: RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous)
                .stroke(EntryDetailSurface.highlight, lineWidth: SymiStroke.hairline)
        )
        .shadow(color: EntryDetailSurface.shadowColor, radius: EntryDetailSurface.shadowRadius, x: 0, y: EntryDetailSurface.shadowYOffset)
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
            EntryDetailContextIcon(systemImage: row.systemImage)

            Text(row.title)
                .font(row.hierarchy.font)
                .foregroundStyle(row.hierarchy.color)
                .lineLimit(row.hierarchy.lineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct EntryDetailContextIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: iconSize, weight: .medium, design: .rounded))
            .foregroundStyle(SymiColors.primaryPetrol.color.opacity(0.62))
            .frame(width: 32, height: 32)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Mögliche Auslöser")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(SymiColors.textPrimary.color)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(visibleTriggers, id: \.self) { trigger in
                    EntryDetailTriggerChip(title: trigger)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EntryDetailSurface.cardFill, in: RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous)
                    .stroke(EntryDetailSurface.highlight, lineWidth: SymiStroke.hairline)
            )
            .shadow(color: EntryDetailSurface.shadowColor, radius: EntryDetailSurface.shadowRadius, x: 0, y: EntryDetailSurface.shadowYOffset)
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
            .background(SymiColors.sage.color.opacity(0.22), in: Capsule())
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
        .background(EntryDetailSurface.cardFill, in: RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EntryDetailSurface.cornerRadius, style: .continuous)
                .stroke(EntryDetailSurface.highlight, lineWidth: SymiStroke.hairline)
        )
        .shadow(color: EntryDetailSurface.shadowColor, radius: EntryDetailSurface.shadowRadius, x: 0, y: EntryDetailSurface.shadowYOffset)
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
            .foregroundStyle(SymiColors.intensityStrong.color.opacity(0.78))
            .frame(maxWidth: .infinity, minHeight: 54)
            .buttonStyle(EntryDetailDestructiveTextButtonStyle())
            .padding(.top, 2)
            .padding(.bottom, 38)
    }
}

private struct EntryDetailDestructiveTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.68 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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
            SymiColors.textPrimary.color.opacity(0.98)
        case .secondary:
            SymiColors.textPrimary.color.opacity(0.84)
        case .tertiary:
            SymiColors.textSecondary.color.opacity(0.82)
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
