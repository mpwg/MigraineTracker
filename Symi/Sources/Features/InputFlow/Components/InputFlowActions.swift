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
                        .tint(AppTheme.symiOnAccent)
                } else {
                    Text(title)
                        .font(SymiTypography.flowPrimaryButton)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(SymiTypography.buttonScaleFactor)

                    HStack {
                        Spacer(minLength: 0)
                        Image(systemName: systemImage)
                            .font(.headline.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .padding(.trailing, SymiSpacing.buttonTrailingIconPadding)
                }
            }
            .foregroundStyle(AppTheme.symiOnAccent)
            .padding(.horizontal, SymiSpacing.xl)
            .frame(maxWidth: .infinity, minHeight: SymiSize.primaryButtonHeight)
            .background(buttonFill, in: Capsule())
            .shadow(
                color: isDisabled ? .clear : SymiShadow.buttonColor,
                radius: SymiShadow.buttonRadius,
                x: SymiShadow.buttonXOffset,
                y: SymiShadow.buttonYOffset
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityIdentifier(accessibilityIdentifier ?? "input-flow-primary")
    }

    private var buttonFill: Color {
        (isDisabled || isLoading) ? AppTheme.symiPetrol.opacity(SymiOpacity.disabledFill) : AppTheme.symiPetrol
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
            .foregroundStyle(AppTheme.symiPetrol.opacity(SymiOpacity.secondaryActionText))
            .frame(minHeight: SymiSize.minInteractiveHeight)
            .disabled(isDisabled)
            .opacity(isDisabled ? SymiOpacity.disabledContent : SymiOpacity.opaque)
            .accessibilityIdentifier(accessibilityIdentifier ?? "input-flow-secondary")
    }
}

typealias SecondaryAction = InputFlowSecondaryAction
