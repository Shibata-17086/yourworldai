//
//  VertexAIService.swift
//  yourworldai
//
//  Created by AI Assistant on 2025/05/24
//

import Foundation
import UIKit

// MARK: - VertexAI Imagen 3 生成サービス
@MainActor
class VertexAIService: ObservableObject {
    
    // MARK: - Gemini Text Generation via Vertex AI
    func generateTextWithGemini(prompt: String) async throws -> String {
        print("🤖 Vertex AI経由でGemini呼び出し開始...")
        print("📍 プロジェクトID: \(GoogleCloudConfig.projectId)")
        print("🌍 リージョン: \(GoogleCloudConfig.location)")
        
        // 基本設定確認
        guard !GoogleCloudConfig.projectId.isEmpty,
              GoogleCloudConfig.projectId != "YOUR_PROJECT_ID",
              !GoogleCloudConfig.location.isEmpty else {
            print("⚠️ Vertex AI設定が不完全です")
            throw VertexAIGenerationError.invalidConfiguration
        }
        
        // APIキー確認
        if GoogleCloudConfig.vertexApiKey.isEmpty || 
           GoogleCloudConfig.vertexApiKey == "YOUR_VERTEX_API_KEY" {
            print("⚠️ Vertex AIアクセストークンが設定されていません")
            throw VertexAIGenerationError.invalidConfiguration
        }
        
        // Gemini用のリクエストペイロード作成
        let request = VertexAIGeminiRequest(
            contents: [
                VertexAIGeminiRequest.Content(
                    parts: [
                        VertexAIGeminiRequest.Part(text: prompt)
                    ]
                )
            ],
            generationConfig: VertexAIGeminiRequest.GenerationConfig(
                temperature: 0.8,
                topP: 0.95,
                topK: 40,
                maxOutputTokens: 2048
            )
        )
        
        // API呼び出し
        let response = try await callVertexAIGeminiAPI(with: request)
        
        // テキスト取得
        guard let candidate = response.candidates?.first,
              let content = candidate.content,
              let part = content.parts?.first,
              let text = part.text else {
            throw VertexAIGenerationError.noTextGenerated
        }
        
        print("✅ Vertex AI経由でGeminiテキスト生成成功！")
        return text
    }
    
    // MARK: - Private Methods for Gemini
    
    private func callVertexAIGeminiAPI(with request: VertexAIGeminiRequest) async throws -> VertexAIGeminiResponse {
        
        // Gemini用エンドポイントURL構築
        let modelName = "gemini-2.0-flash-lite-001" // 最新のGeminiモデル
        let urlString = "https://\(GoogleCloudConfig.location)-aiplatform.googleapis.com/v1/projects/\(GoogleCloudConfig.projectId)/locations/\(GoogleCloudConfig.location)/publishers/google/models/\(modelName):generateContent"
        
        guard let url = URL(string: urlString) else {
            throw VertexAIGenerationError.invalidURL
        }
        
        print("🔄 Vertex AI Gemini API呼び出し中...")
        print("📍 エンドポイント: \(urlString)")
        
        // HTTPリクエスト設定
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30.0
        
        // 認証設定
        do {
            let accessToken = try await VertexAIAuth.getAccessToken()
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } catch {
            print("⚠️ アクセストークン取得失敗: \(error)")
            urlRequest.setValue("Bearer \(GoogleCloudConfig.vertexApiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // リクエストボディ設定
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            // デバッグ用：リクエスト内容を出力
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 リクエストJSON: \(jsonString.prefix(500))...")
            }
        } catch {
            throw VertexAIGenerationError.encodingError(error.localizedDescription)
        }
        
        // API呼び出し実行
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw VertexAIGenerationError.invalidResponse
            }
            
            print("📊 HTTPステータス: \(httpResponse.statusCode)")
            
