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

        VStack(alignment: .leading, spacing: SymiSpacing.xs) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.symiTextPrimary)
                        .frame(width: SymiSize.flowHeaderControlHeight, height: SymiSize.flowHeaderControlHeight)
                        .background(SymiColors.elevatedCard(for: colorScheme), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(SymiColors.subtleSeparator(for: colorScheme), lineWidth: SymiStroke.hairline)
                        }
                }
                .accessibilityLabel("Zurück")
                .accessibilityIdentifier("entry-flow-back")

                Spacer()

                Button("Abbrechen", action: onCancel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.symiPetrol)
                    .frame(minHeight: SymiSize.flowHeaderControlHeight)
                    .accessibilityIdentifier("entry-flow-cancel")
            }

            VStack(alignment: .leading, spacing: SymiSpacing.flowHeaderTitleSpacing) {
                InputFlowProgressBar(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                    theme: metadata.theme
                )

                Text(metadata.title)
                    .font(SymiTypography.flowTitle)
                    .foregroundStyle(metadata.theme.accent(for: colorScheme))
                    .padding(.top, SymiSpacing.md)
                    .fixedSize(horizontal: false, vertical: true)

                Text(metadata.subtitle)
                    .font(SymiTypography.flowSubtitle)
                    .foregroundStyle(AppTheme.symiTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, SymiSpacing.flowHorizontalPadding)
        .padding(.top, SymiSpacing.flowHeaderTopPadding)
        .padding(.bottom, SymiSpacing.zero)
        .frame(maxWidth: SymiSpacing.flowMaxContentWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}
