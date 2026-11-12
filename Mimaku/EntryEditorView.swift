import SwiftUI
import UIKit

struct EntryEditorView: View {
    @EnvironmentObject private var model: VaultModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let entryID: String

    @State private var title = ""
    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var notes = ""
    @State private var reveal = false
    @State private var showPicker = false
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section {
                TextField("例如 邮箱、银行", text: $title)
            } header: {
                Text("标题")
            }
            Section {
                TextField("https://", text: $url)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            } header: {
                Text("网址")
            }
            Section {
                TextField("选填", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("用户名")
            }
            Section {
                HStack {
                    if reveal {
                        TextField("点「点选水果」填入", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("点「点选水果」填入", text: $password)
                    }
                    Button(reveal ? "隐藏" : "显示") { reveal.toggle() }
                        .font(.caption)
                }
                Button("点选水果") { showPicker = true }
                Button("复制") {
                    UIPasteboard.general.string = password
                    model.banner = password.isEmpty ? "还没有水果密码" : "已复制水果密码"
                }
            } header: {
                HStack(spacing: 4) {
                    Image("lock")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text("水果密码")
                }
            }
            Section {
                TextField("选填", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("备注")
            }
            Section {
                Button("放进果篮") { save() }
                    .disabled(model.busy)
                Button("打开网站") { openSite() }
                Button("删除", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(title.isEmpty ? "新条目" : title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                ScrollView {
                    FruitPickerView(buttonTitle: "填入", showsAuto: true) { code in
                        password = code
                        reveal = true
                        showPicker = false
                        model.banner = "已填入，点「放进果篮」才会保存"
                    }
                    .padding(18)
                }
                .navigationTitle("水果密码")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { showPicker = false }
                    }
                }
            }
        }
        .confirmationDialog("删除这条？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                Task {
                    if await model.delete(id: entryID) {
                        dismiss()
                    }
                }
            }
        }
    }

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
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新条目" : title.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            notes: notes
        )
        Task { await model.save(entry) }
    }

    private func openSite() {
        let raw = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            model.banner = "还没有网址"
            return
        }
        let text = raw.hasPrefix("http://") || raw.hasPrefix("https://") ? raw : "https://\(raw)"
        guard let link = URL(string: text) else {
            model.banner = "网址打不开"
            return
        }
        openURL(link)
    }
}
