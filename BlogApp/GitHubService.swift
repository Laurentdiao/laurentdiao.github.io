//  GitHubService.swift
//  GitHub API 封装 - CRUD 操作

import Foundation

@MainActor
class GitHubService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repo = "laurentdiao.github.io"
    private let owner = "Laurentdiao"
    private let baseURL = "https://api.github.com"

    // Token 存 UserDefaults
    var token: String {
        get { UserDefaults.standard.string(forKey: "github_token") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "github_token") }
    }

    var isConfigured: Bool { !token.isEmpty }

    private func request(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let body = body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    // MARK: - 获取文章列表
    func fetchPosts() async {
        guard isConfigured else {
            errorMessage = "请先设置 GitHub Token"
            return
        }
        isLoading = true
        errorMessage = nil

        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/source/_posts")!

        do {
            let (data, resp) = try await URLSession.shared.data(for: request(url: url))
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                errorMessage = "获取失败，请检查 Token 权限"
                isLoading = false
                return
            }

            let files = try JSONDecoder().decode([GitHubFile].self, from: data)
            var loaded: [Post] = []

            for file in files where file.name.hasSuffix(".md") {
                // 获取文件内容
                let fileURL = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(file.path)")!
                let (fileData, _) = try await URLSession.shared.data(for: request(url: fileURL))
                let fileInfo = try JSONDecoder().decode(FullGitHubFile.self, from: fileData)

                if let decoded = Data(base64Encoded: fileInfo.content.replacingOccurrences(of: "\n", with: "")),
                   let content = String(data: decoded, encoding: .utf8),
                   let post = Post.from(githubFile: file, content: content) {
                    loaded.append(post)
                }
            }

            posts = loaded.sorted { $0.date > $1.date }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 创建文章
    func createPost(title: String, content: String, tags: [String], categories: [String]) async -> Bool {
        let post = Post(title: title, date: "", tags: tags, categories: categories, content: content, filename: "", sha: nil)
        let md = post.toMarkdown()
        let filename = sanitize(title) + ".md"
        let path = "source/_posts/\(filename)"

        return await putFile(path: path, content: md, sha: nil, message: "Add \(title)")
    }

    // MARK: - 更新文章
    func updatePost(_ post: Post, title: String, content: String, tags: [String], categories: [String]) async -> Bool {
        var updated = post
        updated.title = title
        updated.content = content
        updated.tags = tags
        updated.categories = categories
        let md = updated.toMarkdown()
        let path = "source/_posts/\(post.filename)"

        // 改用新文件名如果标题变了
        let newFilename = sanitize(title) + ".md"
        let newPath = "source/_posts/\(newFilename)"

        if newFilename != post.filename {
            // 先删旧文件再建新文件
            _ = await deleteFile(path: path, sha: post.sha ?? "")
            return await putFile(path: newPath, content: md, sha: nil, message: "Update \(title)")
        } else {
            return await putFile(path: path, content: md, sha: post.sha, message: "Update \(title)")
        }
    }

    // MARK: - 删除文章
    func deletePost(_ post: Post) async -> Bool {
        let path = "source/_posts/\(post.filename)"
        return await deleteFile(path: path, sha: post.sha ?? "")
    }

    // MARK: - GitHub Actions 触发部署
    func triggerDeploy() {
        // GitHub Pages with main branch auto-serves, but we push a dispatch
        // Actually for main branch, the file push IS the deploy
    }

    // MARK: - Private helpers
    private func putFile(path: String, content: String, sha: String?, message: String) async -> Bool {
        let encoded = Data(content.utf8).base64EncodedString()
        let body: [String: Any] = [
            "message": message,
            "content": encoded,
            "branch": "main",
            "sha": sha as Any
        ].compactMapValues { $0 is String && ($0 as! String).isEmpty ? nil : $0 }

        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var req = request(url: url, method: "PUT", body: try! JSONSerialization.data(withJSONObject: body))

        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            return code == 200 || code == 201
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func deleteFile(path: String, sha: String) async -> Bool {
        let body: [String: Any] = [
            "message": "Delete \(path)",
            "sha": sha,
            "branch": "main"
        ]
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var req = request(url: url, method: "DELETE", body: try! JSONSerialization.data(withJSONObject: body))

        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return ((resp as? HTTPURLResponse)?.statusCode ?? 0) == 200
        } catch {
            return false
        }
    }

    private func sanitize(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return title.components(separatedBy: invalid).joined(separator: "_")
    }
}

struct FullGitHubFile: Codable {
    let content: String
    let sha: String
}
