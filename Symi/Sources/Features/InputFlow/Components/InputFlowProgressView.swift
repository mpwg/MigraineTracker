import SwiftUI

struct InputFlowProgressView: View {
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
        HStack(spacing: 18) {
            GeometryReader { proxy in
                let indicatorSize: CGFloat = 24
                let trackWidth = max(proxy.size.width - indicatorSize, 1)
                let xOffset = progressPosition(in: trackWidth)
                let activeWidth = min(xOffset + indicatorSize / 2, proxy.size.width)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.12))
                        .frame(height: 4)
                        .offset(y: indicatorSize / 2 - 2)

                    Capsule()
                        .fill(theme.accent(for: colorScheme))
                        .frame(width: activeWidth, height: 4)
                        .offset(y: indicatorSize / 2 - 2)

                    Text("\(clampedCurrentStep)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: indicatorSize, height: indicatorSize)
                        .background(theme.accent(for: colorScheme), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(colorScheme == .dark ? 0.18 : 0.92), lineWidth: 1)
                        }
                        .offset(x: xOffset)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 24)

            Text("von \(safeTotalSteps)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
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
