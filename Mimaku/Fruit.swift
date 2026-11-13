import SwiftUI

/// 一种水果，对应 web 版 FRUITS 表里的一格。
///
/// 顺序、字母表、颜色都与 index.html 中的 `FRUITS` / `.fruit-*` 保持一致。
struct Fruit: Identifiable, Hashable {
    let key: String
    let name: String
    let code: String
    let red: Double
    let green: Double
    let blue: Double

    var id: String { key }

    var color: Color { Color(red: red, green: green, blue: blue) }

    static let all: [Fruit] = [
        Fruit(key: "apple", name: "苹果", code: "A", red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        Fruit(key: "banana", name: "香蕉", code: "B", red: 251 / 255, green: 191 / 255, blue: 36 / 255),
        Fruit(key: "orange", name: "橘子", code: "O", red: 249 / 255, green: 115 / 255, blue: 22 / 255),
        Fruit(key: "grape", name: "葡萄", code: "G", red: 139 / 255, green: 92 / 255, blue: 246 / 255),
        Fruit(key: "strawberry", name: "草莓", code: "S", red: 236 / 255, green: 72 / 255, blue: 153 / 255),
        Fruit(key: "watermelon", name: "西瓜", code: "W", red: 16 / 255, green: 185 / 255, blue: 129 / 255),
        Fruit(key: "peach", name: "桃子", code: "P", red: 253 / 255, green: 164 / 255, blue: 175 / 255),
        Fruit(key: "pineapple", name: "凤梨", code: "I", red: 251 / 255, green: 191 / 255, blue: 36 / 255),
        Fruit(key: "mango", name: "芒果", code: "M", red: 249 / 255, green: 115 / 255, blue: 22 / 255),
        Fruit(key: "kiwi", name: "奇异果", code: "K", red: 132 / 255, green: 204 / 255, blue: 22 / 255),
        Fruit(key: "tomato", name: "番茄", code: "L", red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        Fruit(key: "cherry", name: "樱桃", code: "C", red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        Fruit(key: "lemon", name: "柠檬", code: "E", red: 251 / 255, green: 191 / 255, blue: 36 / 255),
        Fruit(key: "pear", name: "梨子", code: "R", red: 132 / 255, green: 204 / 255, blue: 22 / 255),
        Fruit(key: "chili", name: "辣椒", code: "U", red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        Fruit(key: "coconut", name: "椰子", code: "N", red: 163 / 255, green: 163 / 255, blue: 163 / 255)
    ]

    static func named(_ key: String) -> Fruit? {
        all.first { $0.key == key }
    }

    /// web 版按条目 id 的字符码之和取模挑图标，这里保持一致。
    static func forEntry(_ id: String) -> Fruit {
        let sum = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return all[sum % all.count]
    }
}

/// 水果图片（Assets.xcassets 里的同名 imageset）。
struct FruitIcon: View {
    let key: String
    var size: CGFloat = 24

    var body: some View {
        Image(key)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// 水果密码的规则与统计，对应 web 版的 validFruitPassword / factorial / 熵值。
enum FruitPassword {
    /// 与 Go 版 `fruitAlphabet` 完全一致。
    static let alphabet: Set<Character> = Set("ABOGSWPIMKLCEURN")
    static let minimumLength = 6
    static let maximumLength = 16

    static func isValid(_ value: String) -> Bool {
        let characters = Array(value)
        guard (minimumLength...maximumLength).contains(characters.count) else { return false }
        var seen = Set<Character>()
        for character in characters {
            guard alphabet.contains(character), seen.insert(character).inserted else { return false }
        }
        return true
    }

    /// 16! / (16 - n)!，即点选 n 个水果时的排列总数。
    static func arrangements(count: Int) -> Double {
        guard count > 0 else { return 0 }
        var value = 1.0
        for index in 0..<count {
            value *= Double(Fruit.all.count - index)
        }
        return value
    }

    /// 每个水果贡献 log2(16) = 4 bit 熵。
    static func entropy(count: Int) -> Double {
        count > 0 ? Double(count) * 4 : 0
    }

    static func display(_ value: Double) -> String {
        grouped.string(from: NSNumber(value: value)) ?? "0"
    }

    private static let grouped: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

extension Color {
    static let mimakuGreen = Color(red: 40 / 255, green: 167 / 255, blue: 69 / 255)
    static let mimakuGreenDark = Color(red: 33 / 255, green: 136 / 255, blue: 56 / 255)
    static let mimakuInk = Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
    static let mimakuSlate = Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255)
    static let mimakuMuted = Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255)
    static let mimakuLine = Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255)
    static let mimakuPanel = Color(red: 241 / 255, green: 245 / 255, blue: 249 / 255)
    static let mimakuGrid = Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255)
    static let mimakuPlaceholder = Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255)
    static let mimakuPurple = Color(red: 109 / 255, green: 108 / 255, blue: 196 / 255)
    static let mimakuDangerText = Color(red: 185 / 255, green: 28 / 255, blue: 28 / 255)
    static let mimakuDangerFill = Color(red: 254 / 255, green: 226 / 255, blue: 226 / 255)
}

/// 与 web 版 `.btn` 一致的胶囊按钮。
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case ghost
        case danger
    }

    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(fill, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .white
        case .ghost: return .mimakuSlate
        case .danger: return .mimakuDangerText
        }
    }

    private var fill: Color {
        switch kind {
        case .primary: return .mimakuGreen
        case .ghost: return .mimakuPanel
        case .danger: return .mimakuDangerFill
        }
    }
}
