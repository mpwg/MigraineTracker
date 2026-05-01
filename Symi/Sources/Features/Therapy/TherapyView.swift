import SwiftUI

struct TherapyView: View {
    @State private var viewModel: TherapyViewModel

    init(dependencies: TherapyFeatureDependencies) {
        _viewModel = State(initialValue: dependencies.makeTherapyViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.dashboardSpacing) {
                TherapyHeader()

                TherapyOverviewCard()

                TherapyTodaySection(medications: viewModel.todayMedications)

                TherapyNavigationSection(viewModel: viewModel)

                if let message = viewModel.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.symiCoral)
                        .padding(.horizontal, SymiSpacing.xxl)
                }
            }
            .padding(.horizontal, SymiSpacing.groupedHorizontalInset)
            .padding(.top, SymiSpacing.screenTopInset)
            .padding(.bottom, SymiSpacing.reportBottomPadding)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
        }
        .navigationTitle("Therapie")
        .brandScreen()
        .task {
            viewModel.load()
        }
        .refreshable {
            viewModel.load()
        }
    }
}

private struct TherapyHeader: View {
    var body: some View {
        Text("Therapie")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(AppTheme.symiPetrol)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct TherapyOverviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.sm) {
            Label("Übersicht", systemImage: "pills.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.symiPetrol)

            Text("Deine regelmäßige Medikation im Blick behalten")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .therapyCard()
    }
}

private struct TherapyTodaySection: View {
    let medications: [TherapyMedicationItem]

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.md) {
            Text("Heute")
                .font(.headline)
                .foregroundStyle(AppTheme.symiPetrol)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: SymiSpacing.xs) {
                if medications.isEmpty {
                    Text("Keine regelmäßige Medikation für heute.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(medications) { medication in
                        TherapyMedicationRow(medication: medication)

                        if medication.id != medications.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .therapyCard()
        }
    }
}

private struct TherapyMedicationRow: View {
    let medication: TherapyMedicationItem

    var body: some View {
        HStack(alignment: .top, spacing: SymiSpacing.md) {
            Image(systemName: "pills")
                .font(.headline)
                .foregroundStyle(AppTheme.symiPetrol)
                .frame(width: SymiSize.entryDetailContextIcon, height: SymiSize.entryDetailContextIcon)
                .background(AppTheme.symiSage.opacity(SymiOpacity.secondaryFill), in: Circle())

            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                Text(medication.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(medication.dosage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: SymiSpacing.md)

            Text(medication.timeText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.symiPetrol)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, SymiSpacing.xs)
    }
}

private struct TherapyNavigationSection: View {
    @Bindable var viewModel: TherapyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.md) {
            Text("Navigation")
                .font(.headline)
                .foregroundStyle(AppTheme.symiPetrol)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: SymiSpacing.zero) {
                NavigationLink {
                    TherapyPlanView(viewModel: viewModel)
                } label: {
                    TherapyNavigationRow(
                        icon: "list.bullet.clipboard",
                        title: "Therapien & Prävention",
                        subtitle: "Maßnahmen anlegen und verwalten"
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, SymiSize.entryDetailContextIcon + SymiSpacing.md)

                NavigationLink {
                    TherapyHistoryView(viewModel: viewModel)
                } label: {
                    TherapyNavigationRow(
                        icon: "clock.arrow.circlepath",
                        title: "Verlauf",
                        subtitle: "Aktive, pausierte und beendete Maßnahmen"
                    )
                }
                .buttonStyle(.plain)
            }
            .therapyCard()
        }
    }
}

private struct TherapyNavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: SymiSpacing.md) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(AppTheme.symiPetrol)
                .frame(width: SymiSize.entryDetailContextIcon, height: SymiSize.entryDetailContextIcon)

            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, SymiSpacing.md)
    }
}

