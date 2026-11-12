import SwiftUI

struct Fruit: Identifiable, Hashable {
    let key: String
    let name: String
    let code: String
    let red: Double
    let green: Double
    let blue: Double

    var id: String { key }
    var color: Color { Color(red: red, green: green, blue: blue) }

    /// 黄、粉、灰、黄绿这类浅底上用深色字，其余保持白字。
    var labelOnLight: Bool {
        switch key {
        case "banana", "lemon", "pineapple", "peach", "kiwi", "coconut":
            return true
        default:
            return false
        }
    }

    var labelColor: Color { labelOnLight ? .mimakuInk : .white }

    static let all: [Fruit] = [
        Fruit(key: "watermelon", name: "西瓜", code: "W", red: 0.06, green: 0.73, blue: 0.51),
        Fruit(key: "coconut", name: "椰子", code: "N", red: 0.64, green: 0.64, blue: 0.64),
        Fruit(key: "peach", name: "桃子", code: "P", red: 0.99, green: 0.64, blue: 0.69),
        Fruit(key: "grape", name: "葡萄", code: "G", red: 0.55, green: 0.36, blue: 0.96),
        Fruit(key: "pineapple", name: "凤梨", code: "I", red: 0.98, green: 0.75, blue: 0.14),
        Fruit(key: "lemon", name: "柠檬", code: "E", red: 0.98, green: 0.75, blue: 0.14),
        Fruit(key: "cherry", name: "樱桃", code: "C", red: 0.94, green: 0.27, blue: 0.27),
        Fruit(key: "chili", name: "辣椒", code: "U", red: 0.94, green: 0.27, blue: 0.27),
        Fruit(key: "kiwi", name: "奇异果", code: "K", red: 0.52, green: 0.80, blue: 0.09),
        Fruit(key: "orange", name: "橘子", code: "O", red: 0.98, green: 0.45, blue: 0.09),
        Fruit(key: "strawberry", name: "草莓", code: "S", red: 0.93, green: 0.28, blue: 0.60),
        Fruit(key: "mango", name: "芒果", code: "M", red: 0.98, green: 0.45, blue: 0.09),
        Fruit(key: "apple", name: "苹果", code: "A", red: 0.94, green: 0.27, blue: 0.27),
        Fruit(key: "banana", name: "香蕉", code: "B", red: 0.98, green: 0.75, blue: 0.14),
        Fruit(key: "tomato", name: "番茄", code: "L", red: 0.94, green: 0.27, blue: 0.27),
        Fruit(key: "pear", name: "梨子", code: "R", red: 0.52, green: 0.80, blue: 0.09)
    ]

    static func named(_ key: String) -> Fruit? {
        all.first { $0.key == key }
    }

    static func forEntry(_ id: String) -> Fruit {
        let sum = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return all[sum % all.count]
    }
}

struct FruitIcon: View {
    let key: String
    var size: CGFloat = 32

    var body: some View {
        Image(key)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

extension Color {
    static let mimakuGreen = Color(red: 40 / 255, green: 167 / 255, blue: 69 / 255)
    static let mimakuInk = Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
    static let mimakuMuted = Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255)
    static let mimakuSlate = Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255)
    static let mimakuPanel = Color(red: 241 / 255, green: 245 / 255, blue: 249 / 255)
    static let mimakuGrid = Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255)
    static let mimakuLine = Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255)
    static let mimakuPlaceholder = Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255)
}

enum FruitPassword {
    static func permutations(_ count: Int) -> Int64 {
        guard count > 0 else { return 0 }
        var value: Int64 = 1
        for n in (16 - count + 1)...16 {
            value *= Int64(n)
        }
        return value
    }

    static func entropy(_ count: Int) -> Double {
        Double(count) * 4
    }

    static let grouped: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()
}
