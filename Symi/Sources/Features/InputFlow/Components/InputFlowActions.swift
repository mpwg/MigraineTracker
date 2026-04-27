import SwiftUI

struct InputFlowPrimaryButton: View {
    let title: String
    let systemImage: String
    let isLoading: Bool
    let isDisabled: Bool
    let accessibilityIdentifier: String?
    let action: () -> Void

    init(
        title: String,
        systemImage: String = "arrow.right",
        isLoading: Bool = false,
        isDisabled: Bool = false,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(SymiTypography.flowPrimaryButton)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack {
                        Spacer(minLength: 0)
                        Image(systemName: systemImage)
                            .font(.headline.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .padding(.trailing, 18)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(buttonFill, in: Capsule())
            .shadow(color: isDisabled ? .clear : SymiShadow.buttonColor, radius: SymiShadow.buttonRadius, x: 0, y: SymiShadow.buttonYOffset)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityIdentifier(accessibilityIdentifier ?? "input-flow-primary")
    }

    private var buttonFill: Color {
        (isDisabled || isLoading) ? AppTheme.symiPetrol.opacity(0.55) : AppTheme.symiPetrol
    }
}

struct InputFlowSecondaryAction: View {
    let title: String
    let isDisabled: Bool
    let accessibilityIdentifier: String?
    let action: () -> Void

    init(
        title: String,
        isDisabled: Bool = false,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isDisabled = isDisabled
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .font(SymiTypography.flowSecondaryAction)
            .foregroundStyle(AppTheme.symiPetrol)
            .frame(minHeight: 44)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.55 : 1)
            .accessibilityIdentifier(accessibilityIdentifier ?? "input-flow-secondary")
    }
}
