//
//  ImageGenerationService.swift
//  yourworldai
//

import Foundation
import UIKit

// MARK: - エラー定義
enum ImageGenerationError: LocalizedError {
    case invalidAPIKey
    case noModelSelected
    case promptGenerationFailed
    case networkError(String)
    case decodingError(String)
    case timeoutError
    case apiError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "APIキーが設定されていません。"
        case .noModelSelected:
            return "生成モデルが選択されていません。"
        case .promptGenerationFailed:
            return "プロンプトの生成に失敗しました。"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .decodingError(let message):
            return "APIレスポンスの解析に失敗: \(message)"
        case .timeoutError:
            return "画像生成がタイムアウトしました。"
        case .apiError(let code, let message):
            return "API エラー (\(code)): \(message)"
        }
    }
}

// MARK: - 生成結果
struct GenerationResult {
    let image: UIImage
    let prompt: String
    let reason: String?
}

// MARK: - プロンプト生成結果
struct PromptGenerationResult {
    let prompt: String
    let reason: String?
}

// MARK: - 画像生成サービス
@MainActor
class ImageGenerationService: ObservableObject {
    
    // Vertex AI Imagen 3サービス
    private let vertexAIService = VertexAIService()
    
    // MARK: - 評価ベース生成
    func generateFromSwipeResults(
        _ swipeResults: [UUID: (direction: SwipeDirection, description: String?)],
        model: ReplicateModelInfo
    ) async throws -> GenerationResult {
        
        // 好まれた画像の説明文を抽出
        let likedDescriptions = extractLikedDescriptions(from: swipeResults)
        
        let promptResult: PromptGenerationResult
        
        if !likedDescriptions.isEmpty {
            promptResult = try await generatePrompt(from: likedDescriptions)
        } else {
            promptResult = PromptGenerationResult(
                prompt: generateGenericPrompt(for: model.inputType),
                reason: "特に強く好む画像が見つからなかったため、汎用的なプロンプトを使用しました。"
            )
        }
        
        return try await generateImage(
            prompt: promptResult.prompt,
            model: model,
            reason: promptResult.reason
        )
    }
    
    // MARK: - 直接生成
    func generateDirectly(
        prompt: String,
        model: ReplicateModelInfo
    ) async throws -> GenerationResult {
        
        return try await generateImage(
            prompt: prompt,
            model: model,
            reason: "ユーザーが直接入力したプロンプトです。"
        )
    }
    
    // MARK: - プロンプト生成
    func generatePrompt(from descriptions: [String]) async throws -> PromptGenerationResult {
        // Geminiでプロンプト生成を試行
        if let geminiResult = await tryGeminiPromptGeneration(descriptions: descriptions) {
            return geminiResult
        }
        
        // フォールバック: キーワード抽出
        return generateFallbackPrompt(from: descriptions)
    }
    
    // MARK: - 画像生成（メイン処理）
    private func generateImage(
        prompt: String,
        model: ReplicateModelInfo,
        reason: String? = nil
    ) async throws -> GenerationResult {
        
        // Google Vertex AI Imagen 3の場合
        if model.inputType == .googleVertexAI {
            let image = try await generateWithVertexAI(prompt: prompt, model: model)
            return GenerationResult(
                image: image,
                prompt: prompt,
                reason: reason
            )
        }
        
        // Replicate APIの場合（既存の処理）
        guard !ReplicateConfig.apiKey.isEmpty, 
              ReplicateConfig.apiKey != "YOUR_REPLICATE_API_TOKEN" else {
            throw ImageGenerationError.invalidAPIKey
        }
        
        // 入力データを準備
        let inputData = prepareInputData(prompt: prompt, modelType: model.inputType)
        
        // リクエストを作成・送信
        let predictionResponse = try await submitPrediction(
            modelVersionId: model.versionId,
            inputData: inputData
        )
        
        // 結果をポーリング
        let finalResult = try await pollForResult(from: predictionResponse)
        
        // 画像をダウンロード
        let image = try await downloadImage(from: finalResult)
        
        return GenerationResult(
            image: image,
            prompt: prompt,
            reason: reason
        )
    }
    
