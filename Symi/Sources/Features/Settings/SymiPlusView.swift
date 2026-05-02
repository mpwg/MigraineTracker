import SwiftUI

struct SymiPlusView: View {
    @State private var store: SymiPlusStore

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let privacyURL = URL(string: "https://symiapp.com/privacy")!
    private let termsURL = URL(string: "https://symiapp.com/terms")!

    init(store: SymiPlusStore = SymiPlusStore()) {
        _store = State(initialValue: store)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SymiSpacing.symiPlusContentSpacing) {
                SymiPlusHeroCard(entitlementState: store.entitlementState)

                featureList(footerText: store.footerText, statusMessage: store.statusMessage)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, SymiSpacing.symiPlusContentTopPadding)
            .padding(.bottom, SymiSpacing.symiPlusContentBottomPadding)
            .frame(maxWidth: SymiSize.symiPlusContentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            SymiPlusBottomCTAView(
                primaryButtonTitle: store.primaryButtonTitle,
                privacyURL: privacyURL,
                termsURL: termsURL,
                canStartPurchase: store.canStartPurchase,
                canRestorePurchases: store.canRestorePurchases,
                activate: {
                    Task {
                        await store.purchaseSelectedProduct()
                    }
                },
                restorePurchases: {
                    Task {
                        await store.restorePurchases()
                    }
                }
            )
        }
        .navigationTitle("Symi Plus")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .tint(AppTheme.petrol(for: colorScheme))
        .task {
            await store.loadProducts()
        }
    }

    private func featureList(footerText: String, statusMessage: String?) -> some View {
        VStack(spacing: SymiSpacing.symiPlusFeatureSpacing) {
            ForEach(Self.featureRows) { row in
                SymiPlusFeatureCard(row: row)
            }

            if let statusMessage {
                SymiPlusStatusView(message: statusMessage)
            }

            SymiPlusFooterInfoView(text: footerText)
        }
    }

    private var screenBackground: Color {
        colorScheme == .dark ? AppTheme.warmBackground(for: colorScheme) : SymiPlusPalette.screenBackground
    }

    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .compact ? SymiSpacing.symiPlusCompactHorizontalPadding : SymiSpacing.symiPlusRegularHorizontalPadding
    }

    private static let featureRows = [
        SymiPlusFeatureRow(
            systemImage: "doc.text",
            title: "PDF-Berichte für Arztgespräche",
            subtitle: "Bereite deine Daten übersichtlich und verständlich auf."
        ),
        SymiPlusFeatureRow(
            systemImage: "chart.line.uptrend.xyaxis",
            title: "Erweiterte Auswertungen",
            subtitle: "Erkenne langfristig Muster in Schmerz, Triggern und Verlauf."
        ),
        SymiPlusFeatureRow(
            systemImage: "square.and.arrow.down",
            title: "Mehr Export-Optionen",
            subtitle: "Bereit für spätere professionelle Berichte und Analysen."
        ),
        SymiPlusFeatureRow(
            systemImage: "heart",
            title: "Symi unterstützen",
            subtitle: "Hilf dabei, die App langfristig weiterzuentwickeln.",
            iconTint: AppTheme.symiCoral
        )
    ]
}

private struct SymiPlusHeroCard: View {
    let entitlementState: SymiPlusEntitlementState

