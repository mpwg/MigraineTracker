import SwiftUI

struct AppleHealthView: View {
    @State private var controller: SettingsController

    init(dependencies: SettingsFeatureDependencies) {
        _controller = State(initialValue: dependencies.makeSettingsController())
    }

    var body: some View {
        AppleHealthSettingsView(controller: controller)
    }
}
