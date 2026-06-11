//
//  GitHubService.swift
//  MyBlogApp
//

import Combine
import Foundation
import UIKit

@MainActor
final class GitHubService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var aboutPage: BlogPage?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repo = "laurentdiao.github.io"
    private let owner = "Laurentdiao"
    private let baseURL = "https://api.github.com"
    private let tokenAccount = "github_token"

    var token: String {
        get {
            let keychainToken = KeychainStore.readToken(account: tokenAccount)
            if !keychainToken.isEmpty { return keychainToken }
            return UserDefaults.standard.string(forKey: tokenAccount) ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.removeObject(forKey: tokenAccount)
            if trimmed.isEmpty {
                KeychainStore.deleteToken(account: tokenAccount)
            } else {
                KeychainStore.saveToken(trimmed, account: tokenAccount)
            }
        }
    }

    var isConfigured: Bool { !token.isEmpty }

    var publicURL: URL {
        URL(string: "https://laurentdiao.github.io")!
    }

    // MARK: - Posts

    func fetchPosts() async {
        guard isConfigured else { return }
        isLoading = true
        errorMessage = nil

        do {
            let files: [GitHubFile] = try await getJSON(path: "source/_posts")
            var loaded: [Post] = []

            for file in files where file.name.hasSuffix(".md") {
                let info: FullGitHubFile = try await getJSON(path: file.path)
                guard let decoded = info.decodedContent,
                      let post = Post.from(githubFile: file, content: decoded) else {
                    continue
                }
                loaded.append(post)
            }

            posts = loaded.sorted { $0.date > $1.date }
        } catch {
            errorMessage = message(for: error)
        }

        isLoading = false
    }

    func createPost(title: String, content: String, tags: [String], categories: [String]) async -> Bool {
        let post = Post(title: title, date: "", tags: tags, categories: categories, content: content, filename: "", sha: nil)
        let filename = sanitize(title) + ".md"
        return await saveFile(path: "source/_posts/\(filename)", content: post.toMarkdown(), sha: nil, message: "Add \(title)")
    }

    func updatePost(_ post: Post, title: String, content: String, tags: [String], categories: [String]) async -> Bool {
        var updated = post
        updated.title = title
        updated.content = content
        updated.tags = tags
        updated.categories = categories

        let oldPath = "source/_posts/\(post.filename)"
        let newFilename = sanitize(title) + ".md"
        let newPath = "source/_posts/\(newFilename)"

        if newFilename != post.filename {
            guard let sha = post.sha, await deleteFile(path: oldPath, sha: sha, message: "Rename \(post.title)") else {
                return false
            }
            return await saveFile(path: newPath, content: updated.toMarkdown(), sha: nil, message: "Update \(title)")
        }

        return await saveFile(path: oldPath, content: updated.toMarkdown(), sha: post.sha, message: "Update \(title)")
    }

    func deletePost(_ post: Post) async -> Bool {
        guard let sha = post.sha else {
            errorMessage = "缺少文件 sha，刷新后再试。"
            return false
        }
        return await deleteFile(path: "source/_posts/\(post.filename)", sha: sha, message: "Delete \(post.title)")
    }

    // MARK: - About

    func fetchAboutPage() async -> BlogPage? {
        guard isConfigured else { return nil }
        isLoading = true
        errorMessage = nil

        do {
            let file: FullGitHubFile = try await getJSON(path: "source/about/index.md")
            let page = BlogPage.about(from: file)
            aboutPage = page
            isLoading = false
            return page
        } catch {
            errorMessage = message(for: error)
            isLoading = false
            return nil
        }
    }

    func updateAboutPage(_ page: BlogPage, title: String, content: String) async -> Bool {
        var updated = page
        updated.title = title
        updated.content = content

        return await saveFile(
            path: updated.path,
            content: updated.toMarkdown(),
            sha: updated.sha,
            message: "Update About Me"
        )
    }

    // MARK: - Image Upload

    func uploadImage(_ image: UIImage) async -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            errorMessage = "图片压缩失败。"
            return nil
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "img_\(timestamp).jpg"
        let path = "source/images/\(filename)"

        let ok = await saveFile(path: path, contentBase64: data.base64EncodedString(), sha: nil, message: "Upload image")
        return ok ? "/images/\(filename)" : nil
    }

    // MARK: - Private

    private func saveFile(path: String, content: String, sha: String?, message commitMessage: String) async -> Bool {
        await saveFile(path: path, contentBase64: Data(content.utf8).base64EncodedString(), sha: sha, message: commitMessage)
    }

    private func saveFile(path: String, contentBase64: String, sha: String?, message commitMessage: String) async -> Bool {
        var body: [String: Any] = [
            "message": commitMessage,
            "content": contentBase64,
            "branch": "main"
        ]
        if let sha { body["sha"] = sha }

        do {
            let _: EmptyResponse = try await sendJSON(path: path, method: "PUT", body: body, expected: [200, 201])
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    private func deleteFile(path: String, sha: String, message commitMessage: String) async -> Bool {
        let body: [String: Any] = [
            "message": commitMessage,
            "sha": sha,
            "branch": "main"
        ]

        do {
            let _: EmptyResponse = try await sendJSON(path: path, method: "DELETE", body: body, expected: [200])
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    private func getJSON<T: Decodable>(path: String) async throws -> T {
        let url = contentsURL(path: path)
        let (data, response) = try await URLSession.shared.data(for: request(url: url))
        try validate(response: response, data: data, expected: [200])
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func sendJSON<T: Decodable>(path: String, method: String, body: [String: Any], expected: Set<Int>) async throws -> T {
        let data = try JSONSerialization.data(withJSONObject: body)
        let (responseData, response) = try await URLSession.shared.data(for: request(url: contentsURL(path: path), method: method, body: data))
        try validate(response: response, data: responseData, expected: expected)

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try JSONDecoder().decode(T.self, from: responseData)
    }

    private func contentsURL(path: String) -> URL {
        let encodedPath = path.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }.joined(separator: "/")
        return URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(encodedPath)")!
    }

    private func request(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func validate(response: URLResponse, data: Data, expected: Set<Int>) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GitHubServiceError.requestFailed("无效的网络响应。")
        }

        guard expected.contains(http.statusCode) else {
            let apiError = try? JSONDecoder().decode(GitHubAPIError.self, from: data)
            let detail = apiError?.message ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw GitHubServiceError.requestFailed("GitHub 返回 \(http.statusCode)：\(detail)")
        }
    }

    private func message(for error: Error) -> String {
        if let error = error as? GitHubServiceError {
            return error.localizedDescription
        }
        return error.localizedDescription
    }

    private func sanitize(_ value: String) -> String {
        let cleaned = value
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "untitled-\(Int(Date().timeIntervalSince1970))" : cleaned
    }
}

private struct GitHubAPIError: Decodable {
    let message: String
}

private struct EmptyResponse: Decodable {}

private enum GitHubServiceError: LocalizedError {
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let message): return message
        }
    }
}