    // MARK: - Vertex AI Imagen 3生成
    private func generateWithVertexAI(prompt: String, model: ReplicateModelInfo) async throws -> UIImage {
        do {
            // Fast版かどうかを判定
            let aspectRatio: Imagen3AspectRatio = .square
            let outputFormat: Imagen3OutputFormat = .png
            
            let image = try await vertexAIService.generateImage(
                prompt: prompt,
                aspectRatio: aspectRatio,
                outputFormat: outputFormat
            )
            
            print("✅ Google Vertex AI Imagen 3で画像生成成功！")
            return image
            
        } catch let vertexError as VertexAIGenerationError {
            // Vertex AIエラーをImageGenerationErrorに変換
            throw ImageGenerationError.networkError(vertexError.localizedDescription)
        } catch {
            throw ImageGenerationError.networkError("Vertex AI Imagen 3生成エラー: \(error.localizedDescription)")
        }
    }
}

// MARK: - Private Methods
private extension ImageGenerationService {
    
    func extractLikedDescriptions(from swipeResults: [UUID: (direction: SwipeDirection, description: String?)]) -> [String] {
        return swipeResults.compactMap { (_, result) in
            result.direction == .like ? result.description : nil
        }
    }
    
    func tryGeminiPromptGeneration(descriptions: [String]) async -> PromptGenerationResult? {
        guard !GeminiConfig.apiKey.isEmpty, 
              GeminiConfig.apiKey != "YOUR_GEMINI_API_KEY" else {
            return nil
        }
        
        let combinedDescriptions = descriptions.joined(separator: "\n---\n")
        let promptText = """
        ユーザーが好む画像の特徴は以下の通りです：
        
        \(combinedDescriptions)
        
        これらの特徴を分析して、ユーザーの好みに合った新しい画像を生成するための英語のプロンプトを作成してください。
        プロンプトは具体的で、アートスタイル、色彩、構図、雰囲気などの視覚的要素を含めてください。
        
        回答は必ず以下の形式に従ってください：
        
        英語プロンプト: [ここに英語のプロンプトを書く]
        理由: [なぜそのプロンプトを選んだかの理由を日本語で書く]
        
        例：
        英語プロンプト: Beautiful anime-style illustration of a young woman with flowing hair, soft pastel colors, dreamy atmosphere, high quality digital art
        理由: ユーザーはアニメ風のイラストと柔らかな色調、美しい女性キャラクターを好む傾向があるため、これらの要素を組み合わせたプロンプトを作成しました。
        """
        
        do {
            let response = try await callGeminiAPI(with: promptText)
            return parseGeminiResponse(response)
        } catch {
            print("Gemini API呼び出しエラー: \(error)")
            return nil
        }
    }
    
    func generateFallbackPrompt(from descriptions: [String]) -> PromptGenerationResult {
        let keywords = extractKeywordsFromDescriptions(descriptions)
        
        if !keywords.isEmpty {
            let keywordString = keywords.joined(separator: ", ")
            return PromptGenerationResult(
                prompt: "Create a beautiful artwork featuring \(keywordString), high quality, detailed, artistic style",
                reason: "Geminiでのプロンプト生成に失敗したため、好まれた画像の説明文からキーワードを抽出してプロンプトを構築しました。キーワード: \(keywordString)"
            )
        } else {
            let combinedHints = descriptions.prefix(3).joined(separator: ". ")
            return PromptGenerationResult(
                prompt: "Generate an image based on user preferences. User likes images described as: \"\(combinedHints)\". Generate a similar image with artistic style, high quality, detailed.",
                reason: "キーワード抽出に失敗したため、好まれた画像の説明文を単純に結合しました。"
            )
        }
    }
    
    func generateGenericPrompt(for inputType: ModelInputType) -> String {
        switch inputType {
        case .textToImage:
            return "Generate something amazing, detailed, high quality."
        case .imagen3:
            return "Generate something amazing, detailed, high quality, photorealistic."
        case .googleVertexAI:
            return "Create a beautiful, high-quality, photorealistic image with stunning details and artistic composition."
        case .conjunction:
            return "(このモデルはテキストプロンプトを使用しません)"
        }
    }
    
