import SwiftUI

struct EpisodeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let episode: Episode
    @State private var isEditing = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        List {
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
                    }
                }
            }

            if let weatherSnapshot = episode.weatherSnapshot {
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
                    if !weatherSnapshot.source.isEmpty {
                        detailRow("Quelle", weatherSnapshot.source)
                    }
                    detailRow("Erfasst", weatherSnapshot.recordedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            if !episode.notes.isEmpty {
                Section("Notiz") {
                    Text(episode.notes)
                }
            }
        }
        .navigationTitle("Episodendetail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten") {
                    isEditing = true
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Löschen", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                EpisodeEditorView(episode: episode)
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
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(value)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func medicationHeadline(for medication: MedicationEntry) -> String {
        if medication.dosage.isEmpty {
            return medication.category.rawValue
        }

        return "\(medication.category.rawValue) · \(medication.dosage)"
    }

    private func deleteEpisode() {
        episode.markDeleted()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Löschen fehlgeschlagen: \(error)")
        }
    }
}
