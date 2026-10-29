import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "command")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("CmdTab")
                .font(.largeTitle.bold())
            Text("A macOS app built with SwiftUI")
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(minWidth: 320, minHeight: 240)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
