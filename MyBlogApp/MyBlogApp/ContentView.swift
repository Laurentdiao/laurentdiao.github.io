//
//  ContentView.swift
//  MyBlogApp
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var service: GitHubService
    @Environment(\.openURL) private var openURL

    @State private var showSettings = false
    @State private var showNewPost = false
    @State private var showAboutEditor = false
    @State private var postToEdit: Post?
    @State private var postPendingDeletion: Post?
    @State private var showDeleteDialog = false
    @State private var showError = false

    var body: some View {
        navigationRoot
            .sheet(isPresented: $showSettings, content: settingsSheet)
            .sheet(isPresented: $showNewPost, content: newPostSheet)
            .sheet(isPresented: $showAboutEditor, content: aboutSheet)
            .sheet(item: $postToEdit, content: editPostSheet)
            .confirmationDialog("删除文章？", isPresented: $showDeleteDialog, titleVisibility: .visible, actions: deleteDialogActions, message: deleteDialogMessage)
            .alert("出错了", isPresented: $showError, actions: errorAlertActions, message: errorAlertMessage)
            .onChange(of: service.errorMessage, initial: false, handleErrorChange)
            .task(loadPostsIfNeeded)
    }

    private var navigationRoot: some View {
        NavigationStack {
            rootContent
                .navigationTitle("Winnie's Blog")
                .toolbar { toolbarContent }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if service.isConfigured {
            PostsListView(
                posts: service.posts,
                isLoading: service.isLoading,
                onRefresh: refreshPosts,
                onNewPost: openNewPost,
                onAbout: openAboutEditor,
                onOpenSite: openSite,
                onEdit: edit,
                onDelete: confirmDeletion
            )
        } else {
            SetupPrompt(onSettings: openSettings)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("设置")
        }

        ToolbarItem(placement: .topBarTrailing) {
            addMenu
        }
    }

    @ViewBuilder
    private var addMenu: some View {
        Menu {
            Button(action: openNewPost) {
                Label("写文章", systemImage: "square.and.pencil")
            }

            Button(action: openAboutEditor) {
                Label("改 About Me", systemImage: "person.crop.circle")
            }

            Button(action: openSite) {
                Label("打开网站", systemImage: "safari")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
        }
        .disabled(!service.isConfigured)
        .accessibilityLabel("新建或编辑")
    }

    private func delete(_ post: Post) {
        Task {
            if await service.deletePost(post) {
                await service.fetchPosts()
            }
        }
    }

    private func refreshPosts() async {
        await service.fetchPosts()
    }

    private func edit(_ post: Post) {
        postToEdit = post
    }

    private func confirmDeletion(_ post: Post) {
        postPendingDeletion = post
        showDeleteDialog = true
    }

    private func openSettings() {
        showSettings = true
    }

    private func openNewPost() {
        showNewPost = true
    }

    private func openAboutEditor() {
        showAboutEditor = true
    }

    private func openSite() {
        openURL(service.publicURL)
    }

    private func loadPostsIfNeeded() async {
        guard service.isConfigured, service.posts.isEmpty else { return }
        await service.fetchPosts()
    }

    private func settingsSheet() -> some View {
        SettingsView()
    }

    private func newPostSheet() -> some View {
        PostEditorView(mode: .create, onSaved: reloadPosts)
    }

    private func aboutSheet() -> some View {
        AboutEditorView()
    }

    private func editPostSheet(_ post: Post) -> some View {
        PostEditorView(mode: .edit(post), onSaved: reloadPosts)
    }

    private func reloadPosts() {
        Task { await service.fetchPosts() }
    }

    private func deleteDialogActions() -> some View {
        Group {
            if let post = postPendingDeletion {
                Button("删除「\(post.title)」", role: .destructive) {
                    delete(post)
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func deleteDialogMessage() -> some View {
        Text("删除会直接提交到 GitHub，并触发网页重新部署。")
    }

    @ViewBuilder
    private func errorAlertActions() -> some View {
        Button("OK") {
            service.errorMessage = nil
        }
    }

    private func errorAlertMessage() -> some View {
        Text(service.errorMessage ?? "")
    }

    private func handleErrorChange(_ oldValue: String?, _ newValue: String?) {
        showError = newValue != nil
    }
}

private struct PostsListView: View {
    let posts: [Post]
    let isLoading: Bool
    let onRefresh: @Sendable () async -> Void
    let onNewPost: () -> Void
    let onAbout: () -> Void
    let onOpenSite: () -> Void
    let onEdit: (Post) -> Void
    let onDelete: (Post) -> Void

    var body: some View {
        List {
            quickActionsSection
            contentSection
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await onRefresh()
        }
        .overlay(content: loadingOverlay)
    }

    private var quickActionsSection: some View {
        Section {
            QuickActionRow(
                onNewPost: onNewPost,
                onAbout: onAbout,
                onOpenSite: onOpenSite
            )
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 6, trailing: 16))
    }

    @ViewBuilder
    private var contentSection: some View {
        if posts.isEmpty && !isLoading {
            EmptyPostsView(onNewPost: onNewPost)
                .listRowBackground(Color.clear)
        } else {
            Section("文章") {
                ForEach(posts) { post in
                    PostListRow(
                        post: post,
                        onEdit: onEdit,
                        onDelete: onDelete
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func loadingOverlay() -> some View {
        if isLoading {
            ProgressView("正在同步")
                .padding(18)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct PostListRow: View {
    let post: Post
    let onEdit: (Post) -> Void
    let onDelete: (Post) -> Void

    var body: some View {
        PostRow(post: post)
            .contentShape(Rectangle())
            .onTapGesture {
                onEdit(post)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    onDelete(post)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    onEdit(post)
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                .tint(.orange)
            }
    }
}

private struct SetupPrompt: View {
    var onSettings: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock.shield")
                .font(.system(size: 54))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("连接 GitHub 后开始写博客")
                    .font(.title3.bold())
                Text("需要一个只给博客仓库 Contents 读写权限的 Personal Access Token。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onSettings) {
                Label("打开设置", systemImage: "key.fill")
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct QuickActionRow: View {
    var onNewPost: () -> Void
    var onAbout: () -> Void
    var onOpenSite: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            QuickActionButton(title: "写文章", systemImage: "square.and.pencil", action: onNewPost)
            QuickActionButton(title: "About", systemImage: "person.crop.circle", action: onAbout)
            QuickActionButton(title: "网站", systemImage: "safari", action: onOpenSite)
        }
    }
}

private struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.orange)
    }
}

private struct EmptyPostsView: View {
    var onNewPost: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("还没有文章")
                .font(.headline)
            Button(action: onNewPost) {
                Label("写第一篇文章", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
    }
}

private struct PostRow: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Label(String(post.date.prefix(10)), systemImage: "calendar")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let category = post.categories.first {
                    Pill(text: category, color: .orange)
                }

                ForEach(post.tags.prefix(2), id: \.self) { tag in
                    Pill(text: tag, color: .blue)
                }
            }

            if !post.content.isEmpty {
                Text(post.content.replacingOccurrences(of: "\n", with: " ").prefix(92))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct Pill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