            // レスポンス内容をデバッグ出力
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 レスポンス内容: \(responseString.prefix(500))...")
            }
            
            // エラーレスポンス処理
            if httpResponse.statusCode != 200 {
                let errorString = String(data: data, encoding: .utf8) ?? "不明なエラー"
                print("❌ API エラーレスポンス: \(errorString)")
                
                if let errorResponse = try? JSONDecoder().decode(VertexAIError.self, from: data) {
                    throw VertexAIGenerationError.apiError(errorResponse)
                } else {
                    throw VertexAIGenerationError.httpError(httpResponse.statusCode, errorString)
                }
            }
            
            // 成功レスポンス処理
            do {
                let geminiResponse = try JSONDecoder().decode(VertexAIGeminiResponse.self, from: data)
                return geminiResponse
            } catch {
                print("❌ JSONデコードエラー: \(error)")
                throw VertexAIGenerationError.decodingError(error.localizedDescription)
            }
            
        } catch let error as VertexAIGenerationError {
            throw error
        } catch {
            throw VertexAIGenerationError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Imagen 3画像生成
    func generateImage(
        prompt: String,
        aspectRatio: Imagen3AspectRatio = .square,
        outputFormat: Imagen3OutputFormat = .png,
        negativePrompt: String? = nil
    ) async throws -> UIImage {
        
        // 🚨 発表会緊急対策: Vertex AI設定を簡素化
        print("🔄 Vertex AI Imagen 3 生成開始...")
        print("📍 プロジェクトID: \(GoogleCloudConfig.projectId)")
        print("🌍 リージョン: \(GoogleCloudConfig.location)")
        
        // 基本設定確認（発表会用に簡略化）
        guard !GoogleCloudConfig.projectId.isEmpty,
              GoogleCloudConfig.projectId != "YOUR_PROJECT_ID",
              !GoogleCloudConfig.location.isEmpty else {
            print("⚠️ Vertex AI設定が不完全です")
            throw VertexAIGenerationError.invalidConfiguration
        }
        
        // APIキー確認（より柔軟に）
        if GoogleCloudConfig.vertexApiKey.isEmpty || 
           GoogleCloudConfig.vertexApiKey == "YOUR_VERTEX_API_KEY" {
            print("⚠️ Vertex AIアクセストークンが設定されていません")
            throw VertexAIGenerationError.invalidConfiguration
        }
        
        // リクエストペイロード作成
        let instance = VertexAIGenerateRequest.Instance(
            prompt: prompt,
            negativePrompt: negativePrompt,
            aspectRatio: aspectRatio.rawValue,
            outputFormat: outputFormat.rawValue,
            sampleCount: 1
        )
        
        let parameters = VertexAIGenerateRequest.Parameters(
            sampleCount: 1,
            outputImageType: outputFormat.rawValue,
            language: "auto"
        )
        
        let request = VertexAIGenerateRequest(
            instances: [instance],
            parameters: parameters
        )
        
        // API呼び出し
        let response = try await callVertexAIAPI(with: request)
        
        // 画像データ取得
        guard let prediction = response.predictions?.first,
              let base64Data = prediction.bytesBase64Encoded else {
            throw VertexAIGenerationError.noImageGenerated
        }
        
        // Base64データを画像に変換
        guard let imageData = Data(base64Encoded: base64Data),
              let image = UIImage(data: imageData) else {
            throw VertexAIGenerationError.imageConversionFailed
        }
        
        print("✅ Vertex AI Imagen 3で画像生成成功！")
        return image
    }
    
    // MARK: - Private Methods
    
    private func callVertexAIAPI(with request: VertexAIGenerateRequest) async throws -> VertexAIGenerateResponse {
        
        // エンドポイントURL構築
        let urlString = "\(GoogleCloudConfig.vertexAIEndpoint)\(GoogleCloudConfig.imagen3Model):predict"
        
        guard let url = URL(string: urlString) else {
            throw VertexAIGenerationError.invalidURL
        }
        
        print("🔄 Vertex AI Imagen 3 API呼び出し中...")
        print("📍 エンドポイント: \(urlString)")
        
        // HTTPリクエスト設定
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30.0 // 🔧 タイムアウト設定
        
        // 🚨 発表会緊急対策: 認証設定を簡素化
        do {
            let accessToken = try await VertexAIAuth.getAccessToken()
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } catch {
            print("⚠️ アクセストークン取得失敗: \(error)")
            // フォールバック: 設定ファイルのトークンを直接使用
            urlRequest.setValue("Bearer \(GoogleCloudConfig.vertexApiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // リクエストボディ設定
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw VertexAIGenerationError.encodingError(error.localizedDescription)
        }
        
        // API呼び出し実行
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw VertexAIGenerationError.invalidResponse
            }
            
            print("📊 HTTPステータス: \(httpResponse.statusCode)")
            
            // エラーレスポンス処理
            if httpResponse.statusCode != 200 {
                let errorString = String(data: data, encoding: .utf8) ?? "不明なエラー"
                print("❌ API エラーレスポンス: \(errorString)")
                
                if let errorResponse = try? JSONDecoder().decode(VertexAIError.self, from: data) {
                    throw VertexAIGenerationError.apiError(errorResponse)
                } else {
                    throw VertexAIGenerationError.httpError(httpResponse.statusCode, errorString)
                }
            }
            
            // 成功レスポンス処理
            do {
                let generateResponse = try JSONDecoder().decode(VertexAIGenerateResponse.self, from: data)
                return generateResponse
            } catch {
                throw VertexAIGenerationError.decodingError(error.localizedDescription)
            }
            
        } catch let error as VertexAIGenerationError {
            throw error
        } catch {
            throw VertexAIGenerationError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - エラー定義
enum VertexAIGenerationError: LocalizedError {
    case invalidConfiguration
    case invalidURL
    case encodingError(String)
    case networkError(String)
    case invalidResponse
    case httpError(Int, String)
    case apiError(VertexAIError)
    case decodingError(String)
    case noImageGenerated
    case imageConversionFailed
    case noTextGenerated
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Vertex AI APIの設定が正しくありません。プロジェクトIDとAPIキーを確認してください。"
        case .invalidURL:
            return "無効なAPI URLです。"
        case .encodingError(let message):
            return "リクエストエンコードエラー: \(message)"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .invalidResponse:
            return "無効なサーバーレスポンスです。"
        case .httpError(let code, let message):
            return "HTTP エラー (\(code)): \(message)"
        case .apiError(let vertexError):
            return vertexError.errorDescription ?? "Vertex AI APIエラー"
        case .decodingError(let message):
            return "レスポンス解析エラー: \(message)"
        case .noImageGenerated:
            return "画像が生成されませんでした。"
        case .imageConversionFailed:
            return "生成された画像データの変換に失敗しました。"
        case .noTextGenerated:
            return "テキストが生成されませんでした。"
        }
    }
} 