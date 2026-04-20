import SwiftUI

struct LegacyContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "swift")
                .imageScale(.large)
                .foregroundStyle(.orange)
            Text("vocabulary")
                .font(.largeTitle)
                .bold()
        }
        .padding()
    }
}

#Preview {
    LegacyContentView()
}