    @Environment(\.colorScheme) private var colorScheme
    @State private var heroVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.symiPlusHeroSpacing) {
            Image("PayWallHero")
                .resizable()
                .scaledToFit()
                .frame(width: SymiSize.symiPlusHeroImage, height: SymiSize.symiPlusHeroImage)
                .frame(maxWidth: .infinity)
                .offset(y: SymiSpacing.symiPlusHeroImageOffsetY)
                .scaleEffect(heroVisible ? SymiPlusMotion.heroImageScale : SymiPlusMotion.heroInitialScale)
                .accessibilityHidden(true)

            Text("Symi Plus")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.petrol(for: colorScheme))
                .lineSpacing(SymiSpacing.micro)
                .lineLimit(1)
                .minimumScaleFactor(SymiTypography.symiPlusTitleScaleFactor)

            Text(badgeText)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.petrol(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(SymiTypography.symiPlusBadgeScaleFactor)
                .padding(.horizontal, SymiSpacing.symiPlusBadgeHorizontalPadding)
                .padding(.vertical, SymiSpacing.symiPlusBadgeVerticalPadding)
                .background(SymiColors.symiPlusBadgeFill.color, in: Capsule(style: .continuous))

            Text(descriptionText)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, SymiSpacing.xxs)

            Text("Symi bleibt aktuell vollständig nutzbar — ohne Druck und ohne versteckte Einschränkungen.")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.petrol(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, SymiSpacing.xxs)
        }
        .opacity(heroVisible ? SymiOpacity.opaque : SymiOpacity.symiPlusHeroInitialOpacity)
        .padding(SymiSpacing.symiPlusHeroPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    SymiColors.warmBackground.color,
                    AppTheme.symiSage.opacity(SymiOpacity.symiPlusHeroSage)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: SymiRadius.heroCard, style: .continuous)
        )
        .onAppear {
            withAnimation(.easeOut(duration: SymiAnimation.symiPlusHeroRevealDuration)) {
                heroVisible = true
            }
        }
    }

    private var badgeText: String {
        entitlementState == .active ? "✦ Aktiv" : "✦ Direkt über den App Store"
    }

    private var descriptionText: String {
        entitlementState == .active
            ? "Symi Plus ist für deinen Apple Account freigeschaltet."
            : "Aktiviere Symi Plus sicher über den App Store und unterstütze die Weiterentwicklung."
    }
}

private struct SymiPlusFeatureRow: Identifiable {
    let systemImage: String
    let title: String
    let subtitle: String
    var iconTint: Color = AppTheme.symiPetrol

    var id: String { title }
}

private struct SymiPlusFeatureCard: View {
    let row: SymiPlusFeatureRow
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: SymiSpacing.symiPlusFeatureRowSpacing) {
            Image(systemName: row.systemImage)
                .font(SymiTypography.symiPlusFeatureIcon)
                .foregroundStyle(row.iconTint)
                .frame(width: SymiSize.symiPlusFeatureIcon, height: SymiSize.symiPlusFeatureIcon)
                .background(SymiColors.symiPlusIconFill.color, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SymiSpacing.symiPlusFeatureTextSpacing) {
                Text(row.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.petrol(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text(row.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

        }
        .padding(SymiSpacing.symiPlusCardPadding)
        .frame(maxWidth: .infinity, minHeight: SymiSize.symiPlusFeatureMinHeight, alignment: .leading)
        .background(
            SymiPlusPalette.cardBackground(for: colorScheme),
            in: RoundedRectangle(cornerRadius: SymiRadius.card, style: .continuous)
        )
        .shadow(
            color: Color.primary.opacity(colorScheme == .dark ? SymiOpacity.symiPlusDarkShadow : SymiOpacity.symiPlusLightShadow),
            radius: SymiShadow.symiPlusCardRadius,
            x: SymiShadow.cardXOffset,
            y: SymiShadow.symiPlusCardYOffset
        )
        .accessibilityElement(children: .combine)
    }
}

private struct SymiPlusFooterInfoView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(SymiSpacing.symiPlusFooterLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: SymiSize.symiPlusFooterMaxWidth)
            .padding(.horizontal, SymiSpacing.symiPlusFooterHorizontalPadding)
    }
}

private struct SymiPlusStatusView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.symiPetrol)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: SymiSize.symiPlusFooterMaxWidth)
            .padding(.horizontal, SymiSpacing.symiPlusFooterHorizontalPadding)
    }
}

