//
//  GeminiAnalysisService.swift
//  yourworldai
//

import Foundation
import SwiftUI

// MARK: - 🚀 最適化されたGemini分析サービス
@MainActor
class GeminiAnalysisService: ObservableObject {
    
    // 🔧 API呼び出し制限とキャッシュ
    private var requestCount = 0
    private let maxRequestsPerMinute = 60
    private var lastRequestTime = Date()
    private var analysisCache: [Data: String] = [:]
    private let maxCacheSize = 50
    
    // MARK: - 🔧 レート制限付き画像分析
    func analyzeImage(imageData: Data) async -> String? {
        // キャッシュチェック
        if let cachedResult = analysisCache[imageData] {
            print("📦 キャッシュから分析結果を取得")
            return cachedResult
        }
        
        // レート制限チェック
        if !(await checkRateLimit()) {
            print("⚠️ レート制限に達しました")
            return nil
        }
        
        guard !GeminiConfig.apiKey.isEmpty, 
              GeminiConfig.apiKey != "YOUR_GEMINI_API_KEY" else {
            print("❌ Gemini APIキーが設定されていません")
            return nil
        }
        
        // 🔧 画像サイズ最適化
        let optimizedImageData = optimizeImageForAPI(imageData)
        
        guard let base64Image = optimizedImageData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ 画像のBase64エンコードに失敗")
            return nil
        }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(GeminiConfig.visionModel):generateContent?key=\(GeminiConfig.apiKey)"
        guard let url = URL(string: urlString) else {
            print("❌ 無効なURL: \(urlString)")
            return nil
        }
        
