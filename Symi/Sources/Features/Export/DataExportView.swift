import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct ReportView: View {
    @State private var controller: DataExportController
    @State private var pdfURL: URL?
    @State private var reportPreviewRequested = false
    @State private var reportPreviewRequestedAt: ContinuousClock.Instant?
    @State private var viewportHeight: CGFloat = 800
    @State private var selectedDateRange: ReportDateRange = .lastMonth
    @State private var isDateSelectionPresented = false

    private let clock = ContinuousClock()

    init(dependencies: DataExportFeatureDependencies) {
        _controller = State(initialValue: dependencies.makeDataExportController())
    }

    var body: some View {
        let layout = ReportLayoutMetrics(availableHeight: viewportHeight)

        ScrollView {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                Image("DoctorConversationHero")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: layout.heroMaxWidth)
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.heroHeight)
                    .padding(.vertical, layout.heroVerticalPadding)
                    .background(
                        RadialGradient(
                            colors: [
                                SymiColors.sage.color.opacity(SymiOpacity.faintSurface),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 24,
                            endRadius: 220
                        )
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                    Text("Für dein Arztgespräch")
                        .font(layout.titleFont)
                        .foregroundStyle(SymiColors.textPrimary.color)

                    Text("Alle wichtigen Einträge klar und verständlich zusammengefasst")
                        .font(.headline)
                        .foregroundStyle(SymiColors.textSecondary.color)
                }
                .padding(.top, layout.headerTopPadding)

                VStack(spacing: SymiSpacing.xxl) {
                    ReportInfoCardView(
                        selectedDateRange: selectedDateRange,
                        openDateSelection: openDateSelection
                    )

                    ReportActionCardView(
                        errorMessage: controller.exportErrorMessage
                    )
                }
                .padding(.top, layout.cardsTopPadding)

                Text("Kein Ersatz für eine ärztliche Diagnose")
                    .font(.caption)
                    .foregroundStyle(SymiColors.textSecondary.color.opacity(SymiOpacity.textMuted))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, SymiSpacing.md)
            }
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.vertical, layout.verticalPadding)
            .padding(.bottom, SymiSpacing.reportBottomPadding)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
        }
        .overlay(
            LinearGradient(
                colors: [Color.clear, Color(.systemBackground).opacity(SymiOpacity.appBackgroundSurface)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: SymiSize.reportFadeHeight)
            .allowsHitTesting(false),
            alignment: .bottom
        )
        .overlay(alignment: .bottom) {
            FloatingReportButton(
                isLoading: controller.isLoadingSummary || controller.isPreparingPDF,
                action: openReport
            )
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        viewportHeight = proxy.size.height
                    }
                    .onChange(of: proxy.size.height) { _, newValue in
                        viewportHeight = newValue
                    }
            }
        }
        .navigationTitle("Bericht")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.symiPetrol)
        .background(SymiColors.warmBackground.color.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            controller.loadInitialSummary()
        }
        .onChange(of: controller.exportURL) { _, newValue in
            guard reportPreviewRequested, let newValue else { return }
            presentReportPreview(newValue)
        }
        .onChange(of: controller.exportErrorMessage) { _, newValue in
            guard newValue != nil else { return }
            reportPreviewRequested = false
            reportPreviewRequestedAt = nil
        }
        .onChange(of: pdfURL) { _, newValue in
            if newValue == nil {
                reportPreviewRequested = false
                reportPreviewRequestedAt = nil
            }
        }
        .sheet(isPresented: $isDateSelectionPresented) {
            ReportDateSelectionSheet(
                selectedDateRange: selectedDateRange,
                selectDateRange: selectDateRange
            )
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
        .quickLookPreview($pdfURL)
    }

    private func openReport() {
        guard !controller.isLoadingSummary, !controller.isPreparingPDF else { return }
        reportPreviewRequested = true
        reportPreviewRequestedAt = clock.now
        controller.createPDF()
    }

    private func openDateSelection() {
        isDateSelectionPresented = true
    }

    private func selectDateRange(_ range: ReportDateRange) {
        selectedDateRange = range
        let dateRange = range.dateRange()
        controller.setDateRange(startDate: dateRange.startDate, endDate: dateRange.endDate)
    }

    private func presentReportPreview(_ url: URL) {
        Task {
            if let requestedAt = reportPreviewRequestedAt {
                let elapsed = requestedAt.duration(to: clock.now)
                if elapsed < .milliseconds(350) {
                    try? await Task.sleep(for: .milliseconds(350) - elapsed)
                }
            }

            guard !Task.isCancelled else { return }
            pdfURL = url
        }
    }
}

