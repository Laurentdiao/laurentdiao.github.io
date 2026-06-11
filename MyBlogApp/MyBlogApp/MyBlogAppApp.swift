//
//  MyBlogAppApp.swift
//  MyBlogApp - Winnie's Blog Manager
//

import SwiftUI

@main
struct MyBlogAppApp: App {
    @StateObject private var service = GitHubService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(service)
        }
    }
}
