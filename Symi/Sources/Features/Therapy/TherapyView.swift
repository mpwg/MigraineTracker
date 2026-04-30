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
                        title: "Medikationsplan",
                        subtitle: "Alle Medikamente & Zeitpläne"
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
                        subtitle: "Einnahmen & Anpassungen"
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
                    viewModel.presentMedicationEditor(for: nil)
                } label: {
                    Label("Medikament hinzufügen", systemImage: "plus")
                }
            } footer: {
                Text("Regelmäßige Medikamente bleiben als eigener Therapiekontext von Akutmedikation in Tagebucheinträgen getrennt.")
            }

            Section("Aktuell") {
                if viewModel.activeMedications.isEmpty {
                    Text("Keine aktive regelmäßige Medikation.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.activeMedications) { medication in
                        TherapyPlanMedicationRow(
                            medication: medication,
                            onEdit: { viewModel.presentMedicationEditor(for: medication) },
                            onEnd: { viewModel.endMedication(id: medication.id) }
                        )
                    }
                }
            }

            Section("Beendet") {
                if viewModel.endedMedications.isEmpty {
                    Text("Keine beendete regelmäßige Medikation.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.endedMedications) { medication in
                        TherapyPlanMedicationRow(
                            medication: medication,
                            onEdit: { viewModel.presentMedicationEditor(for: medication) },
                            onEnd: nil
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
        .navigationTitle("Medikationsplan")
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
                        VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                            Text(medication.name)
                                .font(.headline)
                            Text(medication.detailText.isEmpty ? "Keine Dosierung oder Frequenz angegeben." : medication.detailText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(dateRangeText(for: medication))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, SymiSpacing.xxs)
                        .brandGroupedRow()
                    }
                }
            } header: {
                Text("Einnahmen & Anpassungen")
            } footer: {
                Text("Hier siehst du den Verlauf deiner regelmäßigen Medikation. Dokumentierte Einnahmen aus Tagebucheinträgen bleiben weiterhin im Tagebuchkontext.")
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
    let onEnd: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                    Text(medication.name)
                        .font(.headline)
                    if !medication.detailText.isEmpty {
                        Text(medication.detailText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(medication.isActive ? "Aktiv" : "Beendet")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(medication.isActive ? AppTheme.symiSage : .secondary)
            }

            Text(dateRangeText)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Bearbeiten", action: onEdit)
                if let onEnd {
                    Button("Beenden", role: .destructive, action: onEnd)
                }
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
            Section("Medikament") {
                TextField("Name", text: $draft.name)
                    .textInputAutocapitalization(.words)
                TextField("Dosierung, optional", text: $draft.dosage)
                TextField("Frequenz oder Uhrzeit, optional", text: $draft.frequency)
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
        .navigationTitle(draft.id == nil ? "Medikament" : "Bearbeiten")
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
