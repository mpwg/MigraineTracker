import SwiftUI

struct DataSharingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var onAccept: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.xxxl) {
                header

                VStack(alignment: .leading, spacing: SymiSpacing.xxxl) {
                    InfoSection(
                        icon: "checkmark.circle.fill",
                        title: "Was wird geteilt",
                        items: [
                            "App-Nutzung",
                            "Abstürze & Performance"
                        ],
                        tint: AppTheme.sage(for: colorScheme)
                    )

                    Divider()
                        .opacity(SymiOpacity.pressedFill)

                    InfoSection(
                        icon: "lock.shield.fill",
                        title: "Was wird NICHT geteilt",
                        items: [
                            "Deine Einträge",
                            "Gesundheitsdaten",
                            "Persönliche Informationen"
                        ],
                        tint: AppTheme.coral(for: colorScheme)
                    )
                    .padding(.top, SymiSpacing.xs)
                }

                footer
            }
            .padding(.horizontal, SymiSpacing.xxxl)
            .padding(.top, SymiSpacing.xxxl)
            .padding(.bottom, SymiSpacing.dataSharingContentBottomPadding)
        }
        .background(AppTheme.warmBackground(for: colorScheme))
        .safeAreaInset(edge: .bottom) {
            actions
                .padding(.horizontal, SymiSpacing.xxxl)
                .padding(.top, SymiSpacing.md)
                .padding(.bottom, SymiSpacing.lg)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xs) {
            Text("Nutzungsdaten anonym teilen?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("Hilf uns, Symi besser zu machen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: SymiSpacing.xs) {
            Image(systemName: "gearshape.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Du kannst das jederzeit in den Einstellungen ändern.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        VStack(spacing: SymiSpacing.md) {
            Button {
                onAccept()
                dismiss()
            } label: {
                Text("Anonym teilen")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: SymiSize.dataSharingPrimaryButtonHeight)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.symiOnAccent)
            .background(AppTheme.petrol(for: colorScheme), in: RoundedRectangle(cornerRadius: SymiRadius.flowBanner, style: .continuous))

            Button {
                dismiss()
            } label: {
                Text("Jetzt nicht")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SymiSpacing.xs)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.petrol(for: colorScheme))
        }
    }
}

private struct InfoSection: View {
    let icon: String
    let title: String
    let items: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: SymiSpacing.sm) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.symiTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                ForEach(items, id: \.self) { item in
                    DataSharingBulletRow(text: item, tint: tint)
                }
            }
            .padding(.leading, SymiSpacing.dataSharingBulletIndent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DataSharingBulletRow: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: SymiSpacing.xs) {
            Circle()
                .fill(tint)
                .frame(width: SymiSize.dataSharingBulletSize, height: SymiSize.dataSharingBulletSize)
                .padding(.top, SymiSpacing.compact)

            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.symiTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    DataSharingSheet {}
}