private struct ReportLayoutMetrics {
    let isCompactHeight: Bool

    init(availableHeight: CGFloat) {
        isCompactHeight = availableHeight < 720
    }

    var sectionSpacing: CGFloat {
        isCompactHeight ? SymiSpacing.xs : SymiSpacing.xxl
    }

    var heroHeight: CGFloat {
        isCompactHeight ? SymiSize.reportHeroCompactHeight : SymiSize.reportHeroRegularHeight
    }

    var heroMaxWidth: CGFloat {
        isCompactHeight ? SymiSize.reportHeroCompactMaxWidth : SymiSize.reportHeroRegularMaxWidth
    }

    var heroVerticalPadding: CGFloat {
        isCompactHeight ? SymiSpacing.zero : SymiSpacing.xs
    }

    var headerTopPadding: CGFloat {
        isCompactHeight ? SymiSpacing.sm : SymiSpacing.md
    }

    var verticalPadding: CGFloat {
        isCompactHeight ? SymiSpacing.lg : SymiSpacing.xxxl
    }

    var cardsTopPadding: CGFloat {
        isCompactHeight ? SymiSpacing.xs : SymiSpacing.lg
    }

    var titleFont: Font {
        isCompactHeight ? .title.weight(.semibold) : .largeTitle.weight(.semibold)
    }
}

private enum ReportDateRange: String, CaseIterable, Identifiable {
    case last7Days
    case lastMonth
    case last3Months

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last7Days:
            "Letzte 7 Tage"
        case .lastMonth:
            "Letzter Monat"
        case .last3Months:
            "Letzte 3 Monate"
        }
    }

    func dateRange(calendar: Calendar = .current, now: Date = .now) -> (startDate: Date, endDate: Date) {
        let startDate: Date
        switch self {
        case .last7Days:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .lastMonth:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .last3Months:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        }

        return (startDate, now)
    }
}

private struct ReportInfoCardView: View {
    let selectedDateRange: ReportDateRange
    let openDateSelection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            VStack(alignment: .leading, spacing: SymiSpacing.md) {
                HStack(spacing: SymiSpacing.md) {
                    Image(systemName: "doc.text")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(SymiColors.sage.color)
                        .frame(width: SymiSize.homeCalendarDayNumber, height: SymiSize.homeCalendarDayNumber)
                        .background(SymiColors.mist.color, in: RoundedRectangle(cornerRadius: SymiRadius.flowPill, style: .continuous))

                    Text("Bericht")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SymiColors.textPrimary.color)
                }

                Text("Alle wichtigen Einträge kompakt und verständlich aufbereitet")
                    .font(.subheadline)
                    .foregroundStyle(SymiColors.textSecondary.color.opacity(SymiOpacity.heroSecondaryText))
            }

            Button(action: openDateSelection) {
                HStack(spacing: SymiSpacing.lg) {
                    VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                        Text(selectedDateRange.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(SymiColors.textPrimary.color)

                        Text("Zeitraum deiner Auswertung")
                            .font(.subheadline)
                            .foregroundStyle(SymiColors.textSecondary.color.opacity(SymiOpacity.textReadableSecondary))
                    }

                    Spacer(minLength: SymiSpacing.lg)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SymiColors.textSecondary.color.opacity(SymiOpacity.textReadableSecondary))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ReportDateRowButtonStyle())
            .accessibilityHint("Öffnet die Zeitraum-Auswahl")
        }
        .reportCardSurface()
    }
}

