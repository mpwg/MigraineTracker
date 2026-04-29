import QuickLook
import SwiftUI

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
                                SymiColors.sage.color.opacity(0.12),
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

                VStack(spacing: SymiSpacing.lg) {
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
                    .foregroundStyle(SymiColors.textSecondary.color.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, SymiSpacing.md)
            }
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.vertical, layout.verticalPadding)
            .padding(.bottom, 100)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
        }
        .overlay(
            LinearGradient(
                colors: [Color.clear, Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
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
            ReportDateSelectionSheet(selectedDateRange: $selectedDateRange)
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
        isCompactHeight ? 96 : 104
    }

    var heroMaxWidth: CGFloat {
        isCompactHeight ? 300 : 340
    }

    var heroVerticalPadding: CGFloat {
        isCompactHeight ? -SymiSpacing.md : -SymiSpacing.sm
    }

    var headerTopPadding: CGFloat {
        isCompactHeight ? -SymiSpacing.md : -SymiSpacing.xs
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
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last7Days:
            "Letzte 7 Tage"
        case .lastMonth:
            "Letzter Monat"
        case .last3Months:
            "Letzte 3 Monate"
        case .custom:
            "Benutzerdefiniert"
        }
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
                        .frame(width: 36, height: 36)
                        .background(SymiColors.mist.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("Bericht")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SymiColors.textPrimary.color)
                }

                Text("Alle wichtigen Einträge kompakt und verständlich aufbereitet")
                    .font(.subheadline)
                    .foregroundStyle(SymiColors.textSecondary.color.opacity(0.86))
            }

            Button(action: openDateSelection) {
                HStack(spacing: SymiSpacing.lg) {
                    VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                        Text(selectedDateRange.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(SymiColors.textPrimary.color)

                        Text("Zeitraum deiner Auswertung")
                            .font(.subheadline)
                            .foregroundStyle(SymiColors.textSecondary.color.opacity(0.72))
                    }

                    Spacer(minLength: SymiSpacing.lg)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SymiColors.textSecondary.color.opacity(0.58))
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
            .foregroundStyle(SymiColors.textPrimary.color.opacity(0.86))

            Text("Der Bericht wird beim Öffnen automatisch erstellt")
                .font(.footnote.weight(.regular))
                .foregroundStyle(SymiColors.textSecondary.color.opacity(0.5))

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
                colors: [Color.clear, Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            Button(action: action) {
                HStack(spacing: SymiSpacing.xs) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
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
        .frame(height: 100)
        .shadow(color: SymiColors.primaryPetrol.color.opacity(0.12), radius: 18, x: 0, y: -8)
    }
}

private struct ReportDateSelectionSheet: View {
    @Binding var selectedDateRange: ReportDateRange
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            Text("Zeitraum")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SymiColors.textPrimary.color)

            VStack(spacing: SymiSpacing.xs) {
                ForEach(ReportDateRange.allCases) { range in
                    Button {
                        selectedDateRange = range
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
                        .frame(minHeight: 48)
                        .background(SymiColors.mist.color.opacity(selectedDateRange == range ? 0.7 : 0), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: SymiColors.primaryPetrol.color.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}

private struct ReportActionCardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(SymiSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: SymiColors.primaryPetrol.color.opacity(0.045), radius: 10, x: 0, y: 5)
    }
}

private struct ReportDateRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, SymiSpacing.sm)
            .padding(.vertical, SymiSpacing.xs)
            .background(
                SymiColors.mist.color.opacity(configuration.isPressed ? 0.72 : 0),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
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
            .foregroundStyle(.white)
            .padding(.vertical, SymiSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: SymiSize.primaryButtonHeight)
            .background(
                LinearGradient(
                    colors: [
                        SymiColors.primaryPetrol.color.opacity(configuration.isPressed ? 0.88 : 1),
                        SymiColors.primaryPetrol.color.opacity(configuration.isPressed ? 0.82 : 0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: SymiRadius.button, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .shadow(color: SymiColors.primaryPetrol.color.opacity(configuration.isPressed ? 0.22 : 0.18), radius: configuration.isPressed ? 12 : 10, x: 0, y: configuration.isPressed ? 6 : 5)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct BackupSettingsCardView: View {
    @State private var controller: DataExportController

    init(dependencies: DataExportFeatureDependencies) {
        _controller = State(initialValue: dependencies.makeDataExportController())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            VStack(alignment: .leading, spacing: SymiSpacing.compact) {
                Text("Backup erstellen")
                    .font(.headline)

                Text("Sichert alle Einträge und Vorlagen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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

            if let dataTransferMessage = controller.dataTransferMessage {
                Text(dataTransferMessage)
                    .font(.subheadline)
                    .foregroundStyle(dataTransferMessage.contains("Fehler") ? AppTheme.symiCoral : .secondary)
            }
        }
        .padding(.vertical, SymiSpacing.xs)
        .brandGroupedRow()
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
