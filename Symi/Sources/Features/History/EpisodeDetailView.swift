import SwiftUI

struct EpisodeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let appContainer: AppContainer
    let episodeID: UUID

    @State private var episode: EpisodeRecord?
    @State private var isEditing = false
    @State private var isShowingDeleteConfirmation = false

    private let loadEpisodeDetailUseCase: LoadEpisodeDetailUseCase
    private let deleteEpisodeUseCase: DeleteEpisodeUseCase

    init(appContainer: AppContainer, episodeID: UUID) {
        self.appContainer = appContainer
        self.episodeID = episodeID
        self.loadEpisodeDetailUseCase = LoadEpisodeDetailUseCase(repository: appContainer.episodeRepository)
        self.deleteEpisodeUseCase = DeleteEpisodeUseCase(repository: appContainer.episodeRepository)
        _episode = State(initialValue: nil)
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                detailList
            } else {
                regularDetail
            }
        }
        .navigationTitle("Episodendetail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten") {
                    isEditing = true
                }
                .disabled(episode == nil)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Löschen", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
                .disabled(episode == nil)
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                EpisodeEditorView(
                    appContainer: appContainer,
                    episodeID: episodeID,
                    onSaved: { Task { await reload() } }
                )
            }
        }
        .confirmationDialog(
            "Episode löschen?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                deleteEpisode()
            }

            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Episode wird in den Papierkorb verschoben.")
        }
        .task {
            await reload()
        }
    }

    private var detailList: some View {
        List {
            if let episode {
                Section("Episode") {
                    detailRow("Typ", episode.type.rawValue)
                    detailRow("Intensität", "\(episode.intensity) / 10")
                    detailRow("Beginn", episode.startedAt.formatted(date: .abbreviated, time: .shortened))
                    if let endedAt = episode.endedAt {
                        detailRow("Ende", endedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    if !episode.painLocation.isEmpty {
                        detailRow("Lokalisation", episode.painLocation)
                    }
                    if !episode.painCharacter.isEmpty {
                        detailRow("Charakter", episode.painCharacter)
                    }
                    if !episode.functionalImpact.isEmpty {
                        detailRow("Einschränkung", episode.functionalImpact)
                    }
                    if episode.menstruationStatus != .unknown {
                        detailRow("Menstruationsstatus", episode.menstruationStatus.rawValue)
                    }
                }

                if !episode.symptoms.isEmpty {
                    Section("Symptome") {
                        ForEach(episode.symptoms, id: \.self) { symptom in
                            Text(symptom)
                        }
                    }
                }

                if !episode.triggers.isEmpty {
                    Section("Trigger") {
                        ForEach(episode.triggers, id: \.self) { trigger in
                            Text(trigger)
                        }
                    }
                }

                if !episode.medications.isEmpty {
                    Section("Medikamente") {
                        ForEach(episode.medications.sorted(by: { $0.takenAt < $1.takenAt })) { medication in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(medication.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(medication.takenAt.formatted(date: .omitted, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Text(medicationHeadline(for: medication))
                                    .foregroundStyle(.secondary)

                                if medication.quantity > 1 {
                                    Text("Anzahl: \(medication.quantity)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if medication.effectiveness != .partial {
                                    Text("Wirkung: \(medication.effectiveness.rawValue)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if medication.isRepeatDose {
                                    Text("Als Wiederholungseinnahme dokumentiert")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if let reliefStartedAt = medication.reliefStartedAt {
                                    Text("Wirkungseintritt: \(reliefStartedAt.formatted(date: .omitted, time: .shortened))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                            .brandGroupedRow()
                        }
                    }
                }

                if let weatherSnapshot = episode.weather {
                    Section("Wetter") {
                        if !weatherSnapshot.condition.isEmpty {
                            detailRow("Bedingung", weatherSnapshot.condition)
                        }
                        if let temperature = weatherSnapshot.temperature {
                            detailRow("Temperatur", temperature.formatted(.number.precision(.fractionLength(1))) + " °C")
                        }
                        if let humidity = weatherSnapshot.humidity {
                            detailRow("Luftfeuchte", humidity.formatted(.number.precision(.fractionLength(0))) + " %")
                        }
                        if let pressure = weatherSnapshot.pressure {
                            detailRow("Luftdruck", pressure.formatted(.number.precision(.fractionLength(0))) + " hPa")
                        }
                        if let precipitation = weatherSnapshot.precipitation {
                            detailRow("Niederschlag", precipitation.formatted(.number.precision(.fractionLength(1))) + " mm")
                        }
                        if let weatherCode = weatherSnapshot.weatherCode {
                            detailRow("Wettercode", String(weatherCode))
                        }
                        if !weatherSnapshot.source.isEmpty {
                            detailRow("Quelle", weatherSnapshot.source)
                        }
                        if let contextRange = weatherContextRangeText(for: weatherSnapshot) {
                            detailRow("Kontextzeitraum", contextRange)
                        }
                        if !weatherSnapshot.contextPoints.isEmpty {
                            detailRow("Kontextwerte", "\(weatherSnapshot.contextPoints.count) stündliche Werte")
                        }
                        detailRow("Erfasst", weatherSnapshot.recordedAt.formatted(date: .abbreviated, time: .shortened))
                        WeatherAttributionView()
                            .padding(.vertical, 4)
                    }
                }

                if let healthContext = episode.healthContext {
                    Section("Apple Health") {
                        healthRows(for: healthContext)
                    }
                }

                if !episode.notes.isEmpty {
                    Section("Notiz") {
                        Text(episode.notes)
                    }
                }
            } else {
                ContentUnavailableView("Episode nicht gefunden", systemImage: "exclamationmark.triangle")
            }
        }
        .brandGroupedScreen()
    }

    private var regularDetail: some View {
        ScrollView {
            if let episode {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320), spacing: AppTheme.dashboardSpacing, alignment: .top)],
                    alignment: .leading,
                    spacing: AppTheme.dashboardSpacing
                ) {
                    AdaptiveDashboardCard(title: "Episode") {
                        detailValue("Typ", episode.type.rawValue)
                        detailValue("Intensität", "\(episode.intensity) / 10")
                        detailValue("Beginn", episode.startedAt.formatted(date: .abbreviated, time: .shortened))
                        if let endedAt = episode.endedAt {
                            detailValue("Ende", endedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        if !episode.painLocation.isEmpty {
                            detailValue("Lokalisation", episode.painLocation)
                        }
                        if !episode.painCharacter.isEmpty {
                            detailValue("Charakter", episode.painCharacter)
                        }
                        if !episode.functionalImpact.isEmpty {
                            detailValue("Einschränkung", episode.functionalImpact)
                        }
                        if episode.menstruationStatus != .unknown {
                            detailValue("Menstruationsstatus", episode.menstruationStatus.rawValue)
                        }
                    }

                    if !episode.symptoms.isEmpty {
                        AdaptiveDashboardCard(title: "Symptome") {
                            tagFlow(episode.symptoms)
                        }
                    }

                    if !episode.triggers.isEmpty {
                        AdaptiveDashboardCard(title: "Trigger") {
                            tagFlow(episode.triggers)
                        }
                    }

                    if !episode.medications.isEmpty {
                        AdaptiveDashboardCard(title: "Medikamente") {
                            ForEach(episode.medications.sorted(by: { $0.takenAt < $1.takenAt })) { medication in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(medication.name)
                                            .font(.headline)
                                        Spacer()
                                        Text(medication.takenAt.formatted(date: .omitted, time: .shortened))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(medicationHeadline(for: medication))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(AppTheme.secondaryFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }

                    if let weatherSnapshot = episode.weather {
                        AdaptiveDashboardCard(title: "Wetter") {
                            if !weatherSnapshot.condition.isEmpty {
                                detailValue("Bedingung", weatherSnapshot.condition)
                            }
                            if let temperature = weatherSnapshot.temperature {
                                detailValue("Temperatur", temperature.formatted(.number.precision(.fractionLength(1))) + " °C")
                            }
                            if let humidity = weatherSnapshot.humidity {
                                detailValue("Luftfeuchte", humidity.formatted(.number.precision(.fractionLength(0))) + " %")
                            }
                            if let pressure = weatherSnapshot.pressure {
                                detailValue("Luftdruck", pressure.formatted(.number.precision(.fractionLength(0))) + " hPa")
                            }
                            if let precipitation = weatherSnapshot.precipitation {
                                detailValue("Niederschlag", precipitation.formatted(.number.precision(.fractionLength(1))) + " mm")
                            }
                            if let contextRange = weatherContextRangeText(for: weatherSnapshot) {
                                detailValue("Kontextzeitraum", contextRange)
                            }
                            if !weatherSnapshot.contextPoints.isEmpty {
                                detailValue("Kontextwerte", "\(weatherSnapshot.contextPoints.count) stündliche Werte")
                            }
                            detailValue("Erfasst", weatherSnapshot.recordedAt.formatted(date: .abbreviated, time: .shortened))
                            WeatherAttributionView()
                        }
                    }

                    if let healthContext = episode.healthContext {
                        AdaptiveDashboardCard(title: "Apple Health") {
                            healthValues(for: healthContext)
                        }
                    }

                    if !episode.notes.isEmpty {
                        AdaptiveDashboardCard(title: "Notiz") {
                            Text(episode.notes)
                        }
                    }
                }
                .padding(24)
                .wideContent()
            } else {
                ContentUnavailableView("Episode nicht gefunden", systemImage: "exclamationmark.triangle")
                    .frame(maxWidth: .infinity, minHeight: 360)
            }
        }
        .brandScreen()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(value)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .brandGroupedRow()
        .accessibilityElement(children: .combine)
    }

    private func detailValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func tagFlow(_ values: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(values, id: \.self) { value in
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.secondaryFill, in: Capsule())
            }
        }
    }

    @ViewBuilder
    private func healthRows(for context: HealthContextRecord) -> some View {
        ForEach(healthDetailLines(for: context), id: \.title) { line in
            detailRow(line.title, line.value)
        }
    }

    @ViewBuilder
    private func healthValues(for context: HealthContextRecord) -> some View {
        ForEach(healthDetailLines(for: context), id: \.title) { line in
            detailValue(line.title, line.value)
        }
    }

    private func healthDetailLines(for context: HealthContextRecord) -> [(title: String, value: String)] {
        var lines: [(String, String)] = []

        if let sleepMinutes = context.sleepMinutes {
            lines.append(("Schlaf", "\(Int(sleepMinutes.rounded())) min"))
        }
        if let stepCount = context.stepCount {
            lines.append(("Schritte", stepCount.formatted()))
        }
        if let averageHeartRate = context.averageHeartRate {
            lines.append(("Herzfrequenz", averageHeartRate.formatted(.number.precision(.fractionLength(0))) + " bpm"))
        }
        if let restingHeartRate = context.restingHeartRate {
            lines.append(("Ruhepuls", restingHeartRate.formatted(.number.precision(.fractionLength(0))) + " bpm"))
        }
        if let heartRateVariability = context.heartRateVariability {
            lines.append(("HRV", heartRateVariability.formatted(.number.precision(.fractionLength(0))) + " ms"))
        }
        if let menstrualFlow = context.menstrualFlow {
            lines.append(("Menstruation", menstrualFlow))
        }
        if !context.symptoms.isEmpty {
            let symptoms = context.symptoms
                .map { "\($0.type.displayName): \($0.severity)" }
                .joined(separator: ", ")
            lines.append(("Symptome", symptoms))
        }

        lines.append(("Quelle", context.source))
        lines.append(("Gelesen", context.recordedAt.formatted(date: .abbreviated, time: .shortened)))
        return lines
    }

    private func medicationHeadline(for medication: MedicationRecord) -> String {
        if medication.dosage.isEmpty {
            return medication.category.rawValue
        }

        return "\(medication.category.rawValue) · \(medication.dosage)"
    }

    private func weatherContextRangeText(for weather: WeatherRecord) -> String? {
        guard let start = weather.contextRangeStart, let end = weather.contextRangeEnd else {
            return nil
        }

        return "\(start.formatted(date: .abbreviated, time: .shortened)) bis \(end.formatted(date: .abbreviated, time: .shortened))"
    }

    private func deleteEpisode() {
        Task {
            do {
                try await deleteEpisodeUseCase.execute(id: episodeID)
                dismiss()
            } catch {
                assertionFailure("Löschen fehlgeschlagen: \(error)")
            }
        }
    }

    private func reload() async {
        episode = try? await loadEpisodeDetailUseCase.execute(id: episodeID)
    }
}
