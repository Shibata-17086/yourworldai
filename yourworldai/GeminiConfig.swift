//
//  GeminiConfig.swift
//  yourworldai
//
//  Created by [Your Name/AI] on [Date]
//

import Foundation

struct GeminiConfig {

    // !!! 重要: APIキーの安全な管理について !!!
    // テスト目的のみ。安全な管理方法を検討してください。
    static let apiKey = "AIzaSyBSCRDhqDmLx9LsTysbb7jF9TiPDY4xy-g" // ← あなたのGemini APIキー (テスト用、要安全管理！)

    // --- 修正箇所 ---
    // 使用するGeminiモデル (画像入力対応モデル) を gemini-1.5-flash に変更
    // "latest" をつけるのが推奨される場合があります
    static let visionModel = "gemini-1.5-flash-latest"
    // または単に "gemini-1.5-flash" でも動作する場合があります
    // static let visionModel = "gemini-1.5-flash"
    // --- ここまで修正箇所 ---
}
