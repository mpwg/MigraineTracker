import SwiftUI
import UIKit

struct AppleHealthSettingsView: View {
    @Bindable var controller: SettingsController
    @State private var showsDisconnectConfirmation = false

    var body: some View {
        let status = controller.healthAuthorization

        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.xxl) {
                HealthHeaderView()

                if !isConnected(status) {
                    Button {
                        Task {
                            await controller.requestHealthAuthorization()
                        }
                    } label: {
                        Text("Apple Health aktivieren")
                    }
                    .buttonStyle(HealthPrimaryButtonStyle())
                    .disabled(!status.isAvailable)
                }

                if let message = status.lastErrorMessage {
                    HealthNoticeCard(message: message)
                } else if !status.isAvailable {
                    HealthNoticeCard(message: "Apple Health ist auf diesem Gerät nicht verfügbar.")
                }

                if isConnected(status) {
                    HealthStatusBlock(
                        text: statusText(for: status),
                        showsCompletion: isFullyConfigured(status)
                    )

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
                                Text("Deine Einträge können in Apple Health gespeichert werden - nur wenn du es erlaubst.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.symiTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

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
                }
            }
            .padding(.horizontal, AppTheme.groupedHorizontalInset)
            .padding(.top, SymiSpacing.xxl)
            .padding(.bottom, SymiSpacing.settingsContentBottomPadding)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.headline)

                    Text("Apple Health")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Apple Health")
            }
        }
        .brandScreen()
        .onAppear {
            controller.reloadHealthAuthorizationState()
        }
        .animation(.default, value: controller.healthSettingsRevision)
        .confirmationDialog(
            "Apple Health Integration beenden?",
            isPresented: $showsDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Integration beenden", role: .destructive) {
                controller.disconnectAppleHealthIntegration()
                openAppSettings()
            }

            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Symi trennt die lokale Verbindung. HealthKit-Berechtigungen werden von iOS verwaltet und können in den Einstellungen geprüft oder widerrufen werden.")
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

    private func statusText(for status: HealthAuthorizationSnapshot) -> String {
        shouldShowMissingPermissions(for: status) ? "Einige Daten sind aktiviert" : "Alle verfügbaren Daten sind aktiviert"
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
                HealthTrustItem(icon: "lock", title: "Verschlüsselt")
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

private struct HealthStatusBlock: View {
    let text: String
    let showsCompletion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xs) {
            HealthStatusText(text: text)

            if showsCompletion {
                HealthSetupCompleteText()
            }
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

private struct HealthSetupCompleteText: View {
    var body: some View {
        Label("Alles ist eingerichtet", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.symiPetrol)
            .accessibilityLabel("Alles ist eingerichtet")
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
        HStack(alignment: .top, spacing: SymiSpacing.md) {
            IconContainerView(icon: Image(systemName: icon), color: AppTheme.symiPetrol)

            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.symiTextPrimary)
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.symiTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: SymiSpacing.md)

            stateLabel
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
            Label("Freigegeben", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.green)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
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
                PrivacyLine(icon: "iphone", text: "Alle Daten bleiben auf deinem Gerät")
                PrivacyLine(icon: "person.crop.circle.badge.xmark", text: "Keine Weitergabe an Dritte")
                PrivacyLine(icon: "hand.raised", text: "Du kannst den Zugriff jederzeit widerrufen")
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

private struct HealthSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.symiPetrol)
            .padding(.vertical, SymiSpacing.md)
            .frame(maxWidth: .infinity)
            .background(AppTheme.symiSage.opacity(configuration.isPressed ? SymiOpacity.pressedFill : SymiOpacity.secondaryFill))
            .clipShape(RoundedRectangle(cornerRadius: SymiRadius.button, style: .continuous))
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
