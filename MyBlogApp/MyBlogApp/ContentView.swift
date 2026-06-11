//
//  ContentView.swift
//  文章列表 + 设置

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
                    VStack(spacing: 20) {
                        Image(systemName: "lock.shield").font(.system(size: 50)).foregroundColor(.orange)
                        Text("需要设置 GitHub Token").font(.title2).bold()
                        Text("在设置中输入 Personal Access Token\n权限需勾选 repo")
                            .multilineTextAlignment(.center).foregroundColor(.secondary)
                        Button("打开设置") { showSettings = true }.buttonStyle(.borderedProminent)
                    }
                } else if service.posts.isEmpty && !service.isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text").font(.system(size: 48)).foregroundColor(.secondary)
                        Text("还没有文章").font(.title3).foregroundColor(.secondary)
                        Button { showNewPost = true } label: {
                            Label("写第一篇文章", systemImage: "plus.circle.fill")
                        }.buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(service.posts) { post in
                            Button { postToEdit = post } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(post.title).font(.headline).foregroundColor(.primary).lineLimit(2)
                                    HStack(spacing: 8) {
                                        Text(String(post.date.prefix(10))).font(.caption).foregroundColor(.secondary)
                                        if let c = post.categories.first {
                                            Text(c).font(.caption2).padding(.horizontal, 8).padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.15)).cornerRadius(6).foregroundColor(.orange)
                                        }
                                        ForEach(post.tags.prefix(2), id: \.self) { tag in
                                            Text(tag).font(.caption2).padding(.horizontal, 8).padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1)).cornerRadius(6).foregroundColor(.blue)
                                        }
                                    }
                                    Text(String(post.content.prefix(80))).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                                }.padding(.vertical, 4)
                            }
                        }.onDelete(perform: deletePosts)
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await service.fetchPosts() }
                }

                if service.isLoading { ProgressView().scaleEffect(1.5).frame(maxWidth: .infinity, maxHeight: .infinity).background(.ultraThinMaterial) }
            }
            .navigationTitle("Winnie's Blog")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { showSettings = true } label: { Image(systemName: "gearshape") } }
                ToolbarItem(placement: .topBarTrailing) { if service.isConfigured { Button { showNewPost = true } label: { Image(systemName: "plus") } } }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showNewPost) { PostEditorView(mode: .create) }
            .sheet(item: $postToEdit) { post in
                PostEditorView(mode: .edit(post))
            }
            .onChange(of: showNewPost) { _, dismissed in
                if !dismissed { Task { await service.fetchPosts() } }
            }
            .onChange(of: postToEdit) { _, post in
                if post == nil { Task { await service.fetchPosts() } }
            }
            .alert("错误", isPresented: .constant(service.errorMessage != nil)) {
                Button("OK") { service.errorMessage = nil }
            } message: { Text(service.errorMessage ?? "") }
            .task { if service.isConfigured { await service.fetchPosts() } }
        }
    }

    private func deletePosts(at offsets: IndexSet) {
        for i in offsets {
            let p = service.posts[i]
            Task { if await service.deletePost(p) { service.posts.remove(at: i) } }
        }
    }
}