        // 🚀 軽量化されたプロンプト
        let requestPayload = GeminiGenerateContentRequest(
            contents: [
                .init(parts: [
                    .init(text: "この画像の主要な視覚的特徴を50文字以内で簡潔に説明してください。"),
                    .init(mimeType: "image/jpeg", data: base64Image)
                ])
            ]
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0 // タイムアウト設定
        
        do {
            request.httpBody = try JSONEncoder().encode(requestPayload)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 無効なレスポンス")
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Gemini API エラー - Status: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("エラー詳細: \(errorString)")
                }
                return nil
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
            
            if let result = geminiResponse.candidates?.first?.content?.parts?.first?.text {
                // キャッシュに保存
                updateCache(imageData: imageData, result: result)
                return result
            }
            
            return nil
            
        } catch {
            print("❌ Gemini API 呼び出しエラー: \(error)")
            return nil
        }
    }
    
    // MARK: - 🔧 軽量化されたスワイプ後評価分析
    func evaluateSwipedImage(imageData: Data, swipeDirection: SwipeDirection) async -> ImageEvaluationResult? {
        // レート制限チェック
        if !(await checkRateLimit()) {
            print("⚠️ 評価分析: レート制限に達しました")
            return createFallbackEvaluation(direction: swipeDirection)
        }
        
        guard !GeminiConfig.apiKey.isEmpty, 
              GeminiConfig.apiKey != "YOUR_GEMINI_API_KEY" else {
            print("❌ Gemini APIキーが設定されていません")
            return createFallbackEvaluation(direction: swipeDirection)
        }
        
        // 🔧 画像サイズ最適化
        let optimizedImageData = optimizeImageForAPI(imageData)
        
        guard let base64Image = optimizedImageData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ 画像のBase64エンコードに失敗")
            return createFallbackEvaluation(direction: swipeDirection)
        }
        
        let directionText = swipeDirection == .like ? "好き" : "嫌い"
        
        // 🚀 軽量化されたプロンプト（短縮版）
        let analysisPrompt = """
        ユーザーがこの画像を「\(directionText)」と評価しました。
        
        100文字以内で以下を分析してください：
        - なぜ\(directionText)と感じた可能性があるか
        - 主要な視覚的特徴
        - 学習ポイント
        
        簡潔に日本語で回答してください。
        """
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(GeminiConfig.visionModel):generateContent?key=\(GeminiConfig.apiKey)"
        guard let url = URL(string: urlString) else {
            print("❌ 無効なURL: \(urlString)")
            return createFallbackEvaluation(direction: swipeDirection)
        }
        
        let requestPayload = GeminiGenerateContentRequest(
            contents: [
                .init(parts: [
                    .init(text: analysisPrompt),
                    .init(mimeType: "image/jpeg", data: base64Image)
                ])
            ]
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0 // 短縮されたタイムアウト
        
        do {
            request.httpBody = try JSONEncoder().encode(requestPayload)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 無効なレスポンス")
                return createFallbackEvaluation(direction: swipeDirection)
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Gemini API エラー - Status: \(httpResponse.statusCode)")
                return createFallbackEvaluation(direction: swipeDirection)
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
            
            if let analysisText = geminiResponse.candidates?.first?.content?.parts?.first?.text {
                return ImageEvaluationResult(
                    swipeDirection: swipeDirection,
                    analysisText: analysisText,
                    timestamp: Date()
                )
            }
            
            return createFallbackEvaluation(direction: swipeDirection)
            
        } catch {
            print("❌ Gemini API 呼び出しエラー: \(error)")
            return createFallbackEvaluation(direction: swipeDirection)
        }
    }
    
    // MARK: - 🚀 高速化された並列分析（制限付き）
    func analyzeImages(_ imageDatas: [Data]) async -> [String?] {
        // 並列処理数を制限
        let maxConcurrentRequests = 3
        let chunks = imageDatas.chunked(into: maxConcurrentRequests)
        var allResults: [String?] = []
        
        for chunk in chunks {
            let chunkResults = await withTaskGroup(of: (Int, String?).self, returning: [String?].self) { group in
                var results: [String?] = Array(repeating: nil, count: chunk.count)
                
                for (localIndex, imageData) in chunk.enumerated() {
                    group.addTask { [weak self] in
                        let description = await self?.analyzeImage(imageData: imageData)
                        return (localIndex, description)
                    }
                }
                
                for await (localIndex, description) in group {
                    results[localIndex] = description
                }
                
                return results
            }
            
            allResults.append(contentsOf: chunkResults)
            
            // チャンク間で少し待機
            if chunks.count > 1 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            }
        }
        
        return allResults
    }
    
    // MARK: - 🧠 学習結果分析機能
    func analyzeUserPreferences(from evaluationResults: [ImageEvaluationResult]) async throws -> UserPreferenceAnalysis {
        guard !evaluationResults.isEmpty else {
            throw NSError(domain: "GeminiAnalysisService", code: 1, userInfo: [NSLocalizedDescriptionKey: "評価結果が空です"])
        }
        
        let likedEvaluations = evaluationResults.filter { $0.swipeDirection == .like }
        let dislikedEvaluations = evaluationResults.filter { $0.swipeDirection == .unlike }
        
        let analysisPrompt = """
        以下のユーザーの画像評価データを分析して、好みのパターンを特定してください：

        好評価された画像の分析結果:
        \(likedEvaluations.map { "- \($0.analysisText)" }.joined(separator: "\n"))

        低評価された画像の分析結果:
        \(dislikedEvaluations.map { "- \($0.analysisText)" }.joined(separator: "\n"))

        以下の形式で分析結果を提供してください：
        1. 好みの特徴パターン（色彩、構図、スタイル、テーマなど）
        2. 避ける傾向のある要素
        3. 今後の画像生成に対する具体的な推奨事項
        4. ユーザーの美的嗜好の特徴

        詳細で実用的な分析を提供してください。
        """
        
        let response = try await sendAnalysisRequest(prompt: analysisPrompt)
        
        return UserPreferenceAnalysis(
            preferredFeatures: extractPreferredFeatures(from: response),
            avoidedElements: extractAvoidedElements(from: response),
            recommendations: extractRecommendations(from: response),
            aestheticProfile: response,
            analysisDate: Date(),
            totalEvaluations: evaluationResults.count,
            likeCount: likedEvaluations.count
        )
    }
    
    // 画像生成プロンプト最適化
    func optimizePromptBasedOnPreferences(basePrompt: String, preferences: UserPreferenceAnalysis) async throws -> String {
        let optimizationPrompt = """
        ユーザーの好みの分析結果に基づいて、以下の画像生成プロンプトを最適化してください：

        元のプロンプト: "\(basePrompt)"

        ユーザーの好みの特徴:
        \(preferences.preferredFeatures.joined(separator: ", "))

        避けるべき要素:
        \(preferences.avoidedElements.joined(separator: ", "))

        推奨事項:
        \(preferences.recommendations.joined(separator: ", "))

        元のプロンプトの意図を保ちながら、ユーザーの好みに合わせて最適化された新しいプロンプトを提供してください。
        """
        
        return try await sendAnalysisRequest(prompt: optimizationPrompt)
    }
    
    // 共通のリクエスト送信メソッド
    private func sendAnalysisRequest(prompt: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(GeminiConfig.apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GeminiGenerateContentRequest(
            contents: [
                GeminiGenerateContentRequest.Content(
                    parts: [GeminiGenerateContentRequest.Part(text: prompt)]
                )
            ]
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "GeminiAnalysisService", code: 2, userInfo: [NSLocalizedDescriptionKey: "API リクエストに失敗しました"])
        }
        
        let decoder = JSONDecoder()
        let geminiResponse = try decoder.decode(GeminiGenerateContentResponse.self, from: data)
        
        return geminiResponse.candidates?.first?.content?.parts?.first?.text ?? "分析結果を取得できませんでした"
    }
    
    // MARK: - 🔧 Private Helper Methods
    
    private func checkRateLimit() async -> Bool {
        let now = Date()
        let timeDifference = now.timeIntervalSince(lastRequestTime)
        
        // 1分経過したらカウンタリセット
        if timeDifference >= 60 {
            requestCount = 0
            lastRequestTime = now
        }
        
        if requestCount >= maxRequestsPerMinute {
            // レート制限に達した場合、次の分まで待機
            let waitTime = 60 - timeDifference
            if waitTime > 0 {
                print("⏳ レート制限: \(Int(waitTime))秒待機中...")
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                requestCount = 0
                lastRequestTime = Date()
            }
        }
        
        requestCount += 1
        return true
    }
    
    private func optimizeImageForAPI(_ imageData: Data) -> Data {
        guard let image = UIImage(data: imageData) else { return imageData }
        
        // 🔧 API用に画像サイズを最適化（768px制限）
        let maxSize: CGFloat = 768
        
        if image.size.width <= maxSize && image.size.height <= maxSize {
            return imageData
        }
        
        let scale = min(maxSize / image.size.width, maxSize / image.size.height)
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let optimizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // 🔧 JPEG圧縮でファイルサイズ削減
        return optimizedImage.jpegData(compressionQuality: 0.7) ?? imageData
    }
    
    private func updateCache(imageData: Data, result: String) {
        analysisCache[imageData] = result
        
        // キャッシュサイズ制限
        if analysisCache.count > maxCacheSize {
            let oldestKey = analysisCache.keys.first
            if let key = oldestKey {
                analysisCache.removeValue(forKey: key)
            }
        }
    }
    
    private func createFallbackEvaluation(direction: SwipeDirection) -> ImageEvaluationResult {
        let directionText = direction == .like ? "好き" : "嫌い"
        return ImageEvaluationResult(
            swipeDirection: direction,
            analysisText: "この画像を\(directionText)と評価しました。詳細な分析は現在利用できませんが、この評価は学習に反映されます。",
            timestamp: Date()
        )
    }
    
    // ヘルパーメソッド
    private func extractPreferredFeatures(from analysis: String) -> [String] {
        // シンプルな特徴抽出 - 実際の実装では自然言語処理を使用
        let features = analysis.components(separatedBy: "好みの特徴パターン")
            .dropFirst()
            .first?
            .components(separatedBy: "避ける傾向")
            .first?
            .components(separatedBy: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.hasPrefix("-") || trimmed.hasPrefix("•") ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : nil
            } ?? []
        
        return Array(features.prefix(5)) // 上位5つの特徴
    }
    
    private func extractAvoidedElements(from analysis: String) -> [String] {
        let elements = analysis.components(separatedBy: "避ける傾向")
            .dropFirst()
            .first?
            .components(separatedBy: "推奨事項")
            .first?
            .components(separatedBy: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.hasPrefix("-") || trimmed.hasPrefix("•") ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : nil
            } ?? []
        
        return Array(elements.prefix(5))
    }
    
    private func extractRecommendations(from analysis: String) -> [String] {
        let recommendations = analysis.components(separatedBy: "推奨事項")
            .dropFirst()
            .first?
            .components(separatedBy: "美的嗜好")
            .first?
            .components(separatedBy: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.hasPrefix("-") || trimmed.hasPrefix("•") ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : nil
            } ?? []
        
        return Array(recommendations.prefix(5))
    }
}

// MARK: - 🔧 配列拡張（チャンク分割用）
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - 画像評価結果モデル
struct ImageEvaluationResult: Identifiable {
    let id = UUID()
    let swipeDirection: SwipeDirection
    let analysisText: String
    let timestamp: Date
    
    var directionIcon: String {
        swipeDirection == .like ? "heart.fill" : "xmark.circle.fill"
    }
    
    var directionColor: Color {
        swipeDirection == .like ? .green : .red
    }
    
    var directionText: String {
        swipeDirection == .like ? "好き" : "嫌い"
    }
}

// MARK: - 🎯 ユーザー好み分析結果
struct UserPreferenceAnalysis {
    let preferredFeatures: [String]      // 好みの特徴
    let avoidedElements: [String]        // 避ける要素
    let recommendations: [String]        // 推奨事項
    let aestheticProfile: String         // 美的プロファイル
    let analysisDate: Date              // 分析日時
    let totalEvaluations: Int           // 総評価数
    let likeCount: Int                  // 好評価数
    
    var likeRate: Double {
        totalEvaluations > 0 ? Double(likeCount) / Double(totalEvaluations) * 100 : 0
    }
} 
