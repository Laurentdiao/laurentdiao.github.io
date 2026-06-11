//  Post.swift
//  文章数据模型

import Foundation

struct Post: Identifiable, Codable {
    let id = UUID()

    let title: String
    let date: String
    var tags: [String]
    var categories: [String]
    var content: String
    let filename: String
    var sha: String?

    // 从 GitHub API 返回的 content 字段中解析
    static func from(githubFile: GitHubFile, content: String) -> Post? {
        let parts = content.split(separator: "---", maxSplits: 2)
        guard parts.count >= 2 else { return nil }

        let frontMatter = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let body = parts.count >= 3 ? String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines) : ""

        var title = ""
        var date = ""
        var tags: [String] = []
        var categories: [String] = []

        for line in frontMatter.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("title:") {
                title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("date:") {
                date = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if trimmed == "tags:" {
                // handled below
            } else if trimmed.hasPrefix("- ") && !trimmed.hasPrefix("- ") {
                continue
            }
        }

        // 解析数组型 front matter
        var inTags = false
        var inCategories = false

        for line in frontMatter.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "tags:" {
                inTags = true; inCategories = false; continue
            } else if trimmed == "categories:" {
                inCategories = true; inTags = false; continue
            } else if trimmed.hasPrefix("title:") || trimmed.hasPrefix("date:") {
                inTags = false; inCategories = false; continue
            }

            if inTags && trimmed.hasPrefix("- ") {
                let tag = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !tag.isEmpty { tags.append(tag) }
            } else if inCategories && trimmed.hasPrefix("- ") {
                let cat = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !cat.isEmpty { categories.append(cat) }
            } else if trimmed.hasPrefix("-") {
                continue
            } else if !trimmed.isEmpty {
                inTags = false; inCategories = false
            }
        }

        guard !title.isEmpty else { return nil }

        return Post(
            title: title,
            date: date,
            tags: tags,
            categories: categories,
            content: body,
            filename: githubFile.name,
            sha: githubFile.sha
        )
    }

    // 生成 .md 文件内容
    func toMarkdown() -> String {
        var md = "---\n"
        md += "title: \(title)\n"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        md += "date: \(date.isEmpty ? df.string(from: Date()) : date)\n"

        if !tags.isEmpty {
            md += "tags:\n"
            for tag in tags { md += "  - \(tag)\n" }
        }

        if !categories.isEmpty {
            md += "categories:\n"
            for cat in categories { md += "  - \(cat)\n" }
        }

        md += "---\n\n\(content)\n"
        return md
    }
}

struct GitHubFile: Codable {
    let name: String
    let path: String
    let sha: String
    let type: String
}
