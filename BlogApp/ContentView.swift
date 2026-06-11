//  ContentView.swift
//  主界面 - 文章列表 + 设置

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: GitHubService
    @State private var showSettings = false
    @State private var showNewPost = false
    @State private var postToEdit: Post?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if !service.isConfigured {
                    // 未配置 Token
                    VStack(spacing: 20) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("需要设置 GitHub Token")
                            .font(.title2).bold()
                        Text("在设置中输入你的 Personal Access Token\n权限需要勾选 repo")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Button("打开设置") { showSettings = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if service.posts.isEmpty && !service.isLoading {
                    // 空状态
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("还没有文章")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Button { showNewPost = true } label: {
                            Label("写第一篇文章", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(service.posts) { post in
                            Button {
                                postToEdit = post
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(post.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)

                                    HStack(spacing: 8) {
                                        Text(post.date.prefix(10))
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        if let cat = post.categories.first {
                                            Text(cat)
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.15))
                                                .cornerRadius(6)
                                                .foregroundColor(.orange)
                                        }

                                        ForEach(post.tags.prefix(2), id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(6)
                                                .foregroundColor(.blue)
                                        }
                                    }

                                    Text(post.content.prefix(80))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deletePosts)
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await service.fetchPosts() }
                }

                // Loading
                if service.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Winnie's Blog")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if service.isConfigured {
                        Button { showNewPost = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showNewPost) {
                PostEditorView(mode: .create)
            }
            .sheet(item: $postToEdit) { post in
                PostEditorView(mode: .edit(post))
            }
            .onChange(of: showNewPost) { if !$0 { Task { await service.fetchPosts() } } }
            .onChange(of: postToEdit) { if $0 == nil { Task { await service.fetchPosts() } } }
            .alert("错误", isPresented: .constant(service.errorMessage != nil)) {
                Button("OK") { service.errorMessage = nil }
            } message: {
                Text(service.errorMessage ?? "")
            }
            .task {
                if service.isConfigured { await service.fetchPosts() }
            }
        }
    }

    private func deletePosts(at offsets: IndexSet) {
        for index in offsets {
            let post = service.posts[index]
            Task {
                if await service.deletePost(post) {
                    service.posts.remove(at: index)
                }
            }
        }
    }
}
