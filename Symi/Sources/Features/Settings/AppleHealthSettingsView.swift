import SwiftUI
import UIKit

struct AppleHealthView: View {
    @State private var controller: SettingsController

    init(dependencies: SettingsFeatureDependencies) {
        _controller = State(initialValue: dependencies.makeSettingsController())
    }

    var body: some View {
        AppleHealthSettingsView(controller: controller)
    }
}

struct AppleHealthSettingsView: View {
    @Bindable var controller: SettingsController
    @State private var showsDisconnectConfirmation = false

    var body: some View {
        let status = controller.healthAuthorization

        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.xxl) {
                HealthHeaderView()

                if let statusText = statusText(for: status) {
                    HealthStatusText(text: statusText)
                }

                if shouldShowPrimaryCTA(for: status) {
                    Button {
                        handlePrimaryCTA(for: status)
                    } label: {
                        Text(primaryCTATitle(for: status))
                    }
                    .buttonStyle(HealthPrimaryButtonStyle())
                    .disabled(!status.isAvailable)
                }

                if status.isAvailable {
                    Button {
                        Task {
                            await controller.requestHealthAuthorization()
                        }
                    } label: {
                        Label("Berechtigungen erneut anfragen", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(HealthInlineSettingsButtonStyle())
                }

                if let message = status.lastErrorMessage {
                    HealthNoticeCard(message: message)
                } else if !status.isAvailable {
                    HealthNoticeCard(message: "Apple Health ist auf diesem Gerät nicht verfügbar.")
                }

                if isConnected(status) {
                    if !enabledReadDefinitions(for: status).isEmpty {
                        HealthSettingsSection(title: "Freigegebene Daten") {
                            VStack(spacing: SymiSpacing.md) {
                                ForEach(enabledReadDefinitions(for: status)) { definition in
                                    HealthCategoryRow(
                                        icon: iconName(for: definition.id),
                                        title: definition.displayName,
                                        explanation: explanation(for: definition),
                                        state: .granted
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                    }

                    if shouldShowMissingPermissions(for: status) {
                        MoreHealthDataCard {
                            openAppSettings()
                        }
                    }

                    if status.isWriteEnabled, !enabledWriteDefinitions(for: status).isEmpty {
                        HealthSettingsSection(title: "An Apple Health senden") {
                            VStack(alignment: .leading, spacing: SymiSpacing.lg) {
                                VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                                    Text("Du kannst Einträge zusätzlich in Apple Health speichern.")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.symiTextSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("Nur wenn aktiviert")
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.symiTextSecondary)
                                }

                                VStack(spacing: SymiSpacing.md) {
                                    ForEach(enabledWriteDefinitions(for: status)) { definition in
                                        HealthCategoryRow(
                                            icon: iconName(for: definition.id),
                                            title: definition.displayName,
                                            explanation: explanation(for: definition),
                                            state: .granted
                                        )
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                            }
                        }
                    }

                    HealthPrivacySection()

                    HealthDangerZone {
                        showsDisconnectConfirmation = true
                    }
                    .padding(.top, SymiSpacing.xxl)
                }
            }
            .padding(.horizontal, AppTheme.groupedHorizontalInset)
            .padding(.top, SymiSpacing.xxl)
            .padding(.bottom, SymiSpacing.settingsContentBottomPadding)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
        }
        .navigationTitle("Apple Health")
        .brandScreen()
        .onAppear {
            controller.reloadHealthAuthorizationState()
        }
        .animation(.default, value: controller.healthSettingsRevision)
        .confirmationDialog(
            "Integration beenden?",
            isPresented: $showsDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Integration beenden", role: .destructive) {
                controller.disconnectAppleHealthIntegration()
                openAppSettings()
            }

            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Du kannst den Zugriff jederzeit wieder aktivieren.")
        }
    }

    private func shouldShowPrimaryCTA(for status: HealthAuthorizationSnapshot) -> Bool {
        status.isAvailable && !isFullyConfigured(status)
    }

    private func primaryCTATitle(for status: HealthAuthorizationSnapshot) -> String {
        isConnected(status) ? "Weitere Daten aktivieren" : "Apple Health aktivieren"
    }

    private func handlePrimaryCTA(for status: HealthAuthorizationSnapshot) {
        if isConnected(status) {
            openAppSettings()
        } else {
            Task {
                await controller.requestHealthAuthorization()
            }
        }
    }

    private func shouldShowMissingPermissions(for status: HealthAuthorizationSnapshot) -> Bool {
        guard isConnected(status) else { return false }
        return !status.missingReadTypes.isEmpty || !status.missingWriteTypes.isEmpty
    }

    private func isFullyConfigured(_ status: HealthAuthorizationSnapshot) -> Bool {
        isConnected(status) && !shouldShowMissingPermissions(for: status)
    }

    private func openAppSettings() {
        UIApplication.shared.open(HealthSettingsURL.url)
    }

    private func isConnected(_ status: HealthAuthorizationSnapshot) -> Bool {
        status.isAvailable && (status.isReadEnabled || status.isWriteEnabled)
    }

    private func enabledReadDefinitions(for status: HealthAuthorizationSnapshot) -> [HealthDataTypeDefinition] {
        controller.healthReadDefinitions.filter { status.enabledReadTypes.contains($0.id) }
    }

    private func enabledWriteDefinitions(for status: HealthAuthorizationSnapshot) -> [HealthDataTypeDefinition] {
        controller.healthWriteDefinitions.filter { status.enabledWriteTypes.contains($0.id) }
    }

    private func statusText(for status: HealthAuthorizationSnapshot) -> String? {
        guard isConnected(status) else {
            return nil
        }

        return shouldShowMissingPermissions(for: status) ? "Einige Daten sind bereits aktiviert" : "Alle Daten sind eingerichtet"
    }

    private func explanation(for definition: HealthDataTypeDefinition) -> String {
        switch definition.id {
        case .sleep:
            "Schlaf hilft, Muster zwischen Erholung und Beschwerden zu erkennen."
        case .steps:
            "Aktivität zeigt, wie Bewegung und Ruhe rund um deine Einträge zusammenhängen können."
        case .heartRate:
            "Herzfrequenz kann körperliche Belastung im Umfeld eines Eintrags sichtbar machen."
        case .restingHeartRate:
            "Ruhepuls ergänzt deinen Tageskontext ohne Bewertung."
        case .heartRateVariability:
            "Herzfrequenzvariabilität kann Hinweise auf Stress und Erholung als Kontext geben."
        case .menstrualFlow:
            "Zyklusdaten können helfen, wiederkehrende Muster besser einzuordnen."
        case .headache:
            "Kopfschmerz-Einträge können zwischen Symi und Apple Health abgeglichen werden."
        case .nausea:
            "Übelkeit hilft, Begleitsymptome neben Kopfschmerzen besser zu verstehen."
        case .dizziness:
            "Schwindel ergänzt den Verlauf mit einem häufig relevanten Begleitsymptom."
        case .fatigue:
            "Müdigkeit kann zeigen, wie Erschöpfung und Beschwerden zusammenfallen."
        }
    }

    private func iconName(for type: HealthDataTypeID) -> String {
        switch type {
        case .sleep:
            "bed.double"
        case .steps:
            "figure.walk"
        case .heartRate, .restingHeartRate, .heartRateVariability:
            "heart"
        case .menstrualFlow:
            "calendar"
        case .headache:
            "brain.head.profile"
        case .nausea:
            "face.dashed"
        case .dizziness:
            "waveform.path.ecg"
        case .fatigue:
            "sparkles"
        }
    }
}

private struct HealthHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                Text("Deine Daten. Deine Kontrolle.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.symiTextPrimary)
                Text("Alle Daten bleiben auf deinem Gerät und werden niemals an Dritte gesendet.")
                    .font(.body)
                    .foregroundStyle(AppTheme.symiTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: SymiSpacing.sm) {
                HealthTrustItem(icon: "checkmark.shield", title: "Nur mit deiner Erlaubnis")
                HealthTrustItem(icon: "lock", title: "Durch Apple Health geschützt")
                HealthTrustItem(icon: "power", title: "Jederzeit deaktivierbar")
            }
        }
        .padding(SymiSpacing.xxl)
        .brandCard()
        .accessibilityElement(children: .combine)
    }
}

private struct HealthTrustItem: View {
    let icon: String
    let title: String

