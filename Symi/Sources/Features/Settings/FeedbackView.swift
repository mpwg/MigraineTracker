import SwiftUI

struct FeedbackView: View {
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
