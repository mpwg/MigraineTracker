import SwiftUI

struct CaptureView: View {
    @State private var intensity: Double = 5
    @State private var startedAt = Date()
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Episode") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Intensität")
                    HStack {
                        Text("1")
                            .foregroundStyle(.secondary)
                        Slider(value: $intensity, in: 1 ... 10, step: 1)
                        Text("10")
                            .foregroundStyle(.secondary)
                    }
                    Text("\(Int(intensity)) / 10")
                        .font(.headline)
                }

                DatePicker("Beginn", selection: $startedAt)
            }

            Section("Notiz") {
                TextField("Optionale Notiz", text: $notes, axis: .vertical)
                    .lineLimit(3 ... 6)
            }

            Section("Nächste Ausbaustufen") {
                Text("Hier werden in den nächsten Issues Symptome, Trigger, Medikamente und Wetterkontext ergänzt.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Erfassen")
    }
}

#Preview {
    NavigationStack {
        CaptureView()
    }
}
