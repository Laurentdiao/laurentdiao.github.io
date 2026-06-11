//
//  PostEditorView.swift
//  MyBlogApp
//

import PhotosUI
import SwiftUI

enum EditorMode: Identifiable, Equatable {
    case create
    case edit(Post)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let post): return "edit-\(post.filename)"
        }
    }

    static func == (lhs: EditorMode, rhs: EditorMode) -> Bool {
        lhs.id == rhs.id
    }
}

struct PostEditorView: View {
    @EnvironmentObject private var service: GitHubService
    @Environment(\.dismiss) private var dismiss

    let mode: EditorMode
    var onSaved: () -> Void = {}

    @State private var title = ""
    @State private var content = ""
    @State private var selectedCategory = "长文"
    @State private var selectedTags: Set<String> = ["随笔"]
    @State private var isSaving = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var saveSucceeded = false

    private let categories = ["长文", "短文"]
    private let tags = ["随笔", "技术", "生活", "读书笔记", "朋友圈", "日常", "其他"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("写一个题目", text: $title, axis: .vertical)
                        .font(.headline)
                        .lineLimit(1...3)
                } header: {
                    Text("标题")
                }

                Section("文章类型") {
                    Picker("分类", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("标签") {
                    TagSelectionGrid(tags: tags, selectedTags: $selectedTags)
                }

                Section {
                    HStack {
                        Label("正文", systemImage: "text.alignleft")
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                            Label(isUploadingImage ? "上传中" : "插入图片", systemImage: "photo")
                                .font(.caption)
                        }
                        .disabled(isUploadingImage || isSaving)
                    }

                    TextEditor(text: $content)
                        .frame(minHeight: 320)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                } footer: {
                    Text("图片会上传到 source/images，并自动在正文末尾插入 Markdown。")
                }
            }
            .navigationTitle(navigationTitle)
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
                            Text(mode == .create ? "发布" : "保存").bold()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .overlay(alignment: .bottom) {
                if saveSucceeded {
                    StatusToast(text: "已提交到 GitHub，网页会自动更新。", systemImage: "checkmark.circle.fill")
                        .padding(.bottom, 18)
                }
            }
            .onAppear(perform: loadInitialValues)
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                insertImage(from: item)
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .create: return "写文章"
        case .edit: return "编辑文章"
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSaving &&
        !isUploadingImage
    }

    private func loadInitialValues() {
        guard case .edit(let post) = mode else { return }
        title = post.title
        content = post.content
        selectedCategory = post.categories.first ?? "长文"
        selectedTags = Set(post.tags.isEmpty ? ["随笔"] : post.tags)
    }

    private func insertImage(from item: PhotosPickerItem) {
        Task {
            isUploadingImage = true
            defer { isUploadingImage = false; selectedPhoto = nil }

            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let url = await service.uploadImage(image) else {
                service.errorMessage = "图片上传失败，请稍后再试。"
                return
            }

            content += "\n\n![](\(url))\n"
        }
    }

    private func save() {
        isSaving = true

        Task {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let sortedTags = tags.filter { selectedTags.contains($0) }
            let finalTags = sortedTags.isEmpty ? ["随笔"] : sortedTags

            let ok: Bool
            switch mode {
            case .create:
                ok = await service.createPost(title: trimmedTitle, content: trimmedContent, tags: finalTags, categories: [selectedCategory])
            case .edit(let post):
                ok = await service.updatePost(post, title: trimmedTitle, content: trimmedContent, tags: finalTags, categories: [selectedCategory])
            }

            isSaving = false
            if ok {
                saveSucceeded = true
                onSaved()
                try? await Task.sleep(for: .milliseconds(650))
                dismiss()
            }
        }
    }
}

struct AboutEditorView: View {
    @EnvironmentObject private var service: GitHubService
    @Environment(\.dismiss) private var dismiss

    var onSaved: () -> Void = {}

    @State private var page: BlogPage?
    @State private var title = "关于"
    @State private var content = ""
    @State private var isSaving = false
    @State private var saveSucceeded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("页面标题") {
                    TextField("关于", text: $title)
                }

                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 360)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                } header: {
                    Text("About Me 内容")
                } footer: {
                    Text("这里对应 source/about/index.md，支持 Markdown。")
                }
            }
            .navigationTitle("About Me")
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
                            Text("保存").bold()
                        }
                    }
                    .disabled(page == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .overlay {
                if page == nil || service.isLoading {
                    ProgressView("正在读取 About Me")
                }
            }
            .overlay(alignment: .bottom) {
                if saveSucceeded {
                    StatusToast(text: "About Me 已提交。", systemImage: "checkmark.circle.fill")
                        .padding(.bottom, 18)
                }
            }
            .task {
                guard page == nil else { return }
                if let loaded = await service.fetchAboutPage() {
                    page = loaded
                    title = loaded.title
                    content = loaded.content
                }
            }
        }
    }

    private func save() {
        guard let page else { return }
        isSaving = true

        Task {
            let ok = await service.updateAboutPage(
                page,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            isSaving = false

            if ok {
                saveSucceeded = true
                onSaved()
                try? await Task.sleep(for: .milliseconds(650))
                dismiss()
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var service: GitHubService
    @Environment(\.dismiss) private var dismiss

    @State private var token = ""
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("github_pat_... 或 ghp_...", text: $token)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("GitHub Personal Access Token")
                } footer: {
                    Button("如何获取？") { showInfo = true }
                        .font(.caption)
                }

                Section {
                    Button {
                        service.token = token
                        dismiss()
                        Task { await service.fetchPosts() }
                    } label: {
                        Label("保存 Token", systemImage: "key.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .listRowBackground(Color.orange)
                    .foregroundColor(.white)

                    Button(role: .destructive) {
                        service.token = ""
                        token = ""
                    } label: {
                        Label("清除 Token", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { token = service.token }
            .alert("获取 Token", isPresented: $showInfo) {
                Button("打开 GitHub") {
                    if let url = URL(string: "https://github.com/settings/personal-access-tokens") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("创建 Fine-grained token，选择 Laurentdiao/laurentdiao.github.io，并给 Contents: Read and write 权限。")
            }
        }
    }
}

private struct TagSelectionGrid: View {
    let tags: [String]
    @Binding var selectedTags: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    if selectedTags.contains(tag) {
                        selectedTags.remove(tag)
                    } else {
                        selectedTags.insert(tag)
                    }
                } label: {
                    Text(tag)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTags.contains(tag) ? Color.orange.opacity(0.18) : Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(selectedTags.contains(tag) ? Color.orange : Color.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusToast: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}