private struct ReportActionCardView: View {
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            Label {
                Text("Unterstützt dich im Gespräch mit deinem Arzt")
            } icon: {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(SymiColors.sage.color)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SymiColors.textPrimary.color.opacity(SymiOpacity.heroSecondaryText))

            Text("Der Bericht wird beim Öffnen automatisch erstellt")
                .font(.footnote.weight(.regular))
                .foregroundStyle(SymiColors.textSecondary.color.opacity(SymiOpacity.textMuted))

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.symiCoral)
            }
        }
        .reportActionCardSurface()
    }
}

private struct FloatingReportButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.clear, Color(.systemBackground).opacity(SymiOpacity.appBackgroundSurface)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            Button(action: action) {
                HStack(spacing: SymiSpacing.xs) {
                    if isLoading {
                        ProgressView()
                            .tint(SymiColors.onAccent.color)
                    } else {
                        Image(systemName: "doc.text.magnifyingglass")
                            .imageScale(.medium)
                    }

                    Text(isLoading ? "Bericht wird erstellt" : "Bericht ansehen")
                }
            }
            .buttonStyle(ReportPrimaryButtonStyle())
            .disabled(isLoading)
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.bottom, SymiSpacing.lg)
        }
        .frame(height: SymiSize.reportFloatingButtonHeight)
        .overlay(
            Divider().opacity(SymiOpacity.softFill),
            alignment: .top
        )
        .shadow(color: SymiColors.primaryPetrol.color.opacity(SymiOpacity.faintSurface), radius: 18, x: 0, y: -8)
    }
}

private struct ReportDateSelectionSheet: View {
    let selectedDateRange: ReportDateRange
    let selectDateRange: (ReportDateRange) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            Text("Zeitraum")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SymiColors.textPrimary.color)

            VStack(spacing: SymiSpacing.xs) {
                ForEach(ReportDateRange.allCases) { range in
                    Button {
                        selectDateRange(range)
                        dismiss()
                    } label: {
                        HStack(spacing: SymiSpacing.md) {
                            Text(range.title)
                                .font(.body)
                                .foregroundStyle(SymiColors.textPrimary.color)

                            Spacer()

                            if selectedDateRange == range {
                                Image(systemName: "checkmark")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(SymiColors.primaryPetrol.color)
                            }
                        }
                        .padding(.horizontal, SymiSpacing.lg)
                        .frame(minHeight: SymiSize.reportDateRowMinHeight)
                        .background(
                            SymiColors.mist.color.opacity(selectedDateRange == range ? SymiOpacity.appBackgroundSurface : SymiOpacity.entryDetailTopFadeEnd),
                            in: RoundedRectangle(cornerRadius: SymiRadius.flowTile, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(SymiSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SymiColors.warmBackground.color)
    }
}

private struct ReportCardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(SymiSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SymiColors.card.color, in: RoundedRectangle(cornerRadius: SymiRadius.card, style: .continuous))
            .shadow(color: SymiColors.primaryPetrol.color.opacity(SymiOpacity.hairline), radius: 16, x: 0, y: 8)
    }
}

private struct ReportActionCardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(SymiSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SymiColors.card.color, in: RoundedRectangle(cornerRadius: SymiRadius.card, style: .continuous))
            .shadow(color: SymiColors.primaryPetrol.color.opacity(SymiOpacity.glassRegularShadow), radius: 10, x: 0, y: 5)
    }
}

