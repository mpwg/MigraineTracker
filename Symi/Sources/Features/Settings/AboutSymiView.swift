import SwiftUI

struct AboutSymiView: View {
    @State private var controller: SettingsController

    init(dependencies: SettingsFeatureDependencies) {
        _controller = State(initialValue: dependencies.makeSettingsController())
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: controller.appVersionDisplay)
            }
        }
        .navigationTitle("Über Symi")
        .brandGroupedScreen()
    }
}
