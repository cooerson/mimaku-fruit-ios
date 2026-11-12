import SwiftUI

struct FruitPickerView: View {
    var title = "水果密码"
    var buttonTitle: String
    var showsAuto = false
    var shuffleToken = 0
    var onSubmit: (String) -> Void

    @State private var layout = Fruit.all.shuffled()
    @State private var selected: [Fruit] = []

    private var password: String { selected.map(\.code).joined() }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.mimakuGreen)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(layout) { fruit in
                    fruitButton(fruit)
                }
            }
            .padding(8)
            .background(Color.mimakuGrid, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    FruitIcon(key: "lock", size: 18)
                    Text("你的水果密码")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mimakuGreen)
                }
                chain
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.mimakuLine, lineWidth: 1.5))
            }
            .padding(12)
            .background(Color.mimakuPanel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(alignment: .top) {
                stat("破解概率学", selected.isEmpty ? "0" : (FruitPassword.grouped.string(from: NSNumber(value: FruitPassword.permutations(selected.count))) ?? "0"))
                Spacer()
                stat("熵值", selected.isEmpty ? "0" : String(format: "%.1f", FruitPassword.entropy(selected.count)))
            }

            HStack(spacing: 8) {
                if showsAuto {
                    Button(action: autoGenerate) {
                        Text("自动生成")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.mimakuSlate)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.mimakuPanel, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: submit) {
                    Text(buttonTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Color.mimakuGreen.opacity(selected.count < 6 ? 0.45 : 1),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: shuffleToken) { _ in
            layout = Fruit.all.shuffled()
        }
    }

    private func submit() {
        guard selected.count >= 6 else { return }
        onSubmit(password)
    }

    private func fruitButton(_ fruit: Fruit) -> some View {
        let index = selected.firstIndex(of: fruit)
        return Button {
            toggle(fruit)
        } label: {
            VStack(spacing: 2) {
                FruitIcon(key: fruit.key, size: 30)
                Text(fruit.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(fruit.labelColor)
                    .shadow(color: fruit.labelOnLight ? .clear : .black.opacity(0.28), radius: 1, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(fruit.color, in: Circle())
            .overlay {
                if index != nil {
                    Circle().stroke(Color.mimakuGreen, lineWidth: 3)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let index {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 22, height: 22)
                        .background(Color.mimakuGreen, in: Circle())
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fruit.name)
    }

    private var chain: some View {
        Group {
            if selected.isEmpty {
                Text("按顺序点选水果")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(Color.mimakuPlaceholder)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(selected.enumerated()), id: \.element.id) { index, fruit in
                            FruitIcon(key: fruit.key, size: 26)
                            if index < selected.count - 1 {
                                Text("→").font(.subheadline.weight(.semibold)).foregroundStyle(Color.mimakuGreen)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.mimakuMuted)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.mimakuInk)
        }
    }

    private func toggle(_ fruit: Fruit) {
        if let index = selected.firstIndex(of: fruit) {
            selected.remove(at: index)
        } else if selected.count < 16 {
            selected.append(fruit)
        }
    }

    private func autoGenerate() {
        let count = Int.random(in: 8...16)
        selected = Array(Fruit.all.shuffled().prefix(count))
    }
}
