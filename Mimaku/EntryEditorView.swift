import SwiftUI
import UIKit

/// 条目编辑页，对应 web 版的 `#editor` 面板。
struct EntryEditorView: View {
    let entryID: String
    @Binding var path: [String]

    @EnvironmentObject private var model: VaultModel

    @State private var title = ""
    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var notes = ""
    @State private var revealPassword = false
    @State private var showGenerator = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                backButton

                field("标题", placeholder: "例如 邮箱 / 银行", text: $title)
                field("网址", placeholder: "https://", text: $url, keyboard: .URL)
                field("用户名", text: $username)

                passwordField

                VStack(alignment: .leading, spacing: 6) {
                    label("备注")
                    TextEditor(text: $notes)
                        .frame(minHeight: 110)
                        .padding(6)
                        .background(.white, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mimakuLine, lineWidth: 2))
                }

                HStack(spacing: 8) {
                    Button("放进果篮") { save() }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                    Button("打开网站") { openWebsite() }
                        .buttonStyle(PillButtonStyle(kind: .ghost))
                    Button("删除") { confirmDelete = true }
                        .buttonStyle(PillButtonStyle(kind: .danger))
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: load)
        .sheet(isPresented: $showGenerator) {
            SheetCard {
                FruitPickerView(title: "生成器", buttonTitle: "写入条目", showsAuto: true) { generated in
                    password = generated
                    revealPassword = true
                    showGenerator = false
                    model.showBanner("已写入，记得保存")
                }
            }
        }
        .alert("删除这条记录？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) { delete() }
            Button("取消", role: .cancel) {}
        }
    }

    private var backButton: some View {
        Button {
            if !path.isEmpty { path.removeLast() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("返回")
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.mimakuInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.mimakuPanel, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func field(
        _ title: String,
        placeholder: String = "",
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label(title)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mimakuLine, lineWidth: 2))
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                FruitIcon(key: "lock", size: 15)
                Text("水果密码")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mimakuGreen)
            }

            HStack(spacing: 6) {
                Group {
                    if revealPassword {
                        TextField("", text: $password)
                    } else {
                        SecureField("", text: $password)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mimakuLine, lineWidth: 2))
            }

            HStack(spacing: 6) {
                Button(revealPassword ? "隐藏" : "显示") { revealPassword.toggle() }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
                Button("点选水果") { showGenerator = true }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                Button("复制") { copyPassword() }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.mimakuGreen)
    }

    // MARK: - 操作

    private func load() {
        guard let entry = model.entries.first(where: { $0.id == entryID }) else { return }
        title = entry.title
        url = entry.url
        username = entry.username
        password = entry.password
        notes = entry.notes
    }

    private func save() {
        let entry = Entry(
            id: entryID,
            title: title,
            url: url,
            username: username,
            password: password,
            notes: notes
        )
        Task {
            if await model.save(entry), !path.isEmpty {
                path.removeLast()
            }
        }
    }

    private func delete() {
        Task {
            if await model.delete(id: entryID), !path.isEmpty {
                path.removeLast()
            }
        }
    }

    private func copyPassword() {
        guard !password.isEmpty else {
            model.showBanner("还没有密码")
            return
        }
        UIPasteboard.general.string = password
        model.showBanner("已复制密码")
    }

    private func openWebsite() {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            model.showBanner("还没有填写网站")
            return
        }
        let target = trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")
            ? trimmed
            : "https://" + trimmed
        guard let link = URL(string: target) else {
            model.showBanner("网址格式不对")
            return
        }
        UIApplication.shared.open(link)
    }
}
