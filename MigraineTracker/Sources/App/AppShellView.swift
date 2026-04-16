import SwiftUI

struct AppShellView: View {
    let appContainer: AppContainer

    var body: some View {
        NavigationStack {
            HistoryView(appContainer: appContainer)
        }
        .task {
            await appContainer.weatherBackfillService.runIfNeeded()
        }
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
