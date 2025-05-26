//
//  yourworldaiApp.swift
//  yourworldai
//
//  Created by 柴田紘希 on 2025/04/12.
//

import SwiftUI

@main
struct yourworldaiApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                // 最初のタブ: 画像評価
                ContentView()
                    .tabItem {
                        Label("評価", systemImage: "rectangle.stack")
                    }

                // ２番目のタブ: 直接生成
                DirectGenerationView()
                    .tabItem {
                        Label("直接生成", systemImage: "wand.and.stars")
                    }

                // --- 追加: ３番目のタブ: キャラ作成 ---
                CharacterCreationView()
                    .tabItem {
                        Label("キャラ作成", systemImage: "person.crop.rectangle.stack")
                    }
                // --- ここまで追加 ---
            }
        }
    }
}
