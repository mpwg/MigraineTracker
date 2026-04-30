import SwiftUI

struct SettingsSectionCard<Content: View>: View {
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

            VStack(spacing: SymiSpacing.zero) {
                content
            }
            .padding(.vertical, SymiSpacing.xs)
            .brandCard()
        }
    }
}

struct SettingsStatusHeader: View {
    let systemImage: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: SymiSpacing.md) {
            IconContainerView(icon: Image(systemName: systemImage), color: tint)

            VStack(alignment: .leading, spacing: SymiSpacing.compact) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.symiTextPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.symiTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: SymiSpacing.sm)
        }
        .padding(.horizontal, SymiSpacing.lg)
        .padding(.vertical, SymiSpacing.lg)
        .background(tint.opacity(SymiOpacity.clearAccent), in: RoundedRectangle(cornerRadius: SymiRadius.flowBanner, style: .continuous))
        .padding(.horizontal, SymiSpacing.xs)
        .padding(.top, SymiSpacing.xs)
        .padding(.bottom, SymiSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }
}

enum SettingsIconPalette {
    static let dataSecurity = SymiColors.triggerBlue.color
}

struct IconContainerView: View {
    let icon: Image
    let color: Color
    var backgroundOpacity = SymiOpacity.faintSurface
    var preservesOriginalRendering = false

    var body: some View {
        icon
            .resizable()
            .renderingMode(preservesOriginalRendering ? .original : .template)
            .scaledToFit()
            .foregroundStyle(color)
            .padding(SymiSpacing.compact)
            .frame(width: SymiSize.settingsIconContainer, height: SymiSize.settingsIconContainer)
            .background(
                color.opacity(backgroundOpacity),
                in: RoundedRectangle(cornerRadius: SymiRadius.settingsIconContainer, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

enum SettingsRowStyle {
    case primaryAction
    case navigation
    case standard
    case destructive
}

struct AppleHealthCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let statusTitle: String
    let isConnected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: SymiSpacing.md) {
            Image(systemName: "heart.fill")
                .foregroundStyle(AppTheme.symiCoral)
                .font(.headline)

            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                Text("Apple Health")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.symiTextPrimary)
                    .fixedSize(horizontal: true, vertical: false)

            }
            .layoutPriority(1)

            Spacer(minLength: SymiSpacing.md)

            HStack(spacing: SymiSpacing.xs) {
                Text(statusTitle)
                    .font(.subheadline)
                    .foregroundStyle(isConnected ? AppTheme.symiPetrol : AppTheme.symiTextSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, SymiSpacing.lg)
        .padding(.vertical, SymiSpacing.lg)
        .frame(minHeight: SymiSize.settingsAppleHealthCardMinHeight)
        .background(
            appleHealthBackground,
            in: RoundedRectangle(cornerRadius: SymiRadius.flowBanner, style: .continuous)
        )
        .padding(.horizontal, SymiSpacing.xs)
        .padding(.top, SymiSpacing.xs)
        .padding(.bottom, SymiSpacing.sm)
        .contentShape(RoundedRectangle(cornerRadius: SymiRadius.flowBanner, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Health. Lese- und Schreibzugriff. \(statusTitle)")
    }

    private var appleHealthBackground: Color {
        if colorScheme == .dark {
            return Color.white.opacity(SymiOpacity.clearAccent)
        }

        return Color(.systemGray6)
    }
}

struct SettingsRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var assetImageName: String?
    var rightValue: String?
    var tint: Color = AppTheme.symiPetrol
    var rowStyle: SettingsRowStyle = .standard
    var subtitleLineLimit: Int?
    var showsChevron = false
    var isDestructive = false
    var isEnabled = true

    var body: some View {
        HStack(alignment: .center, spacing: SymiSpacing.md) {
            iconView

            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.symiTextSecondary)
                        .lineLimit(subtitleLineLimit)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: SymiSpacing.sm)

            if let rightValue {
                Text(rightValue)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.symiTextSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, SymiSpacing.lg)
        .padding(.vertical, SymiSpacing.md)
        .frame(minHeight: SymiSize.minInteractiveHeight)
        .contentShape(Rectangle())
        .opacity(isEnabled ? SymiOpacity.opaque : SymiOpacity.disabledRow)
        .accessibilityElement(children: .combine)
    }

    private var titleFont: Font {
        switch rowStyle {
        case .primaryAction:
            .body.weight(.semibold)
        case .destructive:
            .body.weight(.medium)
        case .navigation, .standard:
            .body
        }
    }

    private var titleColor: Color {
        switch rowStyle {
        case .primaryAction:
            AppTheme.symiPetrol
        case .destructive:
            AppTheme.symiCoral
        case .navigation, .standard:
            isDestructive ? AppTheme.symiCoral : AppTheme.symiTextPrimary
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let assetImageName {
            IconContainerView(
                icon: Image(assetImageName),
                color: AppTheme.symiCoral,
                preservesOriginalRendering: true
            )
        } else if let systemImage {
            IconContainerView(icon: Image(systemName: systemImage), color: iconColor)
        }
    }

    private var iconColor: Color {
        switch rowStyle {
        case .primaryAction:
            AppTheme.symiPetrol
        case .destructive:
            AppTheme.symiCoral
        case .navigation, .standard:
            isDestructive ? AppTheme.symiCoral : tint
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var tint: Color = AppTheme.symiPetrol
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .center, spacing: SymiSpacing.md) {
                if let systemImage {
                    IconContainerView(icon: Image(systemName: systemImage), color: tint)
                }

                VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(AppTheme.symiTextPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.symiTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)
            }
        }
        .tint(AppTheme.symiPetrol)
        .padding(.horizontal, SymiSpacing.lg)
        .padding(.vertical, SymiSpacing.md)
        .frame(minHeight: SymiSize.minInteractiveHeight)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Aktiviert" : "Deaktiviert")
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, SymiSpacing.settingsDividerLeadingPadding)
    }
}
