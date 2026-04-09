import SwiftData
import SwiftUI

struct EpisodeEditorView: View {
    private enum EditorMode {
        case create
        case edit
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\MedicationEntry.takenAt, order: .reverse)]) private var previousMedicationEntries: [MedicationEntry]

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
    @State private var weatherEnabled: Bool
    @State private var weatherCondition: String
    @State private var weatherTemperature: String
    @State private var weatherHumidity: String
    @State private var weatherPressure: String
    @State private var weatherSource: String
    @State private var saveMessageVisible = false
    @State private var validationMessage: String?

    private let symptomOptions = ["Übelkeit", "Lichtempfindlichkeit", "Geräuschempfindlichkeit", "Aura"]
    private let triggerOptions = ["Stress", "Schlafmangel", "Alkohol", "Menstruation", "Bildschirmzeit"]
    private let maxRecentMedications = 6

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
        _weatherEnabled = State(initialValue: episode?.weatherSnapshot != nil)
        _weatherCondition = State(initialValue: episode?.weatherSnapshot?.condition ?? "")
        _weatherTemperature = State(initialValue: EpisodeEditorView.stringValue(for: episode?.weatherSnapshot?.temperature, fractionDigits: 1))
        _weatherHumidity = State(initialValue: EpisodeEditorView.stringValue(for: episode?.weatherSnapshot?.humidity, fractionDigits: 0))
        _weatherPressure = State(initialValue: EpisodeEditorView.stringValue(for: episode?.weatherSnapshot?.pressure, fractionDigits: 0))
        _weatherSource = State(initialValue: episode?.weatherSnapshot?.source ?? "")
    }

    var body: some View {
        Form {
            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Fehler: \(validationMessage)")
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

            Section {
                Toggle("Wetterdaten manuell ergänzen", isOn: $weatherEnabled.animation())

                if weatherEnabled {
                    TextField("Wetterlage, z. B. sonnig oder Regen", text: $weatherCondition)
                    TextField("Temperatur in °C", text: $weatherTemperature)
                        .keyboardType(.decimalPad)
                    TextField("Luftfeuchte in %", text: $weatherHumidity)
                        .keyboardType(.decimalPad)
                    TextField("Luftdruck in hPa", text: $weatherPressure)
                        .keyboardType(.decimalPad)
                    TextField("Quelle, z. B. manuell", text: $weatherSource)
                }
            } header: {
                Text("Wetter")
            } footer: {
                Text("Optional. Es wird keine Wetter-Schnittstelle verwendet, nur deine manuelle Eingabe lokal gespeichert.")
            }

            Section("Medikamente") {
                let recentMedications = recentMedicationTemplates

                if !recentMedications.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Zuletzt verwendet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(recentMedications) { template in
                            Button {
                                addMedication(from: template)
                            } label: {
                                MedicationTemplateRow(template: template)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

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
                    .accessibilityLabel("\(title): \(option)")
                    .accessibilityHint(isSelected ? "Entfernt die Auswahl." : "Wählt diese Option aus.")
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

        let parsedWeather: ParsedWeatherSnapshot?

        do {
            parsedWeather = try validatedWeatherSnapshot()
        } catch {
            validationMessage = error.localizedDescription
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

        if let existingWeatherSnapshot = target.weatherSnapshot {
            modelContext.delete(existingWeatherSnapshot)
            target.weatherSnapshot = nil
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

        if let parsedWeather {
            let snapshot = WeatherSnapshot(
                recordedAt: startedAt,
                temperature: parsedWeather.temperature,
                condition: parsedWeather.condition,
                humidity: parsedWeather.humidity,
                pressure: parsedWeather.pressure,
                source: parsedWeather.source,
                episode: target
            )
            target.weatherSnapshot = snapshot
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
        weatherEnabled = false
        weatherCondition = ""
        weatherTemperature = ""
        weatherHumidity = ""
        weatherPressure = ""
        weatherSource = ""
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

    private var recentMedicationTemplates: [MedicationTemplate] {
        var seenKeys = Set<String>()
        var templates: [MedicationTemplate] = []

        for entry in previousMedicationEntries {
            let template = MedicationTemplate(entry: entry)

            guard seenKeys.insert(template.deduplicationKey).inserted else {
                continue
            }

            templates.append(template)

            if templates.count == maxRecentMedications {
                break
            }
        }

        return templates
    }

    private func addMedication(from template: MedicationTemplate) {
        medications.append(
            MedicationDraft(
                name: template.name,
                category: template.category,
                dosage: template.dosage,
                takenAt: startedAt,
                effectiveness: template.effectiveness,
                reliefStartedAtEnabled: false,
                reliefStartedAt: startedAt,
                isRepeatDose: false
            )
        )
    }

    private func validatedWeatherSnapshot() throws -> ParsedWeatherSnapshot? {
        guard weatherEnabled else {
            return nil
        }

        let trimmedCondition = weatherCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = weatherSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemperature = weatherTemperature.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHumidity = weatherHumidity.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPressure = weatherPressure.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasAnyInput = !trimmedCondition.isEmpty
            || !trimmedSource.isEmpty
            || !trimmedTemperature.isEmpty
            || !trimmedHumidity.isEmpty
            || !trimmedPressure.isEmpty

        guard hasAnyInput else {
            return nil
        }

        let temperature = try parseOptionalNumber(from: trimmedTemperature, fieldName: "Temperatur")
        let humidity = try parseOptionalNumber(from: trimmedHumidity, fieldName: "Luftfeuchte")
        let pressure = try parseOptionalNumber(from: trimmedPressure, fieldName: "Luftdruck")

        if let temperature, !(-50 ... 60).contains(temperature) {
            throw EpisodeValidationError.weatherValueOutOfRange(
                fieldName: "Temperatur",
                expectedRange: "-50 bis 60 °C"
            )
        }

        if let humidity, !(0 ... 100).contains(humidity) {
            throw EpisodeValidationError.weatherValueOutOfRange(
                fieldName: "Luftfeuchte",
                expectedRange: "0 bis 100 %"
            )
        }

        if let pressure, !(870 ... 1085).contains(pressure) {
            throw EpisodeValidationError.weatherValueOutOfRange(
                fieldName: "Luftdruck",
                expectedRange: "870 bis 1085 hPa"
            )
        }

        return ParsedWeatherSnapshot(
            condition: trimmedCondition,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            source: trimmedSource.isEmpty ? "Manuell" : trimmedSource
        )
    }

    private func parseOptionalNumber(from text: String, fieldName: String) throws -> Double? {
        guard !text.isEmpty else {
            return nil
        }

        let normalized = text.replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalized) else {
            throw EpisodeValidationError.invalidWeatherValue(fieldName)
        }

        return value
    }

    private static func stringValue(for value: Double?, fractionDigits: Int) -> String {
        guard let value else {
            return ""
        }

        return value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }
}

private enum EpisodeValidationError: LocalizedError {
    case medicationNameMissing
    case invalidWeatherValue(String)
    case weatherValueOutOfRange(fieldName: String, expectedRange: String)

    var errorDescription: String? {
        switch self {
        case .medicationNameMissing:
            "Bitte gib für jedes Medikament zumindest einen Namen an."
        case let .invalidWeatherValue(fieldName):
            "\(fieldName) muss eine gültige Zahl sein."
        case let .weatherValueOutOfRange(fieldName, expectedRange):
            "\(fieldName) muss im Bereich \(expectedRange) liegen."
        }
    }
}

private struct ParsedWeatherSnapshot {
    let condition: String
    let temperature: Double?
    let humidity: Double?
    let pressure: Double?
    let source: String
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
                .accessibilityHint(isSelected ? "Aktuell ausgewählt." : "Setzt die Intensität auf \(level) von 10.")
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

private struct MedicationTemplate: Identifiable {
    let id: String
    let name: String
    let category: MedicationCategory
    let dosage: String
    let effectiveness: MedicationEffectiveness

    init(entry: MedicationEntry) {
        let trimmedName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = entry.dosage.trimmingCharacters(in: .whitespacesAndNewlines)

        self.name = trimmedName
        self.category = entry.category
        self.dosage = trimmedDosage
        self.effectiveness = entry.effectiveness
        self.id = [trimmedName.lowercased(), entry.category.rawValue, trimmedDosage.lowercased()].joined(separator: "|")
    }

    var deduplicationKey: String { id }

    var summary: String {
        if dosage.isEmpty {
            return "\(category.rawValue) · letzte Wirkung \(effectiveness.rawValue.lowercased())"
        }

        return "\(category.rawValue) · \(dosage) · letzte Wirkung \(effectiveness.rawValue.lowercased())"
    }
}

private struct MedicationTemplateRow: View {
    let template: MedicationTemplate

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(template.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .imageScale(.large)
                .foregroundStyle(Color.accentColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(template.name), \(template.summary)")
        .accessibilityHint("Übernimmt dieses Medikament in den aktuellen Eintrag.")
    }
}

#Preview {
    NavigationStack {
        EpisodeEditorView()
    }
}