struct TherapyPlanView: View {
    @Bindable var viewModel: TherapyViewModel

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.presentMedicationEditor(for: nil, kind: .therapy)
                } label: {
                    Label("Therapie hinzufügen", systemImage: "plus")
                }

                Button {
                    viewModel.presentMedicationEditor(for: nil, kind: .prevention)
                } label: {
                    Label("Präventionsmaßnahme hinzufügen", systemImage: "plus")
                }
            } footer: {
                Text("Therapien und Präventionsmaßnahmen bleiben als eigener Verlauf von Akutmedikation in Tagebucheinträgen getrennt.")
            }

            ForEach(TherapyMeasureKind.allCases) { kind in
                Section(kind.pluralTitle) {
                    let measures = viewModel.measures(kind: kind)
                    if measures.isEmpty {
                        Text("Noch keine Einträge.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(measures) { measure in
                            TherapyPlanMedicationRow(
                                medication: measure,
                                onEdit: { viewModel.presentMedicationEditor(for: measure) },
                                onPause: { viewModel.updateStatus(id: measure.id, status: .paused) },
                                onResume: { viewModel.updateStatus(id: measure.id, status: .active) },
                                onEnd: { viewModel.updateStatus(id: measure.id, status: .ended) },
                                onDelete: { viewModel.deleteMeasure(id: measure.id) }
                            )
                        }
                    }
                }
            }

            Section("Aktuell laufend") {
                if viewModel.currentMeasures.isEmpty {
                    Text("Keine aktiven Therapien oder Präventionsmaßnahmen.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.currentMeasures) { medication in
                        TherapyPlanMedicationRow(
                            medication: medication,
                            onEdit: { viewModel.presentMedicationEditor(for: medication) },
                            onPause: { viewModel.updateStatus(id: medication.id, status: .paused) },
                            onResume: { viewModel.updateStatus(id: medication.id, status: .active) },
                            onEnd: { viewModel.updateStatus(id: medication.id, status: .ended) },
                            onDelete: { viewModel.deleteMeasure(id: medication.id) }
                        )
                    }
                }
            }

            if let message = viewModel.message {
                Section {
                    Text(message)
                        .foregroundStyle(AppTheme.symiCoral)
                }
            }
        }
        .navigationTitle("Maßnahmen")
        .brandGroupedScreen()
        .sheet(item: $viewModel.medicationEditor) { draft in
            NavigationStack {
                TherapyMedicationEditorSheet(
                    draft: draft,
                    onCancel: { viewModel.medicationEditor = nil },
                    onSave: { draft in
                        Task {
                            await viewModel.saveMedication(draft)
                        }
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            viewModel.load()
        }
        .refreshable {
            viewModel.load()
        }
    }
}

struct TherapyHistoryView: View {
    @Bindable var viewModel: TherapyViewModel

    var body: some View {
        List {
            Section {
                if viewModel.medications.isEmpty {
                    Text("Noch keine Einträge im Therapieverlauf.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.medications) { medication in
                        TherapyMeasureSummary(medication: medication)
                        .padding(.vertical, SymiSpacing.xxs)
                        .brandGroupedRow()
                    }
                }
            } header: {
                Text("Maßnahmenverlauf")
            } footer: {
                Text("Hier bleiben aktive, pausierte und beendete Therapien und Präventionsmaßnahmen historisch nachvollziehbar.")
            }
        }
        .navigationTitle("Verlauf")
        .brandGroupedScreen()
        .task {
            viewModel.load()
        }
        .refreshable {
            viewModel.load()
        }
    }

    private func dateRangeText(for medication: ContinuousMedicationRecord) -> String {
        let start = medication.startDate.formatted(date: .abbreviated, time: .omitted)
        guard let endDate = medication.endDate else {
            return "Seit \(start)"
        }

        return "\(start) bis \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct TherapyPlanMedicationRow: View {
    let medication: ContinuousMedicationRecord
    let onEdit: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onEnd: (() -> Void)?
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                    Text(medication.name)
                        .font(.headline)
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(medication.status.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            Text(dateRangeText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !medication.notes.isEmpty {
                Text(medication.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Bearbeiten", action: onEdit)
                if medication.status == .active {
                    Button("Pausieren", action: onPause)
                } else {
                    Button("Aktivieren", action: onResume)
                }
                if let onEnd, medication.status != .ended {
                    Button("Beenden", role: .destructive, action: onEnd)
                }
                Button("Löschen", role: .destructive, action: onDelete)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, SymiSpacing.xxs)
        .brandGroupedRow()
    }

    private var dateRangeText: String {
        let start = medication.startDate.formatted(date: .abbreviated, time: .omitted)
        guard let endDate = medication.endDate else {
            return "Seit \(start)"
        }

        return "\(start) bis \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private var summaryText: String {
        [
            medication.kind.title,
            medication.categoryText,
            medication.detailText.isEmpty ? nil : medication.detailText
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var statusColor: Color {
        switch medication.status {
        case .active:
            AppTheme.symiSage
        case .paused:
            .orange
        case .ended:
            .secondary
        }
    }
}

private struct TherapyMeasureSummary: View {
    let medication: ContinuousMedicationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
            Text(medication.name)
                .font(.headline)
            Text("\(medication.kind.title) · \(medication.categoryText) · \(medication.status.title)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(dateRangeText)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !medication.notes.isEmpty {
                Text(medication.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dateRangeText: String {
        let start = medication.startDate.formatted(date: .abbreviated, time: .omitted)
        guard let endDate = medication.endDate else {
            return "Seit \(start)"
        }

        return "\(start) bis \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct TherapyMedicationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ContinuousMedicationDraft
    @State private var hasEndDate: Bool

    let onCancel: () -> Void
    let onSave: (ContinuousMedicationDraft) -> Void

    init(
        draft: ContinuousMedicationDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (ContinuousMedicationDraft) -> Void
    ) {
        _draft = State(initialValue: draft)
        _hasEndDate = State(initialValue: draft.endDate != nil)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Eintrag") {
                Picker("Art", selection: $draft.kind) {
                    ForEach(TherapyMeasureKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }

                TextField("Bezeichnung", text: $draft.name)
                    .textInputAutocapitalization(.words)
                TextField("Kategorie", text: $draft.category)
                    .textInputAutocapitalization(.words)
                Picker("Status", selection: $draft.status) {
                    ForEach(TherapyMeasureStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
            }

            Section("Details") {
                TextField("Dosierung oder Umfang, optional", text: $draft.dosage)
                TextField("Frequenz oder Rhythmus, optional", text: $draft.frequency)
                TextField("Notizen, optional", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Zeitraum") {
                DatePicker("Startdatum", selection: $draft.startDate, displayedComponents: .date)
                Toggle("Enddatum setzen", isOn: $hasEndDate.animation())
                if hasEndDate {
                    DatePicker(
                        "Enddatum",
                        selection: Binding(
                            get: { draft.endDate ?? draft.startDate },
                            set: { draft.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
            }
        }
        .navigationTitle(draft.id == nil ? "Maßnahme" : "Bearbeiten")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") {
                    var normalizedDraft = draft
                    if !hasEndDate {
                        normalizedDraft.endDate = nil
                    }
                    if normalizedDraft.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        normalizedDraft.category = normalizedDraft.kind.defaultCategory
                    }
                    onSave(normalizedDraft)
                    dismiss()
                }
            }
        }
    }
}

private struct TherapyCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(SymiSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SymiColors.card.color, in: RoundedRectangle(cornerRadius: SymiRadius.card, style: .continuous))
            .shadow(color: SymiColors.primaryPetrol.color.opacity(SymiOpacity.hairline), radius: 16, x: 0, y: 8)
    }
}

private extension View {
    func therapyCard() -> some View {
        modifier(TherapyCardModifier())
    }
}
