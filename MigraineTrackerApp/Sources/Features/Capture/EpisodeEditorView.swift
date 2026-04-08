import SwiftData
import SwiftUI

struct EpisodeEditorView: View {
    private enum EditorMode {
        case create
        case edit
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let mode: EditorMode
    private let episode: Episode?
    private let onSaved: (() -> Void)?

    @State private var type: EpisodeType
    @State private var intensity: Double
    @State private var startedAt: Date
    @State private var endedAtEnabled: Bool
    @State private var endedAt: Date
    @State private var painLocation: String
    @State private var painCharacter: String
    @State private var notes: String
    @State private var functionalImpact: String
    @State private var menstruationStatus: MenstruationStatus
    @State private var selectedSymptoms: Set<String>
    @State private var selectedTriggers: Set<String>
    @State private var medications: [MedicationDraft]
    @State private var saveMessageVisible = false
    @State private var validationMessage: String?

    private let symptomOptions = ["Übelkeit", "Lichtempfindlichkeit", "Geräuschempfindlichkeit", "Aura"]
    private let triggerOptions = ["Stress", "Schlafmangel", "Alkohol", "Menstruation", "Bildschirmzeit"]

    init(episode: Episode? = nil, onSaved: (() -> Void)? = nil) {
        self.episode = episode
        self.onSaved = onSaved
        self.mode = episode == nil ? .create : .edit

        _type = State(initialValue: episode?.type ?? .unclear)
        _intensity = State(initialValue: Double(episode?.intensity ?? 5))
        _startedAt = State(initialValue: episode?.startedAt ?? .now)
        _endedAtEnabled = State(initialValue: episode?.endedAt != nil)
        _endedAt = State(initialValue: episode?.endedAt ?? .now)
        _painLocation = State(initialValue: episode?.painLocation ?? "")
        _painCharacter = State(initialValue: episode?.painCharacter ?? "")
        _notes = State(initialValue: episode?.notes ?? "")
        _functionalImpact = State(initialValue: episode?.functionalImpact ?? "")
        _menstruationStatus = State(initialValue: episode?.menstruationStatus ?? .unknown)
        _selectedSymptoms = State(initialValue: Set(episode?.symptoms ?? []))
        _selectedTriggers = State(initialValue: Set(episode?.triggers ?? []))
        _medications = State(initialValue: episode?.medications.map(MedicationDraft.init) ?? [])
    }

