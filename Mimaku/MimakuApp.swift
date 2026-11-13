import SwiftUI

@main
struct MimakuApp: App {
    @StateObject private var model = VaultModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(.mimakuGreen)
                .preferredColorScheme(.light)
        }
    }
}

/// 根据登录状态切换登录页 / 果篮，并统一在顶部显示提示条。
struct RootView: View {
    @EnvironmentObject private var model: VaultModel

    var body: some View {
        ZStack(alignment: .top) {
            if model.isLocked {
                LoginView()
            } else {
                VaultView()
            }

            if let banner = model.banner {
                Text(banner)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.78), in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.banner)
    }
}