    var body: some View {
        Label {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.symiTextPrimary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.symiPetrol)
        }
    }
}

private struct HealthSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.symiTextPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: SymiSpacing.zero) {
                content
            }
            .padding(SymiSpacing.lg)
            .brandCard()
        }
    }
}

private struct HealthStatusText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(AppTheme.symiTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
    }
}

private enum HealthCategoryState {
    case granted
    case optional
}

private struct HealthCategoryRow: View {
    let icon: String
    let title: String
    let explanation: String
    let state: HealthCategoryState

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.sm) {
            HStack(alignment: .top, spacing: SymiSpacing.md) {
                IconContainerView(icon: Image(systemName: icon), color: AppTheme.symiPetrol)

                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.symiTextPrimary)

                Spacer(minLength: SymiSpacing.md)

                stateLabel
            }

            Text(explanation)
                .font(.subheadline)
                .foregroundStyle(AppTheme.symiTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(explanation)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch state {
        case .granted:
            HStack(spacing: SymiSpacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                Text("Freigegeben")
                    .foregroundStyle(AppTheme.symiTextSecondary)
            }
            .font(.subheadline)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(alignment: .trailing)
        case .optional:
            Text("Optional")
                .font(.subheadline)
                .foregroundStyle(AppTheme.symiTextSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .granted:
            "Freigegeben"
        case .optional:
            "Optional"
        }
    }
}

