import SwiftUI

enum InputFlowStepID: String, CaseIterable, Identifiable, Sendable {
    case headache
    case medication
    case triggers
    case note
    case review

    var id: String { rawValue }
}

enum InputFlowStepStatus: String, Sendable {
    case open
    case active
    case complete
}

struct InputFlowStepMetadata: Identifiable, Sendable {
    let id: InputFlowStepID
    let title: String
    let subtitle: String
    let symbolName: String
    let theme: InputFlowStepTheme
    let status: InputFlowStepStatus?

    var subline: String { subtitle }
    var colorToken: InputFlowStepColorToken { theme.colorToken }
}

enum InputFlowStepCatalog {
    static let steps: [InputFlowStepMetadata] = [
        InputFlowStepMetadata(
            id: .headache,
            title: EntryFlowLocalized.text(de: "Kopfschmerz", en: "Headache"),
            subtitle: EntryFlowLocalized.text(de: "Wie stark ist es gerade?", en: "How strong is it right now?"),
            symbolName: "waveform.path.ecg",
            theme: .pain,
            status: nil
        ),
        InputFlowStepMetadata(
            id: .medication,
            title: EntryFlowLocalized.text(de: "Medikation", en: "Medication"),
            subtitle: EntryFlowLocalized.text(de: "Hast du etwas genommen?", en: "Did you take anything?"),
            symbolName: "pills.fill",
            theme: .medication,
            status: nil
        ),
        InputFlowStepMetadata(
            id: .triggers,
            title: EntryFlowLocalized.text(de: "Auslöser", en: "Triggers"),
            subtitle: EntryFlowLocalized.text(de: "Was könnte eine Rolle gespielt haben?", en: "What might have played a role?"),
            symbolName: "brain.head.profile",
            theme: .trigger,
            status: nil
        ),
        InputFlowStepMetadata(
            id: .note,
            title: EntryFlowLocalized.text(de: "Notiz", en: "Note"),
            subtitle: EntryFlowLocalized.text(de: "Was möchtest du festhalten?", en: "What do you want to note?"),
            symbolName: "note.text",
            theme: .note,
            status: nil
        ),
        InputFlowStepMetadata(
            id: .review,
            title: EntryFlowLocalized.text(de: "Eintrag prüfen", en: "Review entry"),
            subtitle: EntryFlowLocalized.text(de: "Alles bereit zum Speichern.", en: "Everything is ready to save."),
            symbolName: "checkmark.seal.fill",
            theme: .review,
            status: nil
        )
    ]

    static func metadata(for id: InputFlowStepID) -> InputFlowStepMetadata {
        guard let metadata = steps.first(where: { $0.id == id }) else {
            preconditionFailure("Fehlende Step-Metadaten für \(id.rawValue).")
        }

        return metadata
    }
}

struct InputFlowStepTheme: Equatable, Sendable {
    let colorToken: InputFlowStepColorToken

    static let pain = InputFlowStepTheme(colorToken: .coral)
    static let medication = InputFlowStepTheme(colorToken: .sageTeal)
    static let trigger = InputFlowStepTheme(colorToken: .blue)
    static let note = InputFlowStepTheme(colorToken: .warmAmber)
    static let review = InputFlowStepTheme(colorToken: .purple)

    var accent: Color {
        colorToken.color
    }

    var accentSoft: Color {
        colorToken.softFill(for: .light)
    }

    var progress: Color {
        colorToken.color
    }

    var iconBackground: Color {
        colorToken.softFill(for: .light)
    }

    func accent(for colorScheme: ColorScheme) -> Color {
        colorToken.color(for: colorScheme)
    }

    func accentSoft(for colorScheme: ColorScheme) -> Color {
        colorToken.softFill(for: colorScheme)
    }

    func selectedFill(for colorScheme: ColorScheme) -> Color {
        colorToken.selectedFill(for: colorScheme)
    }

    func border(for colorScheme: ColorScheme) -> Color {
        colorToken.border(for: colorScheme)
    }

    func iconBackground(for colorScheme: ColorScheme) -> Color {
        colorToken.softFill(for: colorScheme)
    }
}

enum InputFlowStepColorToken: String, CaseIterable, Sendable {
    case coral
    case sageTeal
    case blue
    case warmAmber
    case purple

    var color: Color {
        color(for: .light)
    }

    var lightColorValue: SymiColorValue {
        switch self {
        case .coral:
            SymiColors.coral
        case .sageTeal:
            SymiColors.sage
        case .blue:
            SymiColors.triggerBlue
        case .warmAmber:
            SymiColors.noteAmber
        case .purple:
            SymiColors.reviewPurple
        }
    }

    func color(for colorScheme: ColorScheme) -> Color {
        let value = colorScheme == .dark ? darkColorValue : lightColorValue
        return value.color
    }

    func softFill(for colorScheme: ColorScheme) -> Color {
        color(for: colorScheme).opacity(colorScheme == .dark ? SymiOpacity.progressTrackDark : SymiOpacity.softFill)
    }

    func selectedFill(for colorScheme: ColorScheme) -> Color {
        color(for: colorScheme).opacity(colorScheme == .dark ? SymiOpacity.stepSelectedFillDark : SymiOpacity.selectedStroke)
    }

    func border(for colorScheme: ColorScheme) -> Color {
        color(for: colorScheme).opacity(colorScheme == .dark ? SymiOpacity.stepBorderDark : SymiOpacity.stepBorderLight)
    }

    private var darkColorValue: SymiColorValue {
        switch self {
        case .coral:
            SymiColors.coralDark
        case .sageTeal:
            SymiColors.sageDark
        case .blue:
            SymiColors.triggerBlueDark
        case .warmAmber:
            SymiColors.noteAmberDark
        case .purple:
            SymiColors.reviewPurpleDark
        }
    }
}

extension EntryFlowStep {
    var inputFlowStepID: InputFlowStepID {
        switch self {
        case .headache:
            .headache
        case .medication:
            .medication
        case .triggers:
            .triggers
        case .note:
            .note
        case .review:
            .review
        }
    }
}
