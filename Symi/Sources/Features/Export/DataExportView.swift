import QuickLook
import SwiftUI

struct ReportView: View {
    @State private var controller: DataExportController
    @State private var pdfURL: URL?
    @State private var reportPreviewRequested = false
    @State private var reportPreviewRequestedAt: ContinuousClock.Instant?

    private let clock = ContinuousClock()

    init(dependencies: DataExportFeatureDependencies) {
        _controller = State(initialValue: dependencies.makeDataExportController())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.xxl) {
                VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                    Text("Für dein Arztgespräch")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(SymiColors.textPrimary.color)

                    Text("Alle wichtigen Einträge klar und verständlich zusammengefasst")
                        .font(.headline)
                        .foregroundStyle(SymiColors.textSecondary.color)

                    Text("Bereit für dein nächstes Arztgespräch")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SymiColors.textSecondary.color)
                }

                ReportCardView(
                    isLoading: controller.isLoadingSummary || controller.isPreparingPDF,
                    errorMessage: controller.exportErrorMessage,
                    action: openReport
                )
            }
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.vertical, SymiSpacing.xxxl)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
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
        .quickLookPreview($pdfURL)
    }

    private func openReport() {
        guard !controller.isLoadingSummary, !controller.isPreparingPDF else { return }
        reportPreviewRequested = true
        reportPreviewRequestedAt = clock.now
        controller.createPDF()
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

private struct ReportCardView: View {
    let isLoading: Bool
    let errorMessage: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xxl) {
            VStack(alignment: .leading, spacing: SymiSpacing.md) {
                Image(systemName: "doc.text")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(SymiColors.sage.color)
                    .frame(width: 44, height: 44)
                    .background(SymiColors.mist.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Bericht")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(SymiColors.textPrimary.color)

                Text("Alle wichtigen Einträge kompakt und verständlich aufbereitet")
                    .font(.subheadline)
                    .foregroundStyle(SymiColors.textSecondary.color)
            }

            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                Text("Letzter Monat")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(SymiColors.textPrimary.color)

                Text("Zeitraum deiner Auswertung")
                    .font(.subheadline)
                    .foregroundStyle(SymiColors.textSecondary.color)
            }

            Label {
                Text("Hilft dir, deine Symptome besser zu erklären")
            } icon: {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(SymiColors.sage.color)
            }
            .font(.footnote)
            .foregroundStyle(SymiColors.textSecondary.color)

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

            Text("Der Bericht wird beim Öffnen automatisch erstellt")
                .font(.footnote.weight(.regular))
                .foregroundStyle(SymiColors.textSecondary.color.opacity(0.72))

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.symiCoral)
            }
        }
        .padding(SymiSpacing.xxl)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: SymiColors.primaryPetrol.color.opacity(0.08), radius: 16, x: 0, y: 8)
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
            .shadow(color: SymiColors.primaryPetrol.color.opacity(configuration.isPressed ? 0.18 : 0.14), radius: configuration.isPressed ? 10 : 8, x: 0, y: configuration.isPressed ? 5 : 4)
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