private struct MoreHealthDataCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            HStack(alignment: .top, spacing: SymiSpacing.md) {
                IconContainerView(icon: Image(systemName: "plus.circle"), color: AppTheme.symiPetrol)

                VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                    Text("Mehr Daten verfügbar")
                        .font(.headline)
                        .foregroundStyle(AppTheme.symiTextPrimary)
                    Text("Du kannst weitere Daten in der Health App aktivieren, um noch bessere Einblicke zu erhalten.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.symiTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: action) {
                Label("In Einstellungen öffnen", systemImage: "gearshape")
            }
            .buttonStyle(HealthInlineSettingsButtonStyle())

            Text("Tippe dort auf „Health“ → „Datenzugriff & Geräte“ → „Symi“")
                .font(.footnote)
                .foregroundStyle(AppTheme.symiTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SymiSpacing.lg)
        .brandCard()
    }
}

private struct HealthPrivacySection: View {
    var body: some View {
        HealthSettingsSection(title: "Datenschutz") {
            VStack(alignment: .leading, spacing: SymiSpacing.md) {
                PrivacyLine(icon: "iphone", text: "Daten bleiben auf deinem Gerät")
                PrivacyLine(icon: "person.crop.circle.badge.xmark", text: "Keine Weitergabe an Dritte")
                PrivacyLine(icon: "hand.raised", text: "Zugriff jederzeit widerrufbar")
            }
        }
    }
}

private struct PrivacyLine: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.symiTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.symiPetrol)
        }
    }
}

private struct HealthDangerZone: View {
    let action: () -> Void

    var body: some View {
        HealthSettingsSection(title: "Integration") {
            VStack(alignment: .leading, spacing: SymiSpacing.md) {
                Text("Alle Verbindungen werden getrennt")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.symiTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(role: .destructive, action: action) {
                    Label("Apple Health Integration beenden", systemImage: "xmark.circle")
                }
                .buttonStyle(HealthDestructiveButtonStyle())
            }
        }
    }
}

private struct HealthNoticeCard: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.symiTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(AppTheme.symiPetrol)
        }
        .padding(SymiSpacing.lg)
        .background(AppTheme.symiCard, in: RoundedRectangle(cornerRadius: SymiRadius.flowBanner, style: .continuous))
    }
}

private struct HealthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppTheme.symiOnAccent)
            .padding(.vertical, SymiSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(AppTheme.symiPetrol.opacity(configuration.isPressed ? SymiOpacity.pressedContent : SymiOpacity.opaque))
            .clipShape(RoundedRectangle(cornerRadius: SymiRadius.button, style: .continuous))
            .shadow(color: AppTheme.symiPetrol.opacity(SymiOpacity.shadow), radius: SymiShadow.buttonRadius, y: SymiShadow.buttonYOffset)
    }
}

private struct HealthInlineSettingsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.symiPetrol.opacity(configuration.isPressed ? SymiOpacity.pressedContent : SymiOpacity.opaque))
            .padding(.vertical, SymiSpacing.xs)
            .contentShape(Rectangle())
    }
}

private struct HealthDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.symiCoral)
            .padding(.vertical, SymiSpacing.md)
            .frame(maxWidth: .infinity)
            .background(AppTheme.symiCoral.opacity(configuration.isPressed ? SymiOpacity.softFill : SymiOpacity.clearAccent))
            .clipShape(RoundedRectangle(cornerRadius: SymiRadius.button, style: .continuous))
    }
}

private enum HealthSettingsURL {
    static let url = URL(string: UIApplication.openSettingsURLString)!
}
