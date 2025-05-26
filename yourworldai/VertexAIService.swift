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
    
    // MARK: - Imagen 3画像生成
    func generateImage(
        prompt: String,
        aspectRatio: Imagen3AspectRatio = .square,
        outputFormat: Imagen3OutputFormat = .png,
        negativePrompt: String? = nil
    ) async throws -> UIImage {
        
        // APIキー設定確認
        guard !GoogleCloudConfig.vertexApiKey.isEmpty,
              GoogleCloudConfig.vertexApiKey != "AIzaSyA8JAE7rj-7YWN35umGlKjzDXoLYF9c07g",
              !GoogleCloudConfig.projectId.isEmpty,
              GoogleCloudConfig.projectId != "823889605645-otr7ql0d17em14ebce2g40uu2qvtvvtb.apps.googleusercontent.com" else {
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
        
        // 認証設定
        let accessToken = try await VertexAIAuth.getAccessToken()
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
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
                if let errorResponse = try? JSONDecoder().decode(VertexAIError.self, from: data) {
                    throw VertexAIGenerationError.apiError(errorResponse)
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "不明なエラー"
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
        }
    }
} 