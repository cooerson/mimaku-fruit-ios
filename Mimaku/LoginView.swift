import SwiftUI

/// 登录页：紫底 + 水果点选，对应 web 版的 `#gate`。
struct LoginView: View {
    @EnvironmentObject private var model: VaultModel

    var body: some View {
        ZStack {
            Color.mimakuPurple.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        LogoMark(size: 52)
                        Text("水果密码")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }

                    Text("密码长度为 6–16 个水果。")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.93, green: 0.95, blue: 1))

                    FruitPickerView(buttonTitle: "一键登录") { password in
                        Task { await model.login(password: password) }
                    }
                    .frame(maxWidth: 360)

                    if model.busy {
                        ProgressView()
                            .tint(.white)
                    }

                    if let error = model.loginError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Color(red: 0.996, green: 0.792, blue: 0.792))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// 圆形 logo，对应 web 版的 `.logo-dot`。
struct LogoMark: View {
    var size: CGFloat = 48

    var body: some View {
        Image("logo")
            .resizable()
            .scaledToFit()
            .padding(size * 0.14)
            .frame(width: size, height: size)
            .background(Color.white, in: Circle())
            .shadow(color: Color(red: 30 / 255, green: 27 / 255, blue: 75 / 255).opacity(0.28), radius: 9, y: 6)
    }
}
