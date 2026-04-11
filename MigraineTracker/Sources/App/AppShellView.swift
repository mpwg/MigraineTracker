import SwiftUI

struct AppShellView: View {
    @AppStorage("hasSeenTrustOnboarding") private var hasSeenTrustOnboarding = false

    var body: some View {
        NavigationStack {
            HistoryView()
        }
        .sheet(isPresented: onboardingBinding) {
            NavigationStack {
                ProductInformationView(
                    mode: .onboarding,
                    acknowledge: { hasSeenTrustOnboarding = true }
                )
            }
            .interactiveDismissDisabled()
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasSeenTrustOnboarding },
            set: { isPresented in
                if !isPresented {
                    hasSeenTrustOnboarding = true
                }
            }
        )
    }
}

#Preview {
    AppShellView()
}
