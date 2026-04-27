import SwiftUI

struct InputFlowHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    let step: InputFlowStepID
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onCancel: () -> Void

    init(
        step: InputFlowStepID,
        currentStep: Int,
        totalSteps: Int = InputFlowStepCatalog.steps.count,
        onBack: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.step = step
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onCancel = onCancel
    }

    var body: some View {
        let metadata = InputFlowStepCatalog.metadata(for: step)

        VStack(alignment: .leading, spacing: SymiSpacing.flowHeaderControlSpacing) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        }
                }
                .accessibilityLabel("Zurück")
                .accessibilityIdentifier("entry-flow-back")

                Spacer()

                Button("Abbrechen", action: onCancel)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(AppTheme.symiPetrol)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("entry-flow-cancel")
            }

            VStack(alignment: .leading, spacing: SymiSpacing.flowHeaderTitleSpacing) {
                InputFlowProgressView(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                    theme: metadata.theme
                )

                Text(metadata.title)
                    .font(SymiTypography.flowTitle)
                    .foregroundStyle(metadata.theme.accent(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text(metadata.subtitle)
                    .font(SymiTypography.flowSubtitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, SymiSpacing.flowHorizontalPadding)
        .padding(.top, SymiSpacing.flowHeaderTopPadding)
        .padding(.bottom, 8)
        .frame(maxWidth: SymiSpacing.flowMaxContentWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}
