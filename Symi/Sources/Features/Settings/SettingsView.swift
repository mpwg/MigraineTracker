import SwiftUI

struct SettingsView: View {
    let dependencies: SettingsFeatureDependencies
    let showsCloseButton: Bool

    init(dependencies: SettingsFeatureDependencies, showsCloseButton: Bool = true) {
        self.dependencies = dependencies
        self.showsCloseButton = showsCloseButton
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
                    Label("Apple Health", systemImage: "heart")
                }
            }

            Section("Daten & Sicherheit") {
                NavigationLink {
                    DataSecurityView(dependencies: dependencies.dataExport)
                } label: {
                    Label("Daten & Sicherheit", systemImage: "externaldrive.badge.shield.check")
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
        }
        .navigationTitle("Einstellungen")
        .brandGroupedScreen()
    }
}

private struct AboutSymiView: View {
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

private struct FeedbackView: View {
    var body: some View {
        List {
            Section {
                Link(destination: ProductBranding.supportURL) {
                    Label("Feedback senden", systemImage: "bubble.left.and.text.bubble.right")
                }
            }
        }
        .navigationTitle("Feedback senden")
        .brandGroupedScreen()
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