    var body: some View {
        Form {
            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Picker("Typ", selection: $type) {
                    ForEach(EpisodeType.allCases) { episodeType in
                        Text(episodeType.rawValue).tag(episodeType)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Intensität")
                        Spacer()
                        Text("\(Int(intensity))/10")
                            .font(.headline)
                            .monospacedDigit()
                    }

                    IntensityPicker(value: $intensity)
                }

                DatePicker("Beginn", selection: $startedAt, displayedComponents: [.date, .hourAndMinute])
            } header: {
                Text("Schneller Eintrag")
            } footer: {
                Text("Nur Typ, Intensität und Zeitpunkt sind direkt sichtbar. Alles Weitere ist optional.")
            }

            tagSection(title: "Symptome", options: symptomOptions, selection: $selectedSymptoms)
            tagSection(title: "Trigger", options: triggerOptions, selection: $selectedTriggers)

            Section("Notiz") {
                TextField("Kurz notieren, was auffällt", text: $notes, axis: .vertical)
                    .lineLimit(2 ... 5)
            }

            Section("Optionale Details") {
                DisclosureGroup("Weitere Angaben") {
                    TextField("Schmerzlokalisation", text: $painLocation)
                    TextField("Schmerzcharakter", text: $painCharacter)
                    TextField("Funktionelle Einschränkung", text: $functionalImpact)

                    Picker("Menstruationsstatus", selection: $menstruationStatus) {
                        ForEach(MenstruationStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }

                    Toggle("Ende angeben", isOn: $endedAtEnabled.animation())
                    if endedAtEnabled {
                        DatePicker("Ende", selection: $endedAt, in: startedAt..., displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }

            Section("Medikamente") {
                if medications.isEmpty {
                    Text("Nur ergänzen, wenn du heute etwas genommen hast.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($medications) { $medication in
                        MedicationDraftForm(draft: $medication)
                    }
                    .onDelete { offsets in
                        medications.remove(atOffsets: offsets)
                    }
                }

                Button {
                    medications.append(MedicationDraft())
                } label: {
                    Label("Medikament hinzufügen", systemImage: "plus.circle")
                }
            }

            Section {
                Button(mode == .create ? "Episode speichern" : "Änderungen speichern") {
                    saveEpisode()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(mode == .create ? "Erfassen" : "Episode bearbeiten")
        .scrollDismissesKeyboard(.interactively)
        .alert("Episode gespeichert", isPresented: $saveMessageVisible) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Die Episode wurde lokal in SwiftData gespeichert.")
        }
    }

    @ViewBuilder
    private func tagSection(title: String, options: [String], selection: Binding<Set<String>>) -> some View {
        Section(title) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.wrappedValue.contains(option)

                    Button {
                        if isSelected {
                            selection.wrappedValue.remove(option)
                        } else {
                            selection.wrappedValue.insert(option)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .imageScale(.medium)
                            Text(option)
                                .font(.subheadline.weight(.medium))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(isSelected ? Color.accentColor.opacity(0.16) : Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func saveEpisode() {
        validationMessage = nil

        if endedAtEnabled, endedAt < startedAt {
            validationMessage = "Das Ende darf nicht vor dem Beginn liegen."
            return
        }

        let validDrafts: [MedicationDraft]

        do {
            validDrafts = try validatedMedicationDrafts()
        } catch {
            validationMessage = error.localizedDescription
            return
        }

        let target = episode ?? Episode(startedAt: startedAt, intensity: Int(intensity))

        target.type = type
        target.startedAt = startedAt
        target.endedAt = endedAtEnabled ? endedAt : nil
        target.intensity = Int(intensity)
        target.painLocation = painLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        target.painCharacter = painCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.functionalImpact = functionalImpact.trimmingCharacters(in: .whitespacesAndNewlines)
        target.menstruationStatus = menstruationStatus
        target.symptoms = Array(selectedSymptoms).sorted()
        target.triggers = Array(selectedTriggers).sorted()

        let existingMedications = target.medications
        for medication in existingMedications {
            modelContext.delete(medication)
        }

        if episode == nil {
            modelContext.insert(target)
        }

        for draft in validDrafts {
            let entry = MedicationEntry(
                name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                category: draft.category,
                dosage: draft.dosage.trimmingCharacters(in: .whitespacesAndNewlines),
                takenAt: draft.takenAt,
                effectiveness: draft.effectiveness,
                reliefStartedAt: draft.reliefStartedAtEnabled ? draft.reliefStartedAt : nil,
                isRepeatDose: draft.isRepeatDose,
                episode: target
            )
            target.medications.append(entry)
        }

        do {
            try modelContext.save()
            validationMessage = nil

            if mode == .create {
                resetForm()
                saveMessageVisible = true
            } else {
                onSaved?()
                dismiss()
            }
        } catch {
            validationMessage = "Speichern fehlgeschlagen. Bitte versuche es erneut."
        }
    }

    private func resetForm() {
        type = .unclear
        intensity = 5
        startedAt = .now
        endedAtEnabled = false
        endedAt = .now
        painLocation = ""
        painCharacter = ""
        notes = ""
        functionalImpact = ""
        menstruationStatus = .unknown
        selectedSymptoms = []
        selectedTriggers = []
        medications = []
        validationMessage = nil
    }

    private func validatedMedicationDrafts() throws -> [MedicationDraft] {
        try medications.compactMap { draft in
            let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDosage = draft.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasAnyInput = !trimmedName.isEmpty
                || !trimmedDosage.isEmpty
                || draft.category != .other
                || draft.effectiveness != .partial
                || draft.isRepeatDose
                || draft.reliefStartedAtEnabled

            guard hasAnyInput else {
                return nil
            }

            guard !trimmedName.isEmpty else {
                throw EpisodeValidationError.medicationNameMissing
            }

            return draft
        }
    }
}

private enum EpisodeValidationError: LocalizedError {
    case medicationNameMissing

    var errorDescription: String? {
        switch self {
        case .medicationNameMissing:
            "Bitte gib für jedes Medikament zumindest einen Namen an."
        }
    }
}

private struct IntensityPicker: View {
    @Binding var value: Double

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1 ... 10, id: \.self) { level in
                let isSelected = Int(value) == level

                Button {
                    value = Double(level)
                } label: {
                    Text("\(level)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Intensität \(level)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

private struct MedicationDraftForm: View {
    @Binding var draft: MedicationDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: $draft.name)
            Picker("Kategorie", selection: $draft.category) {
                ForEach(MedicationCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }

            TextField("Dosis", text: $draft.dosage)
            DatePicker("Einnahme", selection: $draft.takenAt)

            Picker("Wirkung", selection: $draft.effectiveness) {
                ForEach(MedicationEffectiveness.allCases) { effectiveness in
                    Text(effectiveness.rawValue).tag(effectiveness)
                }
            }

            Toggle("Wiederholungseinnahme", isOn: $draft.isRepeatDose)
            Toggle("Wirkungseintritt angeben", isOn: $draft.reliefStartedAtEnabled.animation())
            if draft.reliefStartedAtEnabled {
                DatePicker("Wirkungseintritt", selection: $draft.reliefStartedAt)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MedicationDraft: Identifiable {
    let id: UUID
    var name: String
    var category: MedicationCategory
    var dosage: String
    var takenAt: Date
    var effectiveness: MedicationEffectiveness
    var reliefStartedAtEnabled: Bool
    var reliefStartedAt: Date
    var isRepeatDose: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        category: MedicationCategory = .other,
        dosage: String = "",
        takenAt: Date = .now,
        effectiveness: MedicationEffectiveness = .partial,
        reliefStartedAtEnabled: Bool = false,
        reliefStartedAt: Date = .now,
        isRepeatDose: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.dosage = dosage
        self.takenAt = takenAt
        self.effectiveness = effectiveness
        self.reliefStartedAtEnabled = reliefStartedAtEnabled
        self.reliefStartedAt = reliefStartedAt
        self.isRepeatDose = isRepeatDose
    }

    init(entry: MedicationEntry) {
        self.id = entry.id
        self.name = entry.name
        self.category = entry.category
        self.dosage = entry.dosage
        self.takenAt = entry.takenAt
        self.effectiveness = entry.effectiveness
        self.reliefStartedAtEnabled = entry.reliefStartedAt != nil
        self.reliefStartedAt = entry.reliefStartedAt ?? entry.takenAt
        self.isRepeatDose = entry.isRepeatDose
    }
}

#Preview {
    NavigationStack {
        EpisodeEditorView()
    }
}