    func prepareInputData(prompt: String, modelType: ModelInputType) -> ReplicateInputData {
        switch modelType {
        case .textToImage:
            return .textToImage(.init(prompt: prompt, width: 1024, height: 1024))
        case .imagen3:
            return .imagen3(.init(
                prompt: prompt,
                aspect_ratio: "1:1",
                num_outputs: 1,
                output_format: "png",
                output_quality: 90
            ))
        case .googleVertexAI:
            // Vertex AI は専用の処理ルートを使用するため、ここでは使用されない
            return .textToImage(.init(prompt: prompt, width: 1024, height: 1024))
        case .conjunction:
            return .conjunction(.init(prompt_conjunction: true))
        }
    }
    
    func submitPrediction(modelVersionId: String, inputData: ReplicateInputData) async throws -> ReplicatePredictionResponse {
        let requestPayload = ReplicatePredictionRequest(version: modelVersionId, input: inputData)
        
        guard let url = URL(string: "https://api.replicate.com/v1/predictions") else {
            throw ImageGenerationError.networkError("無効なAPI URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(ReplicateConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestPayload)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ImageGenerationError.networkError("無効なサーバーレスポンス")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorDetail = String(data: data, encoding: .utf8) ?? "詳細不明"
                throw ImageGenerationError.apiError(httpResponse.statusCode, errorDetail)
            }
            
            return try JSONDecoder().decode(ReplicatePredictionResponse.self, from: data)
            
        } catch let error as ImageGenerationError {
            throw error
        } catch {
            throw ImageGenerationError.networkError(error.localizedDescription)
        }
    }
    
    func pollForResult(from initialResponse: ReplicatePredictionResponse) async throws -> ReplicatePredictionResponse {
        guard let getUrl = initialResponse.urls?.get else {
            throw ImageGenerationError.networkError("結果取得URLが見つかりません")
        }
        
        var predictionStatus = initialResponse.status
        var finalResult: ReplicatePredictionResponse = initialResponse
        let maxAttempts = 60
        var attempts = 0
        
        while ["starting", "processing"].contains(predictionStatus) && attempts < maxAttempts {
            attempts += 1
            print("現在のステータス: \(predictionStatus)... (試行 \(attempts)/\(maxAttempts))")
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒待機
            
            var getRequest = URLRequest(url: getUrl)
            getRequest.setValue("Token \(ReplicateConfig.apiKey)", forHTTPHeaderField: "Authorization")
            getRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (getData, getResponse) = try await URLSession.shared.data(for: getRequest)
            
            guard let httpGetResponse = getResponse as? HTTPURLResponse, 
                  httpGetResponse.statusCode == 200 else {
                continue // 次の試行へ
            }
            
            let getResult = try JSONDecoder().decode(ReplicatePredictionResponse.self, from: getData)
            predictionStatus = getResult.status
            finalResult = getResult
        }
        
        if attempts >= maxAttempts && ["starting", "processing"].contains(predictionStatus) {
            throw ImageGenerationError.timeoutError
        }
        
        if finalResult.status == "failed" {
            throw ImageGenerationError.apiError(0, finalResult.error ?? "生成に失敗しました")
        }
        
        if finalResult.status == "canceled" {
            throw ImageGenerationError.networkError("画像生成がキャンセルされました")
        }
        
        return finalResult
    }
    
    func downloadImage(from result: ReplicatePredictionResponse) async throws -> UIImage {
        guard let outputUrls = result.output, 
              let firstImageUrl = outputUrls.first else {
            throw ImageGenerationError.networkError("画像URLが見つかりません")
        }
        
        print("画像生成成功！ URL: \(firstImageUrl)")
        
        let (imageData, _) = try await URLSession.shared.data(from: firstImageUrl)
        
        guard let image = UIImage(data: imageData) else {
            throw ImageGenerationError.decodingError("画像データを UIImage に変換できませんでした")
        }
        
        return image
    }
    
