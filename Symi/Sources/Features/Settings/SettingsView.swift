import SwiftUI

struct SettingsView: View {
    let dependencies: SettingsFeatureDependencies
    let showsCloseButton: Bool
    @State private var controller: SettingsController
    @Environment(\.featureFlags) private var featureFlags

    init(dependencies: SettingsFeatureDependencies, showsCloseButton: Bool = true) {
        self.dependencies = dependencies
        self.showsCloseButton = showsCloseButton
        _controller = State(initialValue: dependencies.makeSettingsController())
    }

    var body: some View {
        List {
            Section("Synchronisation") {
                NavigationLink {
                    SyncView(dependencies: dependencies)
                } label: {
                    Label("Synchronisation", systemImage: "icloud")
                }
            }

            Section("Verbindungen") {
                NavigationLink {
                    AppleHealthView(dependencies: dependencies)
                } label: {
                    Label {
                        Text("Apple Health")
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(AppTheme.symiCoral)
                    }
                }
            }

            Section("Daten & Sicherheit") {
                NavigationLink {
                    DataSecurityView(dependencies: dependencies.dataExport)
                } label: {
                    Label("Daten & Sicherheit", systemImage: "checkmark.shield")
                }
            }

            Section("Datenschutz") {
                NavigationLink {
                    PrivacyView(dependencies: dependencies)
                } label: {
                    Label("Datenschutz", systemImage: "hand.raised")
                }
            }

            Section("App") {
                if featureFlags.isEnabled(.monetization) {
                    NavigationLink {
                        SymiPlusView()
                    } label: {
                        Label("Symi Plus", systemImage: "sparkles")
                    }
                }

                NavigationLink {
                    AboutSymiView(dependencies: dependencies)
                } label: {
                    Label("Version", systemImage: "info.circle")
                }

                NavigationLink {
                    FeedbackView()
                } label: {
                    Label("Feedback senden", systemImage: "bubble.left.and.text.bubble.right")
                }
            }

            Section("Diagnose") {
                NavigationLink {
                    DiagnosisView(controller: controller)
                } label: {
                    Label("Diagnose", systemImage: "text.document")
                }
            }
        }
        .navigationTitle("Einstellungen")
        .brandGroupedScreen()
        .task {
            controller.refreshLog(limit: 1)
        }
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
