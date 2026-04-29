import SwiftUI

struct DataSharingSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onAccept: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 24) {
                    InfoSection(
                        icon: "checkmark.circle.fill",
                        title: "Was wird geteilt",
                        items: [
                            "App-Nutzung",
                            "Abstürze & Performance"
                        ],
                        tint: SymiSheetColors.sage
                    )

                    Divider()
                        .opacity(0.2)

                    InfoSection(
                        icon: "lock.shield.fill",
                        title: "Was wird NICHT geteilt",
                        items: [
                            "Deine Einträge",
                            "Gesundheitsdaten",
                            "Persönliche Informationen"
                        ],
                        tint: SymiSheetColors.coral
                    )
                    .padding(.top, 8)
                }

                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 132)
        }
        .background(SymiSheetColors.background)
        .safeAreaInset(edge: .bottom) {
            actions
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nutzungsdaten anonym teilen?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(SymiSheetColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Hilf uns, Symi besser zu machen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
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
        VStack(spacing: 12) {
            Button {
                onAccept()
                dismiss()
            } label: {
                Text("Anonym teilen")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(SymiSheetColors.petrol, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                dismiss()
            } label: {
                Text("Jetzt nicht")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SymiSheetColors.petrol)
        }
    }
}

private struct InfoSection: View {
    let icon: String
    let title: String
    let items: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(SymiSheetColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    DataSharingBulletRow(text: item, tint: tint)
                }
            }
            .padding(.leading, 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DataSharingBulletRow: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(.body)
                .foregroundStyle(SymiSheetColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum SymiSheetColors {
    static let petrol = Color(red: 15 / 255, green: 61 / 255, blue: 62 / 255)
    static let sage = Color(red: 142 / 255, green: 205 / 255, blue: 184 / 255)
    static let coral = Color(red: 255 / 255, green: 138 / 255, blue: 122 / 255)
    static let background = Color(red: 246 / 255, green: 244 / 255, blue: 239 / 255)
    static let primaryText = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
}

#Preview {
    DataSharingSheet {}
}
