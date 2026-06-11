//
//  Post.swift
//  MyBlogApp
//

import Foundation

struct Post: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var date: String
    var tags: [String]
    var categories: [String]
    var content: String
    var filename: String
    var sha: String?

    static func from(githubFile: GitHubFile, content: String) -> Post? {
        let parsed = MarkdownDocument.parse(content)
        guard let title = parsed.frontMatter["title"], !title.isEmpty else { return nil }

        return Post(
            title: title,
            date: parsed.frontMatter["date"] ?? "",
            tags: parsed.listValue(for: "tags"),
            categories: parsed.listValue(for: "categories"),
            content: parsed.body,
            filename: githubFile.name,
            sha: githubFile.sha
        )
    }

    func toMarkdown() -> String {
        var lines = ["---", "title: \(title)"]
        lines.append("date: \(date.isEmpty ? Date.blogTimestamp() : date)")

        if !tags.isEmpty {
            lines.append("tags:")
            lines.append(contentsOf: tags.map { "  - \($0)" })
        }

        if !categories.isEmpty {
            lines.append("categories:")
            lines.append(contentsOf: categories.map { "  - \($0)" })
        }

        lines.append("---")
        lines.append("")
        lines.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
        lines.append("")
        return lines.joined(separator: "\n")
    }
}

struct BlogPage: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var date: String
    var type: String
    var content: String
    var path: String
    var sha: String?

    static func about(from file: FullGitHubFile) -> BlogPage? {
        guard let decoded = file.decodedContent else { return nil }
        let parsed = MarkdownDocument.parse(decoded)

        return BlogPage(
            title: parsed.frontMatter["title"] ?? "关于",
            date: parsed.frontMatter["date"] ?? Date.blogTimestamp(),
            type: parsed.frontMatter["type"] ?? "about",
            content: parsed.body,
            path: "source/about/index.md",
            sha: file.sha
        )
    }

    func toMarkdown() -> String {
        [
            "---",
            "title: \(title)",
            "date: \(date)",
            "type: \(type)",
            "---",
            "",
            content.trimmingCharacters(in: .whitespacesAndNewlines),
            ""
        ].joined(separator: "\n")
    }
}

struct MarkdownDocument {
    var frontMatter: [String: String]
    var lists: [String: [String]]
    var body: String

    static func parse(_ markdown: String) -> MarkdownDocument {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else {
            return MarkdownDocument(frontMatter: [:], lists: [:], body: markdown.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let contentStart = normalized.index(normalized.startIndex, offsetBy: 4)
        guard let closingRange = normalized.range(of: "\n---", range: contentStart..<normalized.endIndex) else {
            return MarkdownDocument(frontMatter: [:], lists: [:], body: markdown.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let frontMatterText = String(normalized[contentStart..<closingRange.lowerBound])
        var bodyStart = closingRange.upperBound
        if bodyStart < normalized.endIndex, normalized[bodyStart] == "\n" {
            bodyStart = normalized.index(after: bodyStart)
        }
        let body = String(normalized[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)

        var values: [String: String] = [:]
        var lists: [String: [String]] = [:]
        var activeListKey: String?

        for rawLine in frontMatterText.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- "), let key = activeListKey {
                let value = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    lists[key, default: []].append(value)
                }
                continue
            }

            activeListKey = nil

            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)

            if rawValue.isEmpty {
                lists[key] = []
                activeListKey = key
            } else {
                values[key] = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }

        return MarkdownDocument(frontMatter: values, lists: lists, body: body)
    }

    func listValue(for key: String) -> [String] {
        lists[key] ?? frontMatter[key].map { [$0] } ?? []
    }
}

struct GitHubFile: Codable {
    let name: String
    let path: String
    let sha: String
    let type: String
}

struct FullGitHubFile: Codable {
    let content: String
    let sha: String

    var decodedContent: String? {
        let cleaned = content.replacingOccurrences(of: "\n", with: "")
        guard let data = Data(base64Encoded: cleaned) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension Date {
    static func blogTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: Date())
    }
}
