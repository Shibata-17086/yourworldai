//
//  VertexAIModels.swift
//  yourworldai
//
//  Created by AI Assistant on 2025/05/24
//

import Foundation

// MARK: - Vertex AI Imagen 3 API Models

// リクエスト用の構造体
struct VertexAIGenerateRequest: Codable {
    let instances: [Instance]
    let parameters: Parameters?
    
    struct Instance: Codable {
        let prompt: String
        let negativePrompt: String?
        let aspectRatio: String?
        let outputFormat: String?
        let sampleCount: Int?
        
        init(prompt: String, negativePrompt: String? = nil, aspectRatio: String = "1:1", outputFormat: String = "PNG", sampleCount: Int = 1) {
            self.prompt = prompt
            self.negativePrompt = negativePrompt
            self.aspectRatio = aspectRatio
            self.outputFormat = outputFormat
            self.sampleCount = sampleCount
        }
    }
    
    struct Parameters: Codable {
        let sampleCount: Int?
        let outputImageType: String?
        let language: String?
        
        init(sampleCount: Int = 1, outputImageType: String = "PNG", language: String = "auto") {
            self.sampleCount = sampleCount
            self.outputImageType = outputImageType
            self.language = language
        }
    }
}

// レスポンス用の構造体
struct VertexAIGenerateResponse: Codable {
    let predictions: [Prediction]?
    let deployedModelId: String?
    let model: String?
    let modelDisplayName: String?
    let modelVersionId: String?
    
    struct Prediction: Codable {
        let bytesBase64Encoded: String?
        let mimeType: String?
        let gcsUri: String?
    }
}

// エラーレスポンス用の構造体
struct VertexAIError: Codable, LocalizedError {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let code: Int
        let message: String
        let status: String
        let details: [ErrorDetailItem]?
    }
    
    struct ErrorDetailItem: Codable {
        let type: String?
        let reason: String?
        let domain: String?
        let metadata: [String: String]?
    }
    
    var errorDescription: String? {
        return "Vertex AI エラー (\(error.code)): \(error.message)"
    }
}

// MARK: - OAuth 2.0 トークンレスポンス
struct OAuth2TokenResponse: Codable {
    let access_token: String
    let expires_in: Int
    let token_type: String
}

// MARK: - Vertex AI API認証
struct VertexAIAuth {
    
    // OAuth 2.0アクセストークンエラー
    enum AuthError: LocalizedError {
        case invalidServiceAccount
        case authenticationFailed(String)
        case noAccessToken
        case networkError(String)
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .invalidServiceAccount:
                return "サービスアカウント設定が無効です。GoogleCloudConfigを確認してください。"
            case .authenticationFailed(let message):
                return "認証に失敗しました: \(message)"
            case .noAccessToken:
                return "アクセストークンを取得できませんでした。"
            case .networkError(let message):
                return "ネットワークエラー: \(message)"
            case .invalidResponse:
                return "認証サーバーからの無効なレスポンスです。"
            }
        }
    }
    
    // OAuth 2.0アクセストークンを取得（開発用：手動トークン使用）
    static func getAccessToken() async throws -> String {
        // 開発段階での簡易実装
        // 実際のプロダクションでは、以下のいずれかの方法を使用：
        // 1. Firebase Auth経由でGoogle OAuth 2.0を使用
        // 2. サービスアカウントキーを使用したJWT認証
        // 3. Google Cloud SDKを使用
        
        // 方法1: 手動で取得したアクセストークンを使用（開発/テスト用）
        if let manualToken = await getManualAccessToken() {
            return manualToken
        }
        
        // 方法2: サービスアカウントを使用（未実装）
        // return try await getAccessTokenFromServiceAccount()
        
        throw AuthError.noAccessToken
    }
    
    // 手動で取得したアクセストークンを使用（開発用）
    private static func getManualAccessToken() async -> String? {
        // ターミナルで以下を実行して取得したトークンを使用：
        // gcloud auth print-access-token
        
        // TODO: 実際のアクセストークンに置き換えてください
        // このトークンは通常1時間で期限切れになります
        let manualToken = "YOUR_MANUAL_ACCESS_TOKEN_HERE" // ← gcloudで取得したトークンをここに貼り付け
        
        if manualToken == "YOUR_MANUAL_ACCESS_TOKEN_HERE" || manualToken.isEmpty {
            print("⚠️ 手動アクセストークンが設定されていません")
            print("以下の手順でアクセストークンを取得してください：")
            print("1. ターミナルを開く")
            print("2. 'gcloud auth login' を実行")
            print("3. 'gcloud auth print-access-token' を実行")
            print("4. 出力されたトークンをこのコードに設定")
            return nil
        }
        
        print("✅ 手動設定されたアクセストークンを使用")
        return manualToken
    }
    
    // サービスアカウントキーを使用した認証（JWT + OAuth 2.0）
    static func getAccessTokenFromServiceAccount() async throws -> String {
        // サービスアカウントキーのパス
        guard let serviceAccountKeyPath = GoogleCloudConfig.serviceAccountKeyPath,
              !serviceAccountKeyPath.isEmpty else {
            throw AuthError.invalidServiceAccount
        }
        
        // JWT生成とOAuth 2.0トークン取得の実装
        // 注意: これは高度な実装が必要です
        // 実装には以下が含まれます：
        // 1. RSA秘密鍵による署名
        // 2. JWT の生成
        // 3. Google OAuth 2.0 エンドポイントへのリクエスト
        
        throw AuthError.authenticationFailed("サービスアカウント認証は現在未実装です。手動アクセストークンを使用してください。")
    }
}

// MARK: - Imagen 3生成設定

enum Imagen3AspectRatio: String, CaseIterable {
    case square = "1:1"
    case portrait = "3:4"
    case landscape = "4:3"
    case widePortrait = "9:16"
    case wideLandscape = "16:9"
    
    var displayName: String {
        switch self {
        case .square: return "正方形 (1:1)"
        case .portrait: return "縦長 (3:4)"
        case .landscape: return "横長 (4:3)"
        case .widePortrait: return "縦長ワイド (9:16)"
        case .wideLandscape: return "横長ワイド (16:9)"
        }
    }
}

enum Imagen3OutputFormat: String, CaseIterable {
    case png = "PNG"
    case jpeg = "JPEG"
    
    var displayName: String {
        switch self {
        case .png: return "PNG (高品質)"
        case .jpeg: return "JPEG (軽量)"
        }
    }
} 