//
//  GeminiModels.swift
//  yourworldai
//
//  Created by [Your Name/AI] on [Date]
//

import Foundation

// --- Gemini API (generateContent) リクエスト用 ---
struct GeminiGenerateContentRequest: Codable {
    let contents: [Content]
    // let generationConfig: GenerationConfig? // 必要なら追加

    struct Content: Codable {
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String? // テキストプロンプト用
        let inlineData: InlineData? // 画像データ用

        // textパート用のイニシャライザ
        init(text: String) {
            self.text = text
            self.inlineData = nil
        }
        // 画像データパート用のイニシャライザ
        init(mimeType: String, data: String) { // dataはBase64エンコード文字列
            self.text = nil
            self.inlineData = InlineData(mimeType: mimeType, data: data)
        }
    }

    struct InlineData: Codable {
        let mimeType: String // 例: "image/jpeg", "image/png"
        let data: String // Base64エンコードされた画像データ
    }

    // struct GenerationConfig: Codable { ... } // 必要なら定義
}

// --- Gemini API (generateContent) レスポンス用 ---
struct GeminiGenerateContentResponse: Codable {
    let candidates: [Candidate]?
    let promptFeedback: PromptFeedback? // プロンプトに関するフィードバック
}

struct Candidate: Codable {
    let content: Content?
    let finishReason: String? // 例: "STOP", "MAX_TOKENS", "SAFETY"
    let index: Int?
    let safetyRatings: [SafetyRating]?
}

struct Content: Codable { // レスポンスのContent構造
    let parts: [Part]?
    let role: String? // 通常 "model"
}

struct Part: Codable { // レスポンスのPart構造
    let text: String?
    // 他のデータタイプ (例: functionCall) が返る可能性もある
}

struct SafetyRating: Codable {
    let category: String // 例: "HARM_CATEGORY_SEXUALLY_EXPLICIT"
    let probability: String // 例: "NEGLIGIBLE", "LOW", "MEDIUM", "HIGH"
}

struct PromptFeedback: Codable {
    let safetyRatings: [SafetyRating]?
    // 他のフィードバック情報 (例: blockReason)
}

// エラーレスポンス用 (簡易版)
struct GeminiErrorResponse: Codable, LocalizedError {
    let error: GeminiErrorDetail?
    var errorDescription: String? {
        return error?.message ?? "Unknown Gemini API error"
    }
}

struct GeminiErrorDetail: Codable {
    let code: Int?
    let message: String?
    let status: String?
}

// プロンプト生成のレスポンス用
struct GeneratedPromptResponse: Codable {
    let generated_prompt: String?
    let reason: String?
}


