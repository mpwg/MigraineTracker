import SwiftUI

typealias InputFlowProgressView = InputFlowProgressBar

struct InputFlowProgressBar: View {
    @Environment(\.colorScheme) private var colorScheme

    let currentStep: Int
    let totalSteps: Int
    let theme: InputFlowStepTheme

    init(currentStep: Int, totalSteps: Int = InputFlowStepCatalog.steps.count, theme: InputFlowStepTheme) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.theme = theme
    }

    var body: some View {
        HStack(alignment: .center, spacing: SymiSpacing.md) {
            GeometryReader { proxy in
                let indicatorSize = SymiSize.progressIndicator
                let trackHeight = SymiSize.progressTrackHeight
                let trackWidth = max(proxy.size.width - indicatorSize, 1)
                let xOffset = progressPosition(in: trackWidth)
                let activeWidth = min(xOffset + indicatorSize / 2, proxy.size.width)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(SymiColors.subtleSeparator(for: colorScheme))
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(theme.accent(for: colorScheme))
                        .frame(width: activeWidth, height: trackHeight)

                    Text("\(clampedCurrentStep)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.symiOnAccent)
                        .frame(width: indicatorSize, height: indicatorSize)
                        .background(theme.accent(for: colorScheme), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(
                                    AppTheme.symiOnAccent.opacity(
                                        colorScheme == .dark
                                            ? SymiOpacity.progressIndicatorStrokeDark
                                            : SymiOpacity.progressIndicatorStrokeLight
                                    ),
                                    lineWidth: SymiStroke.hairline
                                )
                        }
                        .offset(x: xOffset)
                        .offset(y: SymiStroke.hairline)
                        .accessibilityHidden(true)
                }
                .frame(height: indicatorSize, alignment: .center)
            }
            .frame(height: SymiSize.progressIndicator)

            Text("von \(safeTotalSteps)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.symiPetrol.opacity(SymiOpacity.strongText))
                .lineLimit(1)
                .minimumScaleFactor(SymiTypography.compactScaleFactor)
                .frame(width: SymiSize.progressTotalWidth, height: SymiSize.progressIndicator, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Schritt \(clampedCurrentStep) von \(safeTotalSteps)")
    }

    private var safeTotalSteps: Int {
        max(totalSteps, 1)
    }

    private var clampedCurrentStep: Int {
        min(max(currentStep, 1), safeTotalSteps)
    }

    private func progressPosition(in trackWidth: CGFloat) -> CGFloat {
        guard safeTotalSteps > 1 else {
            return trackWidth
        }

        return CGFloat(clampedCurrentStep - 1) / CGFloat(safeTotalSteps - 1) * trackWidth
    }
}