    // Gemini API呼び出し
    func callGeminiAPI(with promptText: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(GeminiConfig.visionModel):generateContent?key=\(GeminiConfig.apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw ImageGenerationError.networkError("無効なGemini URL")
        }
        
        let requestPayload = GeminiGenerateContentRequest(
            contents: [.init(parts: [.init(text: promptText)])]
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONEncoder().encode(requestPayload)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.networkError("無効なGeminiレスポンス")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "詳細不明"
            throw ImageGenerationError.apiError(httpResponse.statusCode, errorString)
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        
        guard let responseText = geminiResponse.candidates?.first?.content?.parts?.first?.text else {
            throw ImageGenerationError.decodingError("Geminiレスポンスからテキストを取得できませんでした")
        }
        
        return responseText
    }
    
    // Geminiレスポンス解析
    func parseGeminiResponse(_ responseText: String) -> PromptGenerationResult? {
        // JSON形式での解析を試行
        if let jsonData = responseText.data(using: .utf8) {
            do {
                let promptResponse = try JSONDecoder().decode(GeneratedPromptResponse.self, from: jsonData)
                if let prompt = promptResponse.generated_prompt, !prompt.isEmpty {
                    print("✅ JSON形式でのプロンプト解析成功")
                    return PromptGenerationResult(prompt: prompt, reason: promptResponse.reason)
                }
            } catch {
                print("📝 GeminiレスポンスはJSON形式ではありません。テキスト解析を実行中...")
            }
        }
        
        // テキストパターンマッチング
        let lines = responseText.components(separatedBy: .newlines)
        var extractedPrompt: String?
        var extractedReason: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.contains("英語プロンプト:") || trimmedLine.contains("プロンプト:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    extractedPrompt = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if trimmedLine.lowercased().contains("english prompt:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    extractedPrompt = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if trimmedLine.contains("理由:") || trimmedLine.contains("理由：") {
                let components = trimmedLine.components(separatedBy: CharacterSet(charactersIn: ":："))
                if components.count > 1 {
                    extractedReason = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // 英語らしい文章を探す
        if extractedPrompt == nil || extractedPrompt!.isEmpty {
            let englishKeywords = ["beautiful", "artwork", "style", "detailed", "high quality", "masterpiece", "art", "painting", "illustration"]
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let containsEnglishKeywords = englishKeywords.contains { keyword in
                    trimmedLine.lowercased().contains(keyword)
                }
                
                if containsEnglishKeywords && trimmedLine.count > 20 {
                    extractedPrompt = trimmedLine
                    break
                }
            }
        }
        
        if let prompt = extractedPrompt, !prompt.isEmpty {
            print("✅ テキスト解析でプロンプト抽出成功")
            return PromptGenerationResult(prompt: prompt, reason: extractedReason)
        }
        
        print("⚠️ プロンプトの抽出に失敗しました")
        return nil
    }
    
    // キーワード抽出
    func extractKeywordsFromDescriptions(_ descriptions: [String]) -> [String] {
        let combinedText = descriptions.joined(separator: " ").lowercased()
        
        let artKeywords = [
            "アニメ", "anime", "漫画", "manga", "イラスト", "illustration",
            "絵画", "painting", "水彩", "watercolor", "デジタルアート", "digital art"
        ]
        
        let colorKeywords = [
            "赤", "red", "青", "blue", "緑", "green", "明るい", "bright",
            "パステル", "pastel", "鮮やか", "vibrant"
        ]
        
        let moodKeywords = [
            "美しい", "beautiful", "可愛い", "cute", "神秘的", "mysterious",
            "幻想的", "dreamy", "ロマンチック", "romantic"
        ]
        
        let allKeywords = artKeywords + colorKeywords + moodKeywords
        var foundKeywords: [String] = []
        
        for keyword in allKeywords {
            if combinedText.contains(keyword) && !foundKeywords.contains(keyword) {
                foundKeywords.append(keyword)
                if foundKeywords.count >= 8 {
                    break
                }
            }
        }
        
        return foundKeywords
    }
} 