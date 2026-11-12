import SwiftUI

@main
struct MimakuApp: App {
    @StateObject private var model = VaultModel()

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                Group {
                    if model.token == nil {
                        LoginView()
                    } else {
                        VaultView()
                    }
                }
                .environmentObject(model)
                if let banner = model.banner {
                    Text(banner)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.78), in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            Task {
                                try? await Task.sleep(nanoseconds: 2_200_000_000)
                                if model.banner == banner {
                                    model.banner = nil
                                }
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.banner)
            .tint(Color.mimakuGreen)
            .preferredColorScheme(.light)
        }
    }
}
