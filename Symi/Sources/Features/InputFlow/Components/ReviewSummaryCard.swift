import SwiftUI

struct InputFlowStepIcon: View {
    @Environment(\.colorScheme) private var colorScheme

    let metadata: InputFlowStepMetadata

    init(_ metadata: InputFlowStepMetadata) {
        self.metadata = metadata
    }

    var body: some View {
        Image(systemName: metadata.symbolName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(metadata.theme.accent(for: colorScheme))
            .frame(width: 44, height: 44)
            .background(metadata.theme.iconBackground(for: colorScheme), in: Circle())
            .accessibilityHidden(true)
    }
}

struct ReviewSummaryCard: View {
    let metadata: InputFlowStepMetadata
    let lines: [String]
    let details: String?
    let accessibilityIdentifier: String
    let onEdit: (() -> Void)?

    init(
        metadata: InputFlowStepMetadata,
        lines: [String],
        details: String? = nil,
        accessibilityIdentifier: String,
        onEdit: (() -> Void)? = nil
    ) {
        self.metadata = metadata
        self.lines = lines
        self.details = details
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onEdit = onEdit
    }

    var body: some View {
        Group {
            if let onEdit {
                Button(action: onEdit) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(onEdit == nil ? "" : "Tippe doppelt, um diesen Schritt zu bearbeiten.")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var content: some View {
        InputFlowCard {
            HStack(alignment: .top, spacing: 12) {
                InputFlowStepIcon(metadata)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 7) {
                    Text(metadata.title)
                        .font(SymiTypography.flowSummaryTitle)

                    ForEach(lines, id: \.self) { line in
                        Text(line)
                            .font(SymiTypography.flowSummaryLine)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let details, !details.isEmpty {
                        Text(details)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                if onEdit != nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 3)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}
