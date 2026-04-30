import SwiftUI

struct PrivacyView: View {
    @State private var controller: SettingsController

    init(dependencies: SettingsFeatureDependencies) {
        _controller = State(initialValue: dependencies.makeSettingsController())
    }

    var body: some View {
        List {
            Section {
                Toggle("Anonyme Nutzungsdaten teilen", isOn: usageDataBinding)
            } footer: {
                Text("Hilft uns, Symi zu verbessern. Deine persönlichen Einträge bleiben immer privat.")
            }

            Section {
                NavigationLink {
                    ProductInformationView(mode: .standard)
                } label: {
                    Label("Datenschutz & Hinweise", systemImage: "hand.raised")
                }
            }
        }
        .navigationTitle("Datenschutz")
        .brandGroupedScreen()
    }

    private var usageDataBinding: Binding<Bool> {
        Binding(
            get: { controller.isUsageDataCollectionAllowed },
            set: { controller.setUsageDataCollectionAllowed($0) }
        )
    }
}
