import SwiftUI

struct AppShellView: View {
    let appContainer: AppContainer

    var body: some View {
        #if os(macOS)
        MacAppShellView(appContainer: appContainer)
        #else
        IOSAppShellView(appContainer: appContainer)
        #endif
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