private struct SymiPlusBottomCTAView: View {
    let primaryButtonTitle: String
    let privacyURL: URL
    let termsURL: URL
    let canStartPurchase: Bool
    let canRestorePurchases: Bool
    let activate: () -> Void
    let restorePurchases: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: SymiSpacing.symiPlusBottomSpacing) {
            Button(action: activate) {
                Label {
                    Text(primaryButtonTitle)
                } icon: {
                    Image(systemName: "sparkles")
                        .font(SymiTypography.symiPlusButtonIcon)
                }
                .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: SymiSize.symiPlusButtonHeight)
            }
            .buttonStyle(SymiPlusPrimaryButtonStyle())
            .disabled(!canStartPurchase)

            Button(action: restorePurchases) {
                Text("Käufe wiederherstellen")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: SymiSize.symiPlusButtonHeight)
            }
            .buttonStyle(SymiPlusSecondaryButtonStyle())
            .disabled(!canRestorePurchases)

            HStack(spacing: SymiSpacing.symiPlusFooterLinkSpacing) {
                Link(destination: privacyURL) {
                    Label("Datenschutz", systemImage: "shield")
                }

                Circle()
                    .fill(Color.secondary.opacity(SymiOpacity.symiPlusFooterDot))
                    .frame(width: SymiSize.symiPlusSeparatorDot, height: SymiSize.symiPlusSeparatorDot)
                    .accessibilityHidden(true)

                Link(destination: termsURL) {
                    Label("Nutzungsbedingungen", systemImage: "doc.text")
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.petrol(for: colorScheme))
            .lineLimit(1)
            .minimumScaleFactor(SymiTypography.symiPlusFooterScaleFactor)
            .padding(.top, SymiSpacing.symiPlusFooterTopPadding)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, SymiSpacing.symiPlusBottomSpacing)
        .padding(.bottom, SymiSpacing.symiPlusBottomPadding)
        .frame(minHeight: SymiSize.symiPlusCTAMinHeight)
        .background(AppTheme.warmBackground(for: colorScheme).opacity(SymiOpacity.symiPlusCTABackground))
        .background(alignment: .top) {
            LinearGradient(
                colors: [
                    Color.clear,
                    AppTheme.warmBackground(for: colorScheme).opacity(SymiOpacity.symiPlusCTAFadeMiddle),
                    AppTheme.warmBackground(for: colorScheme).opacity(SymiOpacity.symiPlusCTAFadeEnd)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: SymiSize.symiPlusCTAFadeHeight)
            .offset(y: -SymiSize.symiPlusCTAFadeHeight)
        }
        .opacity(SymiOpacity.symiPlusCTAPassive)
    }

    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .compact ? SymiSpacing.symiPlusCompactHorizontalPadding : SymiSpacing.symiPlusRegularHorizontalPadding
    }
}

private enum SymiPlusMotion {
    static let heroImageScale: CGFloat = 1.1
    static let heroInitialScale: CGFloat = 1
}

private struct SymiPlusPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.symiOnAccent)
            .background(
                LinearGradient(
                    colors: [
                        AppTheme.symiPetrol.opacity(configuration.isPressed ? SymiOpacity.symiPlusPrimaryPressed : SymiOpacity.opaque),
                        SymiColors.symiPlusPrimaryGradientEnd.color.opacity(configuration.isPressed ? SymiOpacity.symiPlusPrimaryPressed : SymiOpacity.opaque)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule(style: .continuous)
            )
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? SymiOpacity.faintSurface : SymiOpacity.symiPlusPrimaryShadow),
                radius: SymiShadow.symiPlusPrimaryButtonRadius,
                x: SymiShadow.buttonXOffset,
                y: SymiShadow.symiPlusPrimaryButtonYOffset
            )
    }
}

private struct SymiPlusSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.symiPetrol)
            .background(
                Capsule(style: .continuous)
                    .stroke(
                        AppTheme.symiPetrol.opacity(
                            configuration.isPressed ? SymiOpacity.symiPlusSecondaryPressedStroke : SymiOpacity.symiPlusSecondaryStroke
                        ),
                        lineWidth: SymiStroke.symiPlusOutline
                    )
            )
    }
}

private enum SymiPlusPalette {
    static let screenBackground = SymiColors.warmBackground.color

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? AppTheme.cardBackground(for: colorScheme) : SymiColors.onAccent.color
    }
}

#Preview {
    NavigationStack {
        SymiPlusView()
    }
}
