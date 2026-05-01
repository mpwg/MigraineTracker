import SwiftUI

struct SymiPlusView: View {
    var primaryButtonTitle = "Kostenlos aktivieren"
    var activate: () -> Void = {}
    var restorePurchases: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let privacyURL = URL(string: "https://symiapp.com/privacy")!
    private let termsURL = URL(string: "https://symiapp.com/terms")!

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard

                VStack(spacing: 12) {
                    ForEach(featureRows) { row in
                        SymiPlusFeatureCard(row: row)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 190)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .navigationTitle("Symi Plus")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(AppTheme.petrol(for: colorScheme))
    }

    private var heroCard: some View {
        HStack(alignment: .center, spacing: heroSpacing) {
            Image("PayWallHero")
                .resizable()
                .scaledToFit()
                .frame(width: heroImageSize, height: heroImageSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 13) {
                Text("Symi Plus")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.petrol(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("✧ Für kurze Zeit kostenlos")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.petrol(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SymiPlusPalette.badgeFill)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(AppTheme.symiSage.opacity(0.55), lineWidth: 1)
                            )
                    )

                Text("Aktiviere Symi Plus jetzt kostenlos und sichere dir den Einführungsvorteil.")
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Symi bleibt aktuell vollständig nutzbar — ohne Druck und ohne versteckte Einschränkungen.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.petrol(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
        }
        .padding(heroPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    SymiPlusPalette.heroStart,
                    SymiPlusPalette.heroEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(alignment: .trailing) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 96, weight: .light))
                .foregroundStyle(AppTheme.symiSage.opacity(0.12))
                .rotationEffect(.degrees(18))
                .offset(x: -20, y: -6)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Button(action: activate) {
                Label(primaryButtonTitle, systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(SymiPlusPrimaryButtonStyle())

            Button(action: restorePurchases) {
                Text("Käufe wiederherstellen")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(SymiPlusSecondaryButtonStyle())

            Text("Der aktuelle Preis wird direkt aus dem App Store geladen.\nDu kannst Käufe jederzeit wiederherstellen.")
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Divider()
                .padding(.top, 8)

            HStack(spacing: 18) {
                Link(destination: privacyURL) {
                    Label("Datenschutz", systemImage: "shield")
                }

                Circle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 5, height: 5)
                    .accessibilityHidden(true)

                Link(destination: termsURL) {
                    Label("Nutzungsbedingungen", systemImage: "doc.text")
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.petrol(for: colorScheme))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(screenBackground)
    }

    private var featureRows: [SymiPlusFeatureRow] {
        [
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

    private var screenBackground: Color {
        colorScheme == .dark ? AppTheme.warmBackground(for: colorScheme) : SymiPlusPalette.screenBackground
    }

    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .compact ? 16 : 24
    }

    private var heroPadding: CGFloat {
        horizontalSizeClass == .compact ? 20 : 24
    }

    private var heroSpacing: CGFloat {
        horizontalSizeClass == .compact ? 14 : 18
    }

    private var heroImageSize: CGFloat {
        horizontalSizeClass == .compact ? 128 : 160
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
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: row.systemImage)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(row.iconTint)
                .frame(width: 48, height: 48)
                .background(SymiPlusPalette.iconFill, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
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

            Image(systemName: "chevron.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.secondary.opacity(0.55))
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            SymiPlusPalette.cardBackground(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.05), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }
}

private struct SymiPlusPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        AppTheme.symiPetrol.opacity(configuration.isPressed ? 0.88 : 1),
                        Color(red: 0.02, green: 0.34, blue: 0.35).opacity(configuration.isPressed ? 0.88 : 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule(style: .continuous)
            )
            .shadow(color: AppTheme.symiPetrol.opacity(configuration.isPressed ? 0.12 : 0.22), radius: 10, x: 0, y: 5)
    }
}

private struct SymiPlusSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.symiPetrol)
            .background(Color.clear, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(AppTheme.symiPetrol.opacity(configuration.isPressed ? 0.5 : 0.3), lineWidth: 1.2)
            }
    }
}

private enum SymiPlusPalette {
    static let screenBackground = Color(red: 0.972, green: 0.957, blue: 0.925)
    static let heroStart = Color(red: 0.91, green: 0.953, blue: 0.937)
    static let heroEnd = Color(red: 0.965, green: 0.957, blue: 0.937)
    static let badgeFill = Color(red: 0.878, green: 0.941, blue: 0.918)
    static let iconFill = Color(red: 0.91, green: 0.953, blue: 0.937)

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? AppTheme.cardBackground(for: colorScheme) : .white
    }
}

#Preview {
    NavigationStack {
        SymiPlusView()
    }
}
