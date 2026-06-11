//  BlogAppApp.swift
//  BlogApp - Winnie's Blog Manager
//
//  使用方法:
//  1. Xcode → File → New → Project → iOS → App
//  2. 项目名: BlogApp, Interface: SwiftUI
//  3. 把 BlogApp/ 里所有 .swift 文件拖入项目
//  4. 运行前在 App 设置页输入 GitHub Token

import SwiftUI

@main
struct BlogAppApp: App {
    @StateObject private var service = GitHubService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(service)
        }
    }
}
