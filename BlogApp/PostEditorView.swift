//  PostEditorView.swift
//  发布 / 修改文章

import SwiftUI

enum EditorMode {
    case create
    case edit(Post)
}

struct PostEditorView: View {
    @EnvironmentObject var service: GitHubService
    @Environment(\.dismiss) var dismiss

    let mode: EditorMode

    @State private var title = ""
    @State private var content = ""
    @State private var selectedCategory = "长文"
    @State private var selectedTag = "随笔"
    @State private var isSaving = false

    let categories = ["长文", "短文"]
    let tags = ["随笔", "技术", "生活", "读书笔记", "朋友圈", "其他"]

    var body: some View {
        NavigationStack {
            Form {
                // 标题
                Section("标题") {
                    TextField("文章标题", text: $title)
                }

                // 分类 + 标签
                Section("分类 & 标签") {
                    Picker("分类", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }

                    Picker("标签", selection: $selectedTag) {
                        ForEach(tags, id: \.self) { Text($0) }
                    }
                }

                // 正文
                Section("正文 (Markdown)") {
                    TextEditor(text: $content)
                        .frame(minHeight: 250)
                        .font(.body)
                }
            }
            .navigationTitle(modeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(mode == .create ? "发布" : "保存")
                                .bold()
                        }
                    }
                    .disabled(title.isEmpty || content.isEmpty || isSaving)
                }
            }
            .onAppear {
                if case .edit(let post) = mode {
                    title = post.title
                    content = post.content
                    selectedCategory = post.categories.first ?? "长文"
                    selectedTag = post.tags.first ?? "随笔"
                }
            }
        }
    }

    private var modeTitle: String {
        switch mode {
        case .create: return "写文章"
        case .edit(let p): return "编辑「\(p.title)」"
        }
    }

    private func save() {
        isSaving = true
        Task {
            var success = false
            switch mode {
            case .create:
                success = await service.createPost(
                    title: title,
                    content: content,
                    tags: [selectedTag],
                    categories: [selectedCategory]
                )
            case .edit(let post):
                success = await service.updatePost(
                    post,
                    title: title,
                    content: content,
                    tags: [selectedTag],
                    categories: [selectedCategory]
                )
            }

            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var service: GitHubService
    @Environment(\.dismiss) var dismiss

    @State private var token = ""
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("ghp_xxxxxxxxxxxx", text: $token)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } header: {
                    Text("GitHub Personal Access Token")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("需要勾选 repo 权限")
                        Button("如何获取 Token？") { showInfo = true }
                            .font(.caption)
                    }
                }

                Section {
                    Button("保存") {
                        service.token = token
                        dismiss()
                        Task { await service.fetchPosts() }
                    }
                    .disabled(token.isEmpty)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .listRowBackground(Color.orange)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { token = service.token }
            .alert("获取 Token", isPresented: $showInfo) {
                Button("打开 GitHub") {
                    if let url = URL(string: "https://github.com/settings/tokens") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("1. 打开 GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)\n2. Generate new token → 勾选 repo\n3. 复制生成的 token 粘贴到这里")
            }
        }
    }
}
