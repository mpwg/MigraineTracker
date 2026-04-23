import SwiftUI

struct WeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution = WeatherAttribution.fallback
    @State private var showsAttributionDetails = false

    var showsDescription = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsDescription {
                Text(WeatherAttribution.modifiedSourceDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let markURL {
                AsyncImage(url: markURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    weatherMarkFallback
                }
                .frame(maxWidth: 180, minHeight: 28, maxHeight: 48, alignment: .leading)
                .accessibilityLabel(attribution.serviceName)
            } else {
                weatherMarkFallback
            }

            Button {
                showsAttributionDetails = true
            } label: {
                Label("Wetterquellen anzeigen", systemImage: "doc.text")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .font(.footnote)
        }
        .task {
            attribution = await WeatherAttribution.load()
        }
        .sheet(isPresented: $showsAttributionDetails) {
            WeatherAttributionDetailView(attribution: attribution)
                .presentationDetents([.medium, .large])
        }
    }

    private var markURL: URL? {
        colorScheme == .dark ? attribution.combinedMarkLightURL : attribution.combinedMarkDarkURL
    }

    private var weatherMarkFallback: some View {
        Text(attribution.serviceName)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityLabel(attribution.serviceName)
    }
}

private struct WeatherAttributionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let attribution: WeatherAttributionData

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    weatherMark

                    if let legalAttributionText = attribution.legalAttributionText, !legalAttributionText.isEmpty {
                        Text(legalAttributionText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(WeatherAttribution.sourceDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: attribution.legalPageURL) {
                        Label("Rechtliche Hinweise öffnen", systemImage: "arrow.up.right.square")
                    }
                    .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Wetterquellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var weatherMark: some View {
        if let markURL {
            AsyncImage(url: markURL) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                weatherMarkFallback
            }
            .frame(maxWidth: 220, minHeight: 32, maxHeight: 56, alignment: .leading)
            .accessibilityLabel(attribution.serviceName)
        } else {
            weatherMarkFallback
        }
    }

    private var markURL: URL? {
        colorScheme == .dark ? attribution.combinedMarkLightURL : attribution.combinedMarkDarkURL
    }

    private var weatherMarkFallback: some View {
        Text(attribution.serviceName)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityLabel(attribution.serviceName)
    }
}
