import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: VaultModel
    @State private var shuffleToken = 0

    var body: some View {
        ZStack {
            Color(red: 109 / 255, green: 108 / 255, blue: 196 / 255).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        LogoMark()
                        Text("水果密码")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Text("点选 6–16 种不重复的水果。")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 238 / 255, green: 242 / 255, blue: 255 / 255))

                    ZStack(alignment: .bottomTrailing) {
                        FruitPickerView(buttonTitle: model.busy ? "正在进入…" : "进入果篮", shuffleToken: shuffleToken) { password in
                            Task { await model.login(password: password) }
                        }
                        .disabled(model.busy)
                        .padding(18)
                        .padding(.bottom, 28)

                        Button {
                            shuffleToken += 1
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.mimakuGreen)
                                .frame(width: 32, height: 32)
                                .background(Color.mimakuPanel, in: Circle())
                        }
                        .disabled(model.busy)
                        .padding(12)
                        .accessibilityLabel("重排水果")
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 18, y: 8)

                    if let loginError = model.loginError {
                        Text(loginError)
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 254 / 255, green: 202 / 255, blue: 202 / 255))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct LogoMark: View {
    var body: some View {
        Image("apple")
            .resizable()
            .scaledToFit()
            .frame(width: 43, height: 43)
            .shadow(color: Color(red: 0.55, green: 0.20, blue: 0.22).opacity(0.28), radius: 3, y: 2)
            .frame(width: 72, height: 72)
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: Color(red: 0.992, green: 0.984, blue: 0.996), location: 0.48),
                                .init(color: Color(red: 0.90, green: 0.875, blue: 0.94), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .top) {
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 54, height: 18)
                            .offset(y: 5)
                    }
                    .clipShape(Circle())
            }
            .overlay {
                Circle().strokeBorder(
                    LinearGradient(
                        colors: [
                            .white,
                            Color.white.opacity(0.5),
                            Color(red: 0.82, green: 0.78, blue: 0.90)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.2
                )
            }
            .shadow(color: Color(red: 30 / 255, green: 27 / 255, blue: 75 / 255).opacity(0.24), radius: 10, y: 6)
    }
}
