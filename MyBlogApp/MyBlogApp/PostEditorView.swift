//
//  PostEditorView.swift
//  发布/编辑 + 图片上传 + 设置

import SwiftUI
import PhotosUI

enum EditorMode: Identifiable {
    case create, edit(Post)
    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let p): return p.id.uuidString
        }
    }
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
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingImage = false

    let categories = ["长文", "短文"]
    let tags = ["随笔", "技术", "生活", "读书笔记", "朋友圈", "其他"]

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") { TextField("文章标题", text: $title) }

                Section("分类 & 标签") {
                    Picker("分类", selection: $selectedCategory) { ForEach(categories, id: \.self) { Text($0) } }
                    Picker("标签", selection: $selectedTag) { ForEach(tags, id: \.self) { Text($0) } }
                }

                Section {
                    HStack {
                        Text("正文 (Markdown)")
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                            Label("插入图片", systemImage: "photo")
                                .font(.caption)
                        }
                        .disabled(isUploadingImage)
                        if isUploadingImage { ProgressView().scaleEffect(0.8) }
                    }
                    TextEditor(text: $content)
                        .frame(minHeight: 250)
                        .font(.body)
                }
            }
            .navigationTitle(modeTitle).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isSaving { ProgressView() }
                        else { Text(mode == .create ? "发布" : "保存").bold() }
                    }.disabled(title.isEmpty || content.isEmpty || isSaving)
                }
            }
            .onAppear {
                if case .edit(let p) = mode {
                    title = p.title; content = p.content
                    selectedCategory = p.categories.first ?? "长文"
                    selectedTag = p.tags.first ?? "随笔"
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let item = newItem else { return }
                Task {
                    isUploadingImage = true
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data),
                       let url = await service.uploadImage(img) {
                        content += "\n\n![](" + url + ")\n"
                    }
                    isUploadingImage = false
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
            let ok: Bool = switch mode {
            case .create: await service.createPost(title: title, content: content, tags: [selectedTag], categories: [selectedCategory])
            case .edit(let p): await service.updatePost(p, title: title, content: content, tags: [selectedTag], categories: [selectedCategory])
            }
            await MainActor.run { isSaving = false; if ok { dismiss() } }
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
                Section { SecureField("ghp_xxxxxxxxxxxx", text: $token).font(.system(.body, design: .monospaced)).autocapitalization(.none).disableAutocorrection(true) }
                header: { Text("GitHub Personal Access Token") }
                footer: { Button("如何获取？") { showInfo = true }.font(.caption) }
                Section { Button("保存") { service.token = token; dismiss(); Task { await service.fetchPosts() } }.disabled(token.isEmpty).frame(maxWidth: .infinity).foregroundColor(.white).listRowBackground(Color.orange) }
            }
            .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .onAppear { token = service.token }
            .alert("获取 Token", isPresented: $showInfo) {
                Button("打开 GitHub") { if let u = URL(string: "https://github.com/settings/tokens") { UIApplication.shared.open(u) } }
                Button("OK", role: .cancel) {}
            } message: { Text("1. Settings → Developer settings → Tokens (classic)\n2. Generate → 勾选 repo\n3. 复制粘贴") }
        }
    }
}