private struct ReportDateRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, SymiSpacing.sm)
            .padding(.vertical, SymiSpacing.xs)
            .background(
                SymiColors.mist.color.opacity(configuration.isPressed ? SymiOpacity.textReadableSecondary : SymiOpacity.entryDetailTopFadeEnd),
                in: RoundedRectangle(cornerRadius: SymiRadius.flowTile, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? SymiOpacity.reportPressedScale : SymiOpacity.opaque)
            .opacity(configuration.isPressed ? SymiOpacity.pressedContent : SymiOpacity.opaque)
            .animation(.spring(response: 0.22, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

private extension View {
    func reportCardSurface() -> some View {
        modifier(ReportCardSurfaceModifier())
    }

    func reportActionCardSurface() -> some View {
        modifier(ReportActionCardSurfaceModifier())
    }
}

private struct ReportPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SymiTypography.button)
            .foregroundStyle(SymiColors.onAccent.color)
            .padding(.vertical, SymiSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: SymiSize.primaryButtonHeight)
            .background(
                LinearGradient(
                    colors: [
                        SymiColors.primaryPetrol.color.opacity(configuration.isPressed ? SymiOpacity.reportPrimaryPressedStart : SymiOpacity.opaque),
                        SymiColors.primaryPetrol.color.opacity(configuration.isPressed ? SymiOpacity.reportPrimaryPressedEnd : SymiOpacity.reportPrimaryRestingEnd)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: SymiRadius.button, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? SymiOpacity.reportPrimaryPressedScale : SymiOpacity.opaque)
            .shadow(
                color: SymiColors.primaryPetrol.color.opacity(configuration.isPressed ? SymiOpacity.backgroundAccent : SymiOpacity.secondaryFill),
                radius: configuration.isPressed ? SymiSpacing.md : SymiSpacing.sm,
                x: SymiSpacing.zero,
                y: configuration.isPressed ? SymiSpacing.compact : SymiSpacing.xxs
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct BackupSettingsCardView: View {
    @State private var controller: DataExportController
    @State private var isImportPickerPresented = false

    init(dependencies: DataExportFeatureDependencies) {
        _controller = State(initialValue: dependencies.makeDataExportController())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            backupExportSection

            Divider()

            backupImportSection

            if let importRollbackBackupURL = controller.importRollbackBackupURL {
                ShareLink(item: importRollbackBackupURL) {
                    Label("Rollback-Backup teilen", systemImage: "arrow.uturn.backward.circle")
                }
            }

            transferMessage
        }
        .padding(.vertical, SymiSpacing.xs)
        .brandGroupedRow()
        .fileImporter(
            isPresented: $isImportPickerPresented,
            allowedContentTypes: [.symiJSON5, .json],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else {
                    throw CocoaError(.fileNoSuchFile)
                }
                controller.importBackup(from: .success(url))
            } catch {
                controller.importBackup(from: .failure(error))
            }
        }
    }

    private var backupExportSection: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            BackupSectionHeaderView(
                title: "Backup erstellen",
                subtitle: "Sichert alle Einträge und Vorlagen"
            )

            Button {
                controller.createBackup()
            } label: {
                if controller.dataExportURL == nil && controller.dataTransferMessage == nil {
                    Text("Backup erstellen")
                } else {
                    Label("Backup erstellen", systemImage: "externaldrive.badge.plus")
                }
            }
            .buttonStyle(SymiSecondaryButtonStyle())

            if let dataExportURL = controller.dataExportURL {
                ShareLink(item: dataExportURL) {
                    Label("Backup teilen", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var backupImportSection: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            BackupSectionHeaderView(
                title: "Backup importieren",
                subtitle: "Prüft eine JSON5-Datei und zeigt Änderungen vor dem Import"
            )

            Button {
                isImportPickerPresented = true
            } label: {
                Label("Backup-Datei auswählen", systemImage: "doc.badge.plus")
            }
            .buttonStyle(SymiSecondaryButtonStyle())
            .disabled(controller.isPreparingImportPreview || controller.isApplyingImport)
            .accessibilityIdentifier("backup-import-select-file")

            if controller.isPreparingImportPreview {
                ProgressView("Import-Vorschau wird geprüft")
                    .font(.subheadline)
                    .accessibilityIdentifier("backup-import-preview-loading")
            }

            if let preview = controller.importPreview {
                BackupImportPreviewView(
                    preview: preview,
                    isApplyingImport: controller.isApplyingImport,
                    confirmImport: controller.confirmImport,
                    cancelImport: controller.cancelImportPreview
                )
                .accessibilityIdentifier("backup-import-preview")
            }
        }
    }

    @ViewBuilder
    private var transferMessage: some View {
        if let dataTransferMessage = controller.dataTransferMessage {
            Text(dataTransferMessage)
                .font(.subheadline)
                .foregroundStyle(dataTransferMessage.contains("Fehler") ? AppTheme.symiCoral : .secondary)
        }
    }
}

private struct BackupSectionHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.compact) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BackupImportPreviewView: View {
    let preview: BackupImportPreview
    let isApplyingImport: Bool
    let confirmImport: () -> Void
    let cancelImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.md) {
            VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                Label(preview.hasChanges ? "Änderungen gefunden" : "Keine Änderungen", systemImage: preview.hasChanges ? "checkmark.circle" : "equal.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(preview.hasChanges ? SymiColors.primaryPetrol.color : .secondary)

                Text("Backup vom \(preview.exportedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let dateRange = preview.dateRange {
                    Text("\(dateRange.start.formatted(date: .abbreviated, time: .omitted)) bis \(dateRange.end.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                BackupImportMetricRow(title: "Einträge", newCount: preview.newEpisodes, changedCount: preview.changedEpisodes, deletedCount: preview.deletedEpisodes)
                BackupImportMetricRow(title: "Vorlagen", newCount: preview.newMedicationDefinitions, changedCount: preview.changedMedicationDefinitions)
                BackupImportMetricRow(title: "Dauermedikation", newCount: preview.newContinuousMedications, changedCount: preview.changedContinuousMedications)
            }

            if preview.conflicts.isEmpty {
                Label("Keine Konflikte erkannt", systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                    Label("\(preview.conflicts.count) Konflikt\(preview.conflicts.count == 1 ? "" : "e")", systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.symiCoral)

                    ForEach(preview.conflicts, id: \.self) { conflict in
                        Text(conflict)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: SymiSpacing.sm) {
                Button("Abbrechen", role: .cancel, action: cancelImport)
                    .buttonStyle(SymiSecondaryButtonStyle())
                    .disabled(isApplyingImport)
                    .accessibilityIdentifier("backup-import-cancel")

                Button {
                    confirmImport()
                } label: {
                    if isApplyingImport {
                        ProgressView()
                    } else {
                        Label("Import bestätigen", systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(SymiSecondaryButtonStyle())
                .disabled(!preview.hasChanges || isApplyingImport)
                .accessibilityIdentifier("backup-import-confirm")
            }
        }
        .padding(SymiSpacing.md)
        .background(
            SymiColors.mist.color.opacity(SymiOpacity.entryDetailTopFadeEnd),
            in: RoundedRectangle(cornerRadius: SymiRadius.flowTile, style: .continuous)
        )
    }
}

private struct BackupImportMetricRow: View {
    let title: String
    let newCount: Int
    let changedCount: Int
    var deletedCount = 0

    var body: some View {
        Text("\(title): \(summary)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var summary: String {
        let values = [
            ("neu", newCount),
            ("geändert", changedCount),
            ("gelöscht", deletedCount)
        ]
        .filter { $0.1 > 0 }
        .map { "\($0.1) \($0.0)" }

        return values.isEmpty ? "keine Änderungen" : values.joined(separator: ", ")
    }
}

struct DataBackupSettingsView: View {
    let dependencies: DataExportFeatureDependencies

    var body: some View {
        List {
            Section("Daten") {
                BackupSettingsCardView(dependencies: dependencies)
            }
        }
        .navigationTitle("Backup")
        .brandGroupedScreen()
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
