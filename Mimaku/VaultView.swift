import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct VaultView: View {
    @EnvironmentObject private var model: VaultModel
    @State private var path: [String] = []
    @State private var query = ""
    @State private var showPasswordChange = false
    @State private var showImporter = false
    @State private var shareItem: ShareItem?

    private var emptyTitle: String {
        if model.loadingList { return "正在打开果篮" }
        if model.loadError != nil { return "没能打开果篮" }
        if model.accountIsNew { return "这是新的果篮" }
        return "果篮还是空的"
    }

    private var emptyDetail: String {
        if model.loadingList { return "请稍等" }
        if let loadError = model.loadError { return loadError }
        if model.accountIsNew {
            return "这组水果密码第一次使用。以前的条目在另一组水果密码里。"
        }
        return "点右上角「新建」。"
    }

    private var shown: [Entry] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return model.entries }
        return model.entries.filter {
            ($0.title + " " + $0.username + " " + $0.url).lowercased().contains(text)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if shown.isEmpty {
                    VStack(spacing: 12) {
                        FruitIcon(key: "basket", size: 42)
                        Text(emptyTitle)
                            .font(.headline)
                            .foregroundStyle(Color.mimakuGreen)
                            .multilineTextAlignment(.center)
                        Text(emptyDetail)
                            .font(.subheadline)
                            .foregroundStyle(Color.mimakuMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.white)
                } else {
                    ForEach(shown) { entry in
                        NavigationLink(value: entry.id) {
                            EntryRow(entry: entry)
                        }
                        .listRowBackground(Color.white)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .refreshable { await model.refresh() }
            .navigationTitle("果篮")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "搜索条目")
            .navigationDestination(for: String.self) { id in
                EntryEditorView(entryID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(model.entries.count) 颗")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.mimakuMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button(action: createNew) {
                            HStack(spacing: 4) {
                                Image("greenApple")
                                    .resizable()
                                    .renderingMode(.original)
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                Text("新建")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 240 / 255, green: 253 / 255, blue: 244 / 255), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Menu {
                            Button("改主密码") { showPasswordChange = true }
                            Button("导出") { export() }
                            Button("导入") { showImporter = true }
                            Divider()
                            Button("退出", role: .destructive) { model.lock() }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.mimakuInk)
                                .frame(width: 32, height: 32)
                                .background(Color.mimakuPanel, in: Circle())
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPasswordChange) {
            PasswordChangeView()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    Task { await model.importPack(data) }
                }
            }
        }
    }

    private func createNew() {
        Task {
            if let entry = await model.createEmpty() {
                path.append(entry.id)
            }
        }
    }

    private func export() {
        if let url = try? model.exportFile() {
            shareItem = ShareItem(url: url)
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            let fruit = Fruit.forEntry(entry.id)
            FruitIcon(key: fruit.key, size: 28)
                .padding(8)
                .background(fruit.color, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title.isEmpty ? "未命名" : entry.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.mimakuInk)
                Text(entry.username.isEmpty ? (entry.url.isEmpty ? "—" : entry.url) : entry.username)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 71 / 255, green: 85 / 255, blue: 105 / 255))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ContentUnavailable: View {
    let text: String
    var body: some View {
        Text(text)
            .foregroundStyle(Color.mimakuMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PasswordChangeView: View {
    @EnvironmentObject private var model: VaultModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = 1
    @State private var oldPassword = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                FruitPickerView(
                    title: step == 1 ? "点选现在的水果密码" : "点选新的水果密码",
                    buttonTitle: step == 1 ? "下一步" : "保存"
                ) { password in
                    if step == 1 {
                        oldPassword = password
                        step = 2
                    } else {
                        Task {
                            if await model.changePassword(old: oldPassword, new: password) {
                                dismiss()
                            }
                        }
                    }
                }
                .id(step)
                .padding(18)
            }
            .navigationTitle("改主密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
