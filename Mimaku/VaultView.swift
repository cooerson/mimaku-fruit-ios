import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 果篮主界面，对应 web 版的 `#app`。
struct VaultView: View {
    @EnvironmentObject private var model: VaultModel

    @State private var path: [String] = []
    @State private var showGenerator = false
    @State private var showPasswordChange = false
    @State private var showImport = false
    @State private var exportItem: ExportItem?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: String.self) { id in
                    EntryEditorView(entryID: id, path: $path)
                }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            actionGrid
            searchField
            entryList
            footer
        }
        .background(Color.mimakuGrid)
        .sheet(isPresented: $showGenerator) {
            SheetCard {
                FruitPickerView(title: "生成器", buttonTitle: "复制密码", showsAuto: true) { password in
                    copyGenerated(password)
                }
            }
        }
        .sheet(isPresented: $showPasswordChange) {
            PasswordChangeView()
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(items: [item.url])
        }
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: 12) {
            LogoMark(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("水果密码")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Color.mimakuGreen)
                Text("数据都存储在本地")
                    .font(.footnote)
                    .foregroundStyle(Color.mimakuMuted)
                HStack(spacing: 5) {
                    ForEach(["apple", "banana", "grape", "watermelon", "strawberry", "orange"], id: \.self) { key in
                        Circle()
                            .fill(Fruit.named(key)?.color ?? .mimakuGreen)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [Color(red: 240 / 255, green: 253 / 255, blue: 244 / 255), .white],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var actionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            action("新建", icon: "greenApple", kind: .ghost, action: newEntry)
            action("水果密码", icon: "watermelon", kind: .primary, action: openGenerator)
            action("改主密码", icon: "lock", kind: .ghost) { showPasswordChange = true }
            action("导出", icon: "basket", kind: .ghost, action: export)
            action("导入", icon: "inbox", kind: .ghost) { showImport = true }
            action("退出", icon: nil, kind: .ghost) { model.lock() }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .background(.white)
    }

    private func action(
        _ title: String,
        icon: String?,
        kind: PillButtonStyle.Kind,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    FruitIcon(key: icon, size: 16)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(PillButtonStyle(kind: kind))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.mimakuPlaceholder)
            TextField("在果篮里搜索", text: $model.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(Color.mimakuLine, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - 列表

    @ViewBuilder
    private var entryList: some View {
        if model.filteredEntries.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.filteredEntries) { entry in
                        Button {
                            model.selectedID = entry.id
                            path.append(entry.id)
                        } label: {
                            EntryRow(entry: entry, isSelected: entry.id == model.selectedID)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(emptyKeys, id: \.self) { key in
                    ZStack {
                        Circle().fill(Fruit.named(key)?.color ?? .mimakuGreen)
                        FruitIcon(key: key, size: 22)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
            .frame(width: 220)
            .padding(10)
            .background(Color.mimakuGrid, in: RoundedRectangle(cornerRadius: 16))

            Text("果篮还是空的")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.mimakuGreen)
            Text("点「新建」，或用水果密码生成一条。")
                .font(.subheadline)
                .foregroundStyle(Color.mimakuMuted)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var footer: some View {
        HStack {
            Text("\(model.entries.count) 颗果实")
            Spacer()
            HStack(spacing: 4) {
                FruitIcon(key: "basket", size: 14)
                Text("果篮")
            }
        }
        .font(.caption)
        .foregroundStyle(Color.mimakuMuted)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.white)
    }

    // MARK: - 操作

    private func newEntry() {
        Task {
            if let created = await model.createEmpty() {
                path.append(created.id)
            }
        }
    }

    private func openGenerator() {
        showGenerator = true
    }

    private func copyGenerated(_ password: String) {
        UIPasteboard.general.string = password
        showGenerator = false
        model.showBanner("已复制水果密码")
    }

    private func export() {
        do {
            exportItem = ExportItem(url: try model.exportFile())
            model.showBanner("已导出")
        } catch {
            model.showBanner(error.localizedDescription)
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            Task { model.showBanner(await model.importPack(data)) }
        } catch {
            model.showBanner("读取文件失败")
        }
    }

    private var emptyKeys: [String] {
        ["apple", "banana", "orange", "grape", "strawberry", "watermelon",
         "peach", "kiwi", "lemon", "cherry", "mango", "coconut"]
    }
}

/// 列表里的一行，对应 web 版的 `.item`。
private struct EntryRow: View {
    let entry: Entry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Fruit.forEntry(entry.id).color)
                FruitIcon(key: Fruit.forEntry(entry.id).key, size: 24)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title.isEmpty ? "无标题" : entry.title)
                    .font(.headline)
                    .foregroundStyle(Color.mimakuInk)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.mimakuMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.mimakuPlaceholder)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.mimakuGreen, lineWidth: 2)
                .opacity(isSelected ? 1 : 0)
        )
    }

    private var subtitle: String {
        if !entry.username.isEmpty { return entry.username }
        if !entry.url.isEmpty { return entry.url }
        return "—"
    }
}

/// 修改主密码：两步式的水果点选，对应 web 版的 `#pwdModal`。
private struct PasswordChangeView: View {
    @EnvironmentObject private var model: VaultModel
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var oldPassword = ""
    @State private var error: String?

    var body: some View {
        SheetCard {
            VStack(spacing: 10) {
                Text("修改主密码")
                    .font(.headline)
                    .foregroundStyle(Color.mimakuInk)
                Text(step == 1 ? "第 1 步：点选当前登录用的水果顺序" : "第 2 步：点选新的水果顺序")
                    .font(.subheadline)
                    .foregroundStyle(Color.mimakuMuted)
                    .multilineTextAlignment(.center)

                FruitPickerView(
                    buttonTitle: step == 1 ? "下一步" : "保存新顺序",
                    onSubmit: handle
                )
                .id(step)

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255))
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.mimakuPlaceholder)
                        .frame(width: 32, height: 32)
                }
            }
        }
    }

    private func handle(_ password: String) {
        error = nil
        if step == 1 {
            guard password.count >= FruitPassword.minimumLength else {
                error = "请至少点选 6 种水果"
                return
            }
            oldPassword = password
            step = 2
            return
        }
        guard oldPassword.count >= FruitPassword.minimumLength else {
            error = "请先点选当前水果顺序"
            return
        }
        guard password.count >= FruitPassword.minimumLength else {
            error = "请至少点选 6 种水果"
            return
        }
        guard password != oldPassword else {
            error = "新水果顺序不能与当前相同"
            return
        }
        Task {
            if let message = await model.changePassword(old: oldPassword, new: password) {
                error = message
            } else {
                dismiss()
            }
        }
    }
}

/// 所有弹窗共用的白卡容器。
struct SheetCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .padding(16)
        }
        .background(Color.white)
    }
}

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// 导出备份用的系统分享面板。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
