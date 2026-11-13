import SwiftUI

/// 水果密码点选器，对应 web 版的 `mountFruitPicker`。
///
/// 登录页、顶部「水果密码」、改主密码三处共用同一个组件。
struct FruitPickerView: View {
    var title: String = "生成器"
    var buttonTitle: String = "一键登录"
    var showsAuto = false
    var onSubmit: (String) -> Void

    @State private var layout: [Fruit] = Fruit.all.shuffled()
    @State private var selected: [Fruit] = []
    @State private var tooMany = false

    private var password: String { selected.map(\.code).joined() }

    /// 每行 4 颗水果。用 HStack 而不是 LazyVGrid：网格会先用内容高度定行高，
    /// 圆形按钮就撑不满列宽，水果看起来偏小。
    private var grid: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row) { fruit in
                        FruitChip(fruit: fruit, order: order(of: fruit)) {
                            toggle(fruit)
                        }
                    }
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(Color.mimakuGrid, in: RoundedRectangle(cornerRadius: 12))
    }

    private var rows: [[Fruit]] {
        stride(from: 0, to: layout.count, by: 4).map {
            Array(layout[$0..<min($0 + 4, layout.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.mimakuGreen)
                .padding(.bottom, 8)

            grid
                .padding(.bottom, 16)

            passwordBox
            statsRow
            actions
        }
        .padding(.horizontal, 8)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .alert("最多只能选择 16 种水果！", isPresented: $tooMany) {
            Button("知道了", role: .cancel) {}
        }
    }

    private var passwordBox: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                FruitIcon(key: "lock", size: 18)
                Text("你的水果密码")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mimakuGreen)
            }

            Group {
                if selected.isEmpty {
                    Text("请选择水果生成密码")
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .italic()
                        .foregroundStyle(Color.mimakuPlaceholder)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(selected.enumerated()), id: \.element.id) { index, fruit in
                                FruitIcon(key: fruit.key, size: 22)
                                if index < selected.count - 1 {
                                    Text("→")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.mimakuGreen)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.mimakuLine, lineWidth: 1.5)
            )
        }
        .padding(16)
        .background(Color.mimakuPanel, in: RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 16)
    }

    private var statsRow: some View {
        HStack(alignment: .top) {
            stat(label: "破解概率学", value: FruitPassword.display(FruitPassword.arrangements(count: selected.count)))
            Spacer(minLength: 12)
            stat(label: "熵值", value: entropyText, alignment: .trailing)
        }
        .padding(.bottom, 16)
    }

    private func stat(label: String, value: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.mimakuMuted)
            Text(value)
                .font(.headline)
                .foregroundStyle(Color.mimakuInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var entropyText: String {
        guard !selected.isEmpty else { return "0" }
        return String(format: "%.1f", FruitPassword.entropy(count: selected.count))
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if showsAuto {
                Button("自动生成") { autoGenerate() }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
            }
            Button(buttonTitle) { onSubmit(password) }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .disabled(password.isEmpty)
        }
    }

    // MARK: - 交互

    private func order(of fruit: Fruit) -> Int? {
        selected.firstIndex(of: fruit).map { $0 + 1 }
    }

    private func toggle(_ fruit: Fruit) {
        if let index = selected.firstIndex(of: fruit) {
            selected.remove(at: index)
        } else if selected.count < Fruit.all.count {
            selected.append(fruit)
        } else {
            tooMany = true
        }
    }

    private func autoGenerate() {
        let count = 8 + Int.random(in: 0..<9)
        selected = Array(Fruit.all.shuffled().prefix(count))
    }
}

/// 网格里的一颗水果：圆形底色 + 角标显示点选顺序。
private struct FruitChip: View {
    /// 圆形按钮的边长。卡片最宽 360，扣掉卡片内边距、网格内边距和 3 个列间距后约 78；
    /// 取 74 是为了在 iPhone SE（375pt 宽）上也不会把四列挤出卡片。
    /// 用固定值是因为 `aspectRatio` 会拿内容高度当边长，圆形撑不满列宽。
    static let side: CGFloat = 74

    let fruit: Fruit
    let order: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                FruitIcon(key: fruit.key, size: 36)
                Text(fruit.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: Self.side, height: Self.side)
            .background(fruit.color, in: Circle())
            .overlay(
                Circle().stroke(Color.mimakuGreen, lineWidth: order == nil ? 0 : 2)
            )
            .overlay(alignment: .topTrailing) {
                if let order {
                    Text("\(order)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.mimakuGreen, in: Circle())
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
