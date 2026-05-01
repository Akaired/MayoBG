import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 52))
                .foregroundStyle(.blue)
                .padding(.top, 8)

            Text("MayoBG")
                .font(.title)
                .fontWeight(.bold)

            Text("settings.version".localized)
                .foregroundStyle(.secondary)

            Text("settings.copyright".localized)
                .font(.callout)
                .foregroundStyle(.secondary)

            if let url = URL(string: "https://www.davidemaiorana.dev") {
                Link("www.davidemaiorana.dev", destination: url)
                    .font(.callout)
                    .pointingHandCursor()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private extension View {
    func pointingHandCursor() -> some View {
        onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
