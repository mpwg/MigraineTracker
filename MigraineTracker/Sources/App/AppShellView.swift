import SwiftUI

struct AppShellView: View {
    let appContainer: AppContainer

    var body: some View {
        NavigationStack {
            HomeView(appContainer: appContainer)
        }
        .tint(AppTheme.ocean)
        .toolbarBackground(AppTheme.ink.opacity(0.96), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await appContainer.weatherBackfillService.runIfNeeded()
        }
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
