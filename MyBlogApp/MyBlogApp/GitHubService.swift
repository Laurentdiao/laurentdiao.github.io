//
//  GitHubService.swift
//  GitHub API + 图片上传

import Foundation
import UIKit

@MainActor
class GitHubService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repo = "laurentdiao.github.io"
    private let owner = "Laurentdiao"
    private let baseURL = "https://api.github.com"

    var token: String {
        get { UserDefaults.standard.string(forKey: "github_token") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "github_token") }
    }

    var isConfigured: Bool { !token.isEmpty }

    // MARK: - Posts
    func fetchPosts() async {
        guard isConfigured else { return }
        isLoading = true; errorMessage = nil
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/source/_posts")!
        do {
            let (data, _) = try await URLSession.shared.data(for: request(url: url))
            let files = try JSONDecoder().decode([GitHubFile].self, from: data)
            var loaded: [Post] = []
            for file in files where file.name.hasSuffix(".md") {
                let fURL = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(file.path)")!
                let (fd, _) = try await URLSession.shared.data(for: request(url: fURL))
                let info = try JSONDecoder().decode(FullGitHubFile.self, from: fd)
                if let dec = Data(base64Encoded: info.content.replacingOccurrences(of: "\n", with: "")),
                   let c = String(data: dec, encoding: .utf8),
                   let post = Post.from(githubFile: file, content: c) {
                    loaded.append(post)
                }
            }
            posts = loaded.sorted { $0.date > $1.date }
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    func createPost(title: String, content: String, tags: [String], categories: [String]) async -> Bool {
        let p = Post(title: title, date: "", tags: tags, categories: categories, content: content, filename: "", sha: nil)
        let filename = sanitize(title) + ".md"
        return await putFile(path: "source/_posts/\(filename)", content: p.toMarkdown(), sha: nil, message: "Add \(title)")
    }

    func updatePost(_ post: Post, title: String, content: String, tags: [String], categories: [String]) async -> Bool {
        var p = post; p.title = title; p.content = content; p.tags = tags; p.categories = categories
        let oldPath = "source/_posts/\(post.filename)"
        let newFilename = sanitize(title) + ".md"
        if newFilename != post.filename {
            _ = await deleteFile(path: oldPath, sha: post.sha ?? "")
            return await putFile(path: "source/_posts/\(newFilename)", content: p.toMarkdown(), sha: nil, message: "Update \(title)")
        }
        return await putFile(path: oldPath, content: p.toMarkdown(), sha: post.sha, message: "Update \(title)")
    }

    func deletePost(_ post: Post) async -> Bool {
        await deleteFile(path: "source/_posts/\(post.filename)", sha: post.sha ?? "")
    }

    // MARK: - Image Upload
    func uploadImage(_ image: UIImage) async -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let encoded = data.base64EncodedString()
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "img_\(timestamp).jpg"
        let path = "source/images/\(filename)"
        let body: [String: Any] = ["message": "Upload image", "content": encoded, "branch": "main"]
        let urlStr = "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)"

        var req = request(url: URL(string: urlStr)!, method: "PUT", body: try! JSONSerialization.data(withJSONObject: body))
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if ((resp as? HTTPURLResponse)?.statusCode ?? 0) == 201 {
                return "/images/\(filename)"
            }
        } catch { errorMessage = error.localizedDescription }
        return nil
    }

    // MARK: - Private
    private func putFile(path: String, content: String, sha: String?, message: String) async -> Bool {
        let encoded = Data(content.utf8).base64EncodedString()
        var body: [String: Any] = ["message": message, "content": encoded, "branch": "main"]
        if let s = sha { body["sha"] = s }
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var req = request(url: url, method: "PUT", body: try! JSONSerialization.data(withJSONObject: body))
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return [200, 201].contains((resp as? HTTPURLResponse)?.statusCode ?? 0)
        } catch { return false }
    }

    private func deleteFile(path: String, sha: String) async -> Bool {
        let body: [String: Any] = ["message": "Delete \(path)", "sha": sha, "branch": "main"]
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var req = request(url: url, method: "DELETE", body: try! JSONSerialization.data(withJSONObject: body))
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return ((resp as? HTTPURLResponse)?.statusCode ?? 0) == 200
        } catch { return false }
    }

    private func request(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        if let b = body { req.httpBody = b; req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return req
    }

    private func sanitize(_ s: String) -> String {
        s.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|")).joined(separator: "_")
    }
}
