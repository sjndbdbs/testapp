import SwiftUI

@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 30) {
            Text("备忘录测试")
                .font(.largeTitle)
                .bold()

            Text("你点了 \(count) 次")
                .font(.title2)
                .foregroundColor(.secondary)

            Button(action: { count += 1 }) {
                Text("点击 +1")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
            }

            Button(action: { count = 0 }) {
                Text("重置")
                    .foregroundColor(.red)
            }
        }
    }
}
