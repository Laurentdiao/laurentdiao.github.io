//
//  Post.swift
//  文章数据模型 + Markdown 解析

import Foundation

struct Post: Identifiable, Codable, Equatable {
    let id = UUID()
    var title: String
    var date: String
    var tags: [String]
    var categories: [String]
    var content: String
    var filename: String
    var sha: String?

    static func from(githubFile: GitHubFile, content: String) -> Post? {
        let parts = content.split(separator: "---", maxSplits: 2)
        guard parts.count >= 2 else { return nil }
        let fm = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let body = parts.count >= 3 ? String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines) : ""

        var title = "", date = ""
        var tags: [String] = [], categories: [String] = []
        var inTags = false, inCategories = false

        for line in fm.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("title:") { title = String(t.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
            else if t.hasPrefix("date:") { date = String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
            else if t == "tags:" { inTags = true; inCategories = false }
            else if t == "categories:" { inCategories = true; inTags = false }
            else if t.hasPrefix("title:") || t.hasPrefix("date:") { inTags = false; inCategories = false }
            else if inTags && t.hasPrefix("- ") {
                let v = String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { tags.append(v) }
            } else if inCategories && t.hasPrefix("- ") {
                let v = String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { categories.append(v) }
            } else if t.hasPrefix("-") { continue }
            else if !t.isEmpty { inTags = false; inCategories = false }
        }

        guard !title.isEmpty else { return nil }
        return Post(title: title, date: date, tags: tags, categories: categories, content: body, filename: githubFile.name, sha: githubFile.sha)
    }

    func toMarkdown() -> String {
        var md = "---\ntitle: \(title)\n"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        md += "date: \(date.isEmpty ? df.string(from: Date()) : date)\n"
        if !tags.isEmpty { md += "tags:\n"; for t in tags { md += "  - \(t)\n" } }
        if !categories.isEmpty { md += "categories:\n"; for c in categories { md += "  - \(c)\n" } }
        md += "---\n\n\(content)\n"
        return md
    }
}

struct GitHubFile: Codable {
    let name: String; let path: String; let sha: String; let type: String
}

struct FullGitHubFile: Codable {
    let content: String; let sha: String
}
