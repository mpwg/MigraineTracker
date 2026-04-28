import SwiftUI

struct CaptureView: View {
    let dependencies: CaptureFeatureDependencies

    var body: some View {
        EntryFlowCoordinatorView(dependencies: dependencies)
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
