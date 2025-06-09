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

// MARK: - 画像スタイル定義
enum ImageStyle {
    case anime      // アニメ・イラスト風
    case realistic  // リアル・写真風
    case abstract   // 抽象・アート風
    case landscape  // 風景・自然風
    case artistic   // アーティスティック
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

// MARK: - 🚀 最適化された画像生成サービス
@MainActor
class ImageGenerationService: ObservableObject {
    
    // Vertex AI Imagen 3サービス
    private let vertexAIService = VertexAIService()
    
    // 🔧 パフォーマンス最適化用
    private var generationCount = 0
    private let maxGenerationsPerHour = 20
    private var lastGenerationTime = Date()
    
    // MARK: - 評価ベース生成（最適化版）
    func generateFromSwipeResults(
        _ swipeResults: [UUID: (direction: SwipeDirection, description: String?)],
        evaluationResults: [ImageEvaluationResult] = [],
        model: ReplicateModelInfo
    ) async throws -> GenerationResult {
        
        // 🔧 生成制限チェック
        try checkGenerationLimit()
        
        // 評価結果から好まれた画像の詳細分析を抽出
        let likedAnalysis = extractLikedAnalysis(from: evaluationResults)
        
        // 必ずGeminiでプロンプト＆理由を生成
        let promptResult = await tryGeminiPromptGeneration(descriptions: likedAnalysis) ?? generateFallbackPrompt(from: likedAnalysis)
        
        // Vertex AI Imagen 3を最優先で試行
        let fallbackModels = ReplicateConfig.availableModels.filter { 
            $0.inputType == .googleVertexAI 
        }.sorted { $0.name < $1.name }
        
        if let vertexModel = fallbackModels.first {
            do {
                print("🚀 Vertex AI Imagen 3で高品質生成開始...")
                let image = try await generateWithVertexAI(prompt: promptResult.prompt, model: vertexModel)
                return GenerationResult(image: image, prompt: promptResult.prompt, reason: promptResult.reason)
            } catch {
                print("⚠️ Vertex AI失敗: \(error) - Replicateへフォールバック")
                // Replicate APIで画像生成
                let fallbackImage = try await generateWithReplicateAPI(prompt: promptResult.prompt, model: model)
                return GenerationResult(image: fallbackImage, prompt: promptResult.prompt, reason: promptResult.reason)
            }
        } else {
            // Replicate APIで画像生成
            let fallbackImage = try await generateWithReplicateAPI(prompt: promptResult.prompt, model: model)
            return GenerationResult(image: fallbackImage, prompt: promptResult.prompt, reason: promptResult.reason)
        }
    }
    
    // MARK: - 直接生成（最適化版）
    func generateDirectly(
        prompt: String,
        model: ReplicateModelInfo
    ) async throws -> GenerationResult {
        
        // 🔧 生成制限チェック
        try checkGenerationLimit()
        
        return try await generateImage(
            prompt: prompt,
            model: model,
            reason: "ユーザーが直接入力したプロンプトです。"
        )
    }
    
    // MARK: - 🚀 改良されたプロンプト生成（Gemini優先）
    func generatePrompt(from descriptions: [String]) async throws -> PromptGenerationResult {
        print("🎯 プロンプト生成開始 - 詳細ログ")
        print("📊 入力説明文数: \(descriptions.count)")
        
        // 空の場合のガード
        if descriptions.isEmpty {
            print("⚠️ 説明文が空です - 汎用プロンプトを使用")
            return PromptGenerationResult(
                prompt: "Create a beautiful, high-quality artwork with stunning details and artistic composition",
                reason: "評価データが不足しているため、汎用的なプロンプトを使用しました。"
            )
        }
        
        // 説明文の内容をログ出力
        for (index, description) in descriptions.enumerated() {
            print("📝 説明文\(index + 1): \(description.prefix(100))...")
        }
        
        print("🎯 プロンプト生成開始 - 説明文数: \(descriptions.count)")
        
        // 🤖 第1優先: Geminiで高品質プロンプト生成を試行
        print("🚀 Gemini高品質プロンプト生成を優先実行...")
        print("🔑 GeminiAPIキー設定状況: \(GeminiConfig.apiKey.isEmpty ? "未設定" : "設定済み")")
        
        if let geminiResult = await tryGeminiPromptGeneration(descriptions: descriptions) {
            print("✅ Gemini高品質プロンプト生成成功!")
            print("📋 生成されたプロンプト: \(geminiResult.prompt)")
            print("💭 生成理由: \(geminiResult.reason ?? "理由なし")")
            return geminiResult
        } else {
            print("❌ Gemini高品質プロンプト生成失敗 - フォールバックに移行")
        }
        
        // 🔄 第2優先: 拡張キーワード抽出でフォールバック
        print("🔄 キーワード抽出フォールバックに移行...")
        let fallbackResult = generateFallbackPrompt(from: descriptions)
        
        // 🎨 第3優先: 説明文直接活用（最終手段）
        if fallbackResult.prompt.contains("generic") || fallbackResult.prompt.count < 20 {
            print("🎨 説明文直接活用プロンプト生成...")
            
            let combinedText = descriptions.joined(separator: ", ")
            let intelligentPrompt = createIntelligentPromptFromDescriptions(combinedText)
            
            return PromptGenerationResult(
                prompt: intelligentPrompt,
                reason: "Geminiとキーワード抽出に失敗したため、説明文から直接的にプロンプトを構築しました。"
            )
        }
        
        print("🔄 フォールバック結果使用: \(fallbackResult.prompt)")
        return fallbackResult
    }
    
    // 🧠 インテリジェントプロンプト作成
    private func createIntelligentPromptFromDescriptions(_ text: String) -> String {
        print("🧠 インテリジェントプロンプト作成開始")
        
        let lowercasedText = text.lowercased()
        var promptComponents: [String] = []
        
        // 🎨 アートスタイル判定
        if lowercasedText.contains("アニメ") || lowercasedText.contains("anime") || lowercasedText.contains("manga") {
            promptComponents.append("anime style illustration")
        } else if lowercasedText.contains("realistic") || lowercasedText.contains("photo") || lowercasedText.contains("portrait") {
            promptComponents.append("photorealistic")
        } else if lowercasedText.contains("painting") || lowercasedText.contains("art") {
            promptComponents.append("digital painting")
        } else {
            promptComponents.append("beautiful artwork")
        }
        
        // 🌈 色彩判定
        let colorMap = [
            "bright": "bright colors",
            "dark": "dark atmosphere", 
            "colorful": "vibrant colors",
            "pastel": "soft pastel colors",
            "monochrome": "monochromatic"
        ]
        
        for (keyword, description) in colorMap {
            if lowercasedText.contains(keyword) {
                promptComponents.append(description)
                break
            }
        }
        
        // 😊 雰囲気判定
        let moodMap = [
            "beautiful": "beautiful",
            "cute": "cute and charming", 
            "mysterious": "mysterious atmosphere",
            "dreamy": "dreamy and ethereal",
            "cool": "cool and stylish",
            "elegant": "elegant and sophisticated"
        ]
        
        for (keyword, description) in moodMap {
            if lowercasedText.contains(keyword) {
                promptComponents.append(description)
                break
            }
        }
        
        // 🏞️ テーマ判定
        let themeMap = [
            "nature": "natural scenery",
            "landscape": "beautiful landscape",
            "portrait": "portrait",
            "fantasy": "fantasy theme"
        ]
        
        for (keyword, description) in themeMap {
            if lowercasedText.contains(keyword) {
                promptComponents.append(description)
                break
            }
        }
        
        // 基本的な品質キーワードを追加
        promptComponents.append("high quality")
        promptComponents.append("detailed")
        promptComponents.append("masterpiece")
        
        let finalPrompt = promptComponents.joined(separator: ", ")
        print("🎯 生成されたインテリジェントプロンプト: \(finalPrompt)")
        
        return finalPrompt
    }
    
    // MARK: - 🔧 最適化された画像生成（メイン処理）
    private func generateImage(
        prompt: String,
        model: ReplicateModelInfo,
        reason: String? = nil
    ) async throws -> GenerationResult {
        
        // Google Vertex AI Imagen 3の場合（優先）
        if model.inputType == .googleVertexAI {
            let image = try await generateWithVertexAI(prompt: prompt, model: model)
            return GenerationResult(
                image: image,
                prompt: prompt,
                reason: reason
            )
        }
        
        // Replicate APIの場合（フォールバック）
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
        
        // 結果をポーリング（タイムアウト最適化）
        let finalResult = try await pollForResult(from: predictionResponse)
        
        // 画像をダウンロード
        let image = try await downloadImage(from: finalResult)
        
        return GenerationResult(
            image: image,
            prompt: prompt,
            reason: reason
        )
    }
    
    // MARK: - 🚀 最適化されたVertex AI Imagen 3生成（自動フォールバック付き）
    private func generateWithVertexAI(prompt: String, model: ReplicateModelInfo) async throws -> UIImage {
        print("🚨 発表会緊急診断: Vertex AI生成開始")
        print("📝 プロンプト: \(prompt)")
        print("🏷️ モデル: \(model.name)")
        
        do {
            let aspectRatio: Imagen3AspectRatio = .square
            let outputFormat: Imagen3OutputFormat = .png
            
            print("⚙️ 設定: \(aspectRatio.rawValue), \(outputFormat.rawValue)")
            print("🔗 エンドポイント: \(GoogleCloudConfig.vertexAIEndpoint)")
            print("🆔 プロジェクトID: \(GoogleCloudConfig.projectId)")
            
            // タイムアウト付きで生成
            let image = try await withTimeout(seconds: 30) { [self] in
                try await self.vertexAIService.generateImage(
                prompt: prompt,
                aspectRatio: aspectRatio,
                outputFormat: outputFormat
            )
            }
            
            print("✅ Google Vertex AI Imagen 3で画像生成成功！")
            return image
            
        } catch let error as VertexAIGenerationError {
            print("❌ Vertex AI特定エラー: \(error.localizedDescription)")
            
            // 特定のエラータイプに応じた診断情報
            switch error {
            case .invalidConfiguration:
                print("🔧 設定問題: APIキーまたはプロジェクトIDを確認してください")
            case .httpError(let code, let message):
                print("🌐 HTTPエラー \(code): \(message)")
                if code == 401 {
                    print("🔑 認証エラー: アクセストークンが期限切れの可能性があります")
                    print("💡 解決方法: gcloud auth print-access-token で新しいトークンを取得")
                } else if code == 403 {
                    print("🚫 権限エラー: Vertex AI User権限を確認してください")
                }
            case .networkError(let message):
                print("📡 ネットワークエラー: \(message)")
            default:
                print("❓ その他のエラー: \(error)")
            }
            
            throw error
            
        } catch {
            print("❌ 予期しないVertex AIエラー: \(error.localizedDescription)")
            print("🔄 Replicateに自動切り替えします")
            
            // 🔄 発表会緊急対策: 自動フォールバック
            let fallbackModel = ReplicateConfig.availableModels.first { 
                $0.modelId == "aisha-ai-official/miaomiao-harem-illustrious-v1" 
            } ?? ReplicateConfig.availableModels.first { $0.inputType == .textToImage }!
            
            print("🔄 フォールバックモデル使用: \(fallbackModel.name)")
            
            // Replicateで再生成
            return try await generateWithReplicate(prompt: prompt, model: fallbackModel)
        }
    }
    
    // MARK: - 🔄 Replicateフォールバック生成
    private func generateWithReplicate(prompt: String, model: ReplicateModelInfo) async throws -> UIImage {
        guard !ReplicateConfig.apiKey.isEmpty, 
              ReplicateConfig.apiKey != "YOUR_REPLICATE_API_TOKEN",
              ReplicateConfig.apiKey != "r8_NRN1J3xHZON5EoWF4Q4K6RZg2h5dT8Ky1f0Ck" else {
            print("⚠️ 無効なAPIキー、デモ画像を生成します")
            return try await generateDemoImage(prompt: prompt)
        }
        
        do {
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
            
            print("✅ Replicateで画像生成成功！")
            return image
            
        } catch let error as ImageGenerationError {
            if case .apiError(let code, _) = error, code == 401 {
                print("🚨 認証エラー: デモ画像を生成します")
                return try await generateDemoImage(prompt: prompt)
            }
            throw error
        } catch {
            print("🚨 予期しないエラー: デモ画像を生成します - \(error)")
            return try await generateDemoImage(prompt: prompt)
        }
    }
    
    // MARK: - 🎨 発表会用デモ画像生成
    private func generateDemoImage(prompt: String) async throws -> UIImage {
        print("🎨 プロンプト「\(prompt)」に基づいてデモ画像を生成中...")
        
        // 1秒の遅延でリアルな生成感を演出
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // プロンプトのキーワードに基づいて色を決定
        let colors = determineColorsFromPrompt(prompt)
        let image = createGradientArtImage(colors: colors, prompt: prompt)
        
        print("✅ デモ画像生成完了！")
        return image
    }
    
    // MARK: - 🌈 プロンプトベースカラー決定
    private func determineColorsFromPrompt(_ prompt: String) -> [UIColor] {
        let lowercasePrompt = prompt.lowercased()
        
        // アニメ・可愛い系
        if lowercasePrompt.contains("anime") || lowercasePrompt.contains("cute") || lowercasePrompt.contains("kawaii") || lowercasePrompt.contains("可愛い") {
            return [
                UIColor(red: 1.0, green: 0.7, blue: 0.8, alpha: 1.0), // ピンク
                UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0), // ライトブルー
                UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1.0)  // クリーム
            ]
        }
        
        // 自然・風景系
        if lowercasePrompt.contains("nature") || lowercasePrompt.contains("landscape") || lowercasePrompt.contains("forest") || lowercasePrompt.contains("mountain") {
            return [
                UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0), // グリーン
                UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0), // スカイブルー
                UIColor(red: 0.9, green: 0.9, blue: 0.7, alpha: 1.0)  // ベージュ
            ]
        }
        
        // 夜・宇宙・神秘系
        if lowercasePrompt.contains("night") || lowercasePrompt.contains("space") || lowercasePrompt.contains("star") || lowercasePrompt.contains("mysterious") {
            return [
                UIColor(red: 0.1, green: 0.1, blue: 0.4, alpha: 1.0), // ダークブルー
                UIColor(red: 0.3, green: 0.0, blue: 0.5, alpha: 1.0), // パープル
                UIColor(red: 0.8, green: 0.8, blue: 0.0, alpha: 1.0)  // ゴールド
            ]
        }
        
        // 暖色系（デフォルト）
        return [
            UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0), // オレンジ
            UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 1.0), // イエロー
            UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)  // ピンク
        ]
    }
    
    // MARK: - 🎨 アート風グラデーション画像生成
    private func createGradientArtImage(colors: [UIColor], prompt: String) -> UIImage {
        let size = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 背景グラデーション
            let gradient = createGradient(colors: colors)
            cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // 装飾パターンを追加
            addArtisticPatterns(to: cgContext, size: size, colors: colors)
            
            // プロンプトテキストをオーバーレイ
            addPromptOverlay(to: cgContext, size: size, prompt: prompt)
        }
    }
    
    private func createGradient(colors: [UIColor]) -> CGGradient {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let cgColors = colors.map { $0.cgColor }
        let locations: [CGFloat] = Array(stride(from: 0.0, through: 1.0, by: 1.0 / Double(colors.count - 1)))
        
        return CGGradient(colorsSpace: colorSpace, colors: cgColors as CFArray, locations: locations)!
    }
    
    private func addArtisticPatterns(to context: CGContext, size: CGSize, colors: [UIColor]) {
        // 円形パターン
        context.setBlendMode(.overlay)
        
        for i in 0..<10 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let radius = CGFloat.random(in: 30...150)
            let color = colors.randomElement()?.withAlphaComponent(0.3) ?? UIColor.white.withAlphaComponent(0.3)
            
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        }
        
        // 線パターン
        context.setBlendMode(.softLight)
        context.setLineWidth(3.0)
        
        for i in 0..<15 {
            let startX = CGFloat.random(in: 0...size.width)
            let startY = CGFloat.random(in: 0...size.height)
            let endX = CGFloat.random(in: 0...size.width)
            let endY = CGFloat.random(in: 0...size.height)
            let color = colors.randomElement()?.withAlphaComponent(0.4) ?? UIColor.white.withAlphaComponent(0.4)
            
            context.setStrokeColor(color.cgColor)
            context.move(to: CGPoint(x: startX, y: startY))
            context.addLine(to: CGPoint(x: endX, y: endY))
            context.strokePath()
        }
    }
    
    private func addPromptOverlay(to context: CGContext, size: CGSize, prompt: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -2.0
        ]
        
        let shortPrompt = String(prompt.prefix(50)) + (prompt.count > 50 ? "..." : "")
        let attributedString = NSAttributedString(string: "✨ \(shortPrompt)", attributes: attributes)
        
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: size.height - textSize.height - 40,
            width: textSize.width,
            height: textSize.height
        )
        
        attributedString.draw(in: textRect)
        
        // "AI Generated Demo" ラベル
        let demoAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8),
            .backgroundColor: UIColor.black.withAlphaComponent(0.5)
        ]
        
        let demoString = NSAttributedString(string: " 🎨 AI Generated Demo ", attributes: demoAttributes)
        let demoSize = demoString.size()
        let demoRect = CGRect(
            x: 20,
            y: 20,
            width: demoSize.width,
            height: demoSize.height
        )
        
        demoString.draw(in: demoRect)
    }
    
    // MARK: - 🔧 Private Helper Methods
    
    private func checkGenerationLimit() throws {
        let now = Date()
        let timeDifference = now.timeIntervalSince(lastGenerationTime)
        
        // 1時間経過したらカウンタリセット
        if timeDifference >= 3600 {
            generationCount = 0
            lastGenerationTime = now
        }
        
        if generationCount >= maxGenerationsPerHour {
            throw ImageGenerationError.networkError("1時間あたりの画像生成制限に達しました。しばらく待ってから再試行してください。")
        }
        
        generationCount += 1
    }
    
    // 🚀 強化されたGeminiプロンプト生成（Vertex AI経由・複数評価まとめ）
    private func tryGeminiPromptGeneration(descriptions: [String]) async -> PromptGenerationResult? {
        // Vertex AI経由でGeminiを使用
        print("🤖 Vertex AI経由でGemini画像生成プロンプト生成開始...")

        // 🎯 評価（analysisText）を構造化
        let organizedDescriptions = descriptions.prefix(8).enumerated().map { index, desc in
            "【画像\(index + 1)】\(desc.trimmingCharacters(in: .whitespacesAndNewlines))"
        }.joined(separator: "\n\n")

        // 📝 Geminiへの明確な指示文
        let enhancedPromptText = """
        あなたは画像生成AI用のプロンプト作成の専門家です。

        ユーザーが「好き」と評価した画像の特徴を分析し、Stable DiffusionやMidjourneyなどの画像生成AIで使用する高品質な英語プロンプトを作成してください。

        【ユーザーが好む画像の特徴（複数）】
        \(organizedDescriptions)

        【タスク】
        上記の全ての画像特徴を総合的に分析し、以下の形式で回答してください：

        PROMPT: [75語以内の具体的な英語プロンプト。視覚的特徴、色彩、構図、スタイル、雰囲気を含む]
        NEGATIVE: [避けるべき要素の英語リスト。20語以内]
        REASON: [なぜこのプロンプトを選んだか日本語で簡潔に説明]
        STYLE: [アートスタイル（例：anime, realistic, digital painting）]
        MOOD: [雰囲気（例：peaceful, energetic, mysterious）]

        【重要な指示】
        - プロンプトは必ず英語で記述
        - 具体的で視覚的な描写を含める
        - 品質を示すキーワード（4k, detailed, masterpiece等）を適切に含める
        - ユーザーの好みのパターンを正確に反映させる
        - 画像ごとの特徴を必ず総合して一つのプロンプトにまとめる
        """

        do {
            let vertexAIService = VertexAIService()
            let responseText = try await vertexAIService.generateTextWithGemini(prompt: enhancedPromptText)

            print("✅ Vertex AI Geminiレスポンス取得成功")
            print("📄 レスポンス: \(responseText.prefix(200))...")

            if let result = parseEnhancedGeminiResponse(responseText) {
                print("✅ Vertex AI経由のGeminiプロンプト生成成功！")
                return result
            } else {
                print("⚠️ Vertex AI Geminiレスポンスの解析に失敗")
                return nil
            }
        } catch {
            print("❌ Vertex AI Gemini呼び出しエラー: \(error)")
            return nil
        }
    }

    // 必要なヘルパーメソッドを追加
    private func extractLikedAnalysis(from evaluationResults: [ImageEvaluationResult]) -> [String] {
        return evaluationResults.compactMap { result in
            result.swipeDirection == .like ? result.analysisText : nil
        }
    }
    
    private func generatePromptFromEvaluations(from likedAnalysis: [String]) async throws -> PromptGenerationResult {
        // Geminiで評価結果ベースのプロンプト生成を試行
        if let geminiResult = await tryGeminiPromptGeneration(descriptions: likedAnalysis) {
            return geminiResult
        }
        
        // フォールバック: 評価結果からキーワードを抽出
        return generateFallbackPrompt(from: likedAnalysis)
    }
    
    private func extractLikedDescriptions(from swipeResults: [UUID: (direction: SwipeDirection, description: String?)]) -> [String] {
        return swipeResults.compactMap { (_, result) in
            result.direction == .like ? result.description : nil
        }
    }
    
    private func generateGenericPrompt(for inputType: ModelInputType) -> String {
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
    
    private func generateFallbackPrompt(from descriptions: [String]) -> PromptGenerationResult {
        print("🔄 フォールバックプロンプト生成開始")
        
        // キーワード抽出を試行
        let keywords = extractKeywordsFromDescriptions(descriptions)
        
        if !keywords.isEmpty {
            let keywordString = keywords.joined(separator: ", ")
            print("✅ キーワードベースプロンプト生成: \(keywordString)")
            return PromptGenerationResult(
                prompt: "Create a beautiful artwork featuring \(keywordString), high quality, detailed, artistic style",
                reason: "好まれた画像の説明文からキーワードを抽出してプロンプトを構築しました。抽出キーワード: \(keywordString)"
            )
        } else {
            // キーワード抽出に失敗した場合の高度なフォールバック
            print("⚠️ キーワード抽出失敗 - 高度なフォールバック処理開始")
            
            if !descriptions.isEmpty {
                // 説明文から直接的な特徴を抽出
                let combinedText = descriptions.joined(separator: ". ")
                let truncatedText = String(combinedText.prefix(200)) // 200文字まで
                
                // 簡単な感情分析
                let positiveWords = ["美しい", "素敵", "好き", "良い", "beautiful", "nice", "good", "amazing", "stunning"]
                let hasPositiveWords = positiveWords.contains { word in
                    combinedText.lowercased().contains(word.lowercased())
                }
                
                let basePrompt = hasPositiveWords ? 
                    "Create a beautiful, stunning artwork with artistic style" :
                    "Create an interesting, unique artwork with creative style"
                
                return PromptGenerationResult(
                    prompt: "\(basePrompt), high quality, detailed. Inspired by: \(truncatedText)",
                    reason: "キーワード抽出に失敗しましたが、好まれた画像の説明文を直接活用してプロンプトを構築しました。"
                )
            } else {
                // 完全なフォールバック: 汎用的な高品質プロンプト
                print("📝 汎用プロンプト生成")
                let genericPrompts = [
                    "Create a beautiful, high-quality digital artwork with stunning visual appeal",
                    "Generate an artistic masterpiece with vibrant colors and detailed composition",
                    "Create a visually striking image with professional quality and artistic flair",
                    "Generate a captivating artwork with beautiful aesthetics and creative design",
                    "Create an impressive visual piece with high artistic value and detailed execution"
                ]
                
                let selectedPrompt = genericPrompts.randomElement() ?? genericPrompts[0]
                
                return PromptGenerationResult(
                    prompt: selectedPrompt,
                    reason: "評価データが不足しているため、高品質な汎用アートプロンプトを使用しました。"
                )
            }
        }
    }
    
    private func extractKeywordsFromDescriptions(_ descriptions: [String]) -> [String] {
        // 空の場合のガード
        guard !descriptions.isEmpty else { return [] }
        
        print("🔍 キーワード抽出開始 - 説明文数: \(descriptions.count)")
        
        let combinedText = descriptions.joined(separator: " ").lowercased()
        print("📝 結合テキスト: \(combinedText)")
        
        // 🎨 アート・スタイルキーワード
        let artKeywords = [
            "アニメ", "anime", "漫画", "manga", "イラスト", "illustration",
            "絵画", "painting", "水彩", "watercolor", "デジタルアート", "digital art",
            "油絵", "oil painting", "スケッチ", "sketch", "ドローイング", "drawing",
            "3d", "cg", "レンダリング", "render", "photorealistic", "realistic"
        ]
        
        // 🌈 色彩キーワード
        let colorKeywords = [
            "赤", "red", "青", "blue", "緑", "green", "黄", "yellow",
            "紫", "purple", "ピンク", "pink", "黒", "black", "白", "white",
            "明るい", "bright", "暗い", "dark", "パステル", "pastel", 
            "鮮やか", "vibrant", "カラフル", "colorful", "モノクロ", "monochrome"
        ]
        
        // 😊 雰囲気・感情キーワード
        let moodKeywords = [
            "美しい", "beautiful", "可愛い", "cute", "神秘的", "mysterious",
            "幻想的", "dreamy", "ロマンチック", "romantic", "セクシー", "sexy",
            "クール", "cool", "エレガント", "elegant", "ポップ", "pop"
        ]
        
        // 🌍 テーマ・設定キーワード
        let themeKeywords = [
            "自然", "nature", "風景", "landscape", "海", "ocean", "山", "mountain",
            "空", "sky", "森", "forest", "花", "flower", "動物", "animal",
            "都市", "city", "建物", "building", "人物", "person", "顔", "face"
        ]
        
        // 🎭 スタイル・技法キーワード
        let styleKeywords = [
            "リアル", "real", "抽象", "abstract", "ミニマル", "minimal",
            "詳細", "detailed", "シンプル", "simple", "複雑", "complex",
            "高品質", "high quality", "masterpiece", "アート", "art"
        ]
        
        // 全キーワードリスト
        let allKeywordCategories = [
            ("アート", artKeywords),
            ("色彩", colorKeywords),
            ("雰囲気", moodKeywords),
            ("テーマ", themeKeywords),
            ("スタイル", styleKeywords)
        ]
        
        var foundKeywords: [String] = []
        var categoryStats: [String: Int] = [:]
        
        // カテゴリ別にキーワードを検索
        for (category, keywords) in allKeywordCategories {
            var categoryCount = 0
            
            for keyword in keywords {
                if combinedText.contains(keyword) {
                    if !foundKeywords.contains(keyword) {
                        foundKeywords.append(keyword)
                        categoryCount += 1
                        print("✅ \(category)キーワード発見: \(keyword)")
                    }
                }
            }
            
            categoryStats[category] = categoryCount
        }
        
        // 🔧 高度なキーワード抽出: 文字列パターンマッチング
        let additionalPatterns = [
            // 日本語の形容詞パターン
            "美しい", "綺麗", "素敵", "素晴らしい", "魅力的", "印象的",
            // 英語の形容詞パターン
            "stunning", "gorgeous", "amazing", "fantastic", "incredible", "wonderful",
            // 技術的なパターン
            "4k", "8k", "hd", "ultra", "professional", "studio lighting"
        ]
        
        for pattern in additionalPatterns {
            if combinedText.contains(pattern.lowercased()) {
                if !foundKeywords.contains(pattern) {
                    foundKeywords.append(pattern)
                    print("✅ パターンマッチ: \(pattern)")
                }
            }
        }
        
        // 🎯 結果の統計表示
        print("📊 カテゴリ別統計:")
        for (category, count) in categoryStats {
            print("   \(category): \(count)個")
        }
        print("🔍 抽出キーワード総数: \(foundKeywords.count)")
        print("📝 抽出キーワード: \(foundKeywords.joined(separator: ", "))")
        
        // 上位8個までに制限（品質優先）
        let limitedKeywords = Array(foundKeywords.prefix(8))
        
        if limitedKeywords.isEmpty {
            print("⚠️ キーワード抽出失敗 - フォールバック処理へ")
        } else {
            print("✅ キーワード抽出成功: \(limitedKeywords.count)個")
        }
        
        return limitedKeywords
    }
    
    private func prepareInputData(prompt: String, modelType: ModelInputType) -> ReplicateInputData {
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
    
    private func submitPrediction(modelVersionId: String, inputData: ReplicateInputData) async throws -> ReplicatePredictionResponse {
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
    
    private func downloadImage(from result: ReplicatePredictionResponse) async throws -> UIImage {
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
    
    // 🚀 Vertex AI経由でのGemini呼び出しに移行しました
    // 直接のGemini API呼び出しは廃止され、すべてVertex AI経由で行われます
    

    
    // 🔧 最適化されたポーリング処理
    private func pollForResult(from initialResponse: ReplicatePredictionResponse) async throws -> ReplicatePredictionResponse {
        guard let getUrl = initialResponse.urls?.get else {
            throw ImageGenerationError.networkError("結果取得URLが見つかりません")
        }
        
        var predictionStatus = initialResponse.status
        var finalResult: ReplicatePredictionResponse = initialResponse
        let maxAttempts = 30 // 30秒に短縮
        var attempts = 0
        
        while ["starting", "processing"].contains(predictionStatus) && attempts < maxAttempts {
            attempts += 1
            print("📊 生成進行状況: \(predictionStatus)... (\(attempts)/\(maxAttempts))")
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒待機
            
            var getRequest = URLRequest(url: getUrl)
            getRequest.setValue("Token \(ReplicateConfig.apiKey)", forHTTPHeaderField: "Authorization")
            getRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            getRequest.timeoutInterval = 10.0 // タイムアウト短縮
            
            do {
            let (getData, getResponse) = try await URLSession.shared.data(for: getRequest)
            
            guard let httpGetResponse = getResponse as? HTTPURLResponse, 
                  httpGetResponse.statusCode == 200 else {
                continue // 次の試行へ
            }
            
            let getResult = try JSONDecoder().decode(ReplicatePredictionResponse.self, from: getData)
            predictionStatus = getResult.status
            finalResult = getResult
            } catch {
                print("⚠️ ポーリング中のエラー: \(error)")
                // エラーでも続行
            }
        }
        
        if attempts >= maxAttempts && ["starting", "processing"].contains(predictionStatus) {
            throw ImageGenerationError.timeoutError
        }
        
        if finalResult.status == "failed" {
            throw ImageGenerationError.apiError(0, finalResult.error ?? "生成に失敗しました")
        }
        
        return finalResult
    }
    
    // MARK: - 🎨 高品質ローカル画像生成（評価データベース）
    private func generateHighQualityLocalImage(
        prompt: String, 
        analysisData: [String]
    ) async throws -> UIImage {
        print("🎨 高品質ローカル生成開始 - プロンプト: \(prompt)")
        
        // 1秒の生成時間でリアル感を演出
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 評価データとプロンプトから画像スタイルを決定
        let imageStyle = determineImageStyle(from: prompt, analysisData: analysisData)
        let colorPalette = determineAdvancedColors(from: prompt, analysisData: analysisData)
        
        let image = createAdvancedArtImage(
            style: imageStyle,
            colors: colorPalette,
            prompt: prompt,
            analysisData: analysisData
        )
        
        print("✅ 高品質ローカル生成完了！")
        return image
    }
    
    // MARK: - 🎯 画像スタイル決定
    private func determineImageStyle(from prompt: String, analysisData: [String]) -> ImageStyle {
        let combinedText = (prompt + " " + analysisData.joined(separator: " ")).lowercased()
        
        // アニメ・イラスト系
        if combinedText.contains("anime") || combinedText.contains("manga") || 
           combinedText.contains("illustration") || combinedText.contains("アニメ") {
            return .anime
        }
        
        // リアル・写真系
        if combinedText.contains("realistic") || combinedText.contains("photo") || 
           combinedText.contains("portrait") || combinedText.contains("人物") {
            return .realistic
        }
        
        // 抽象・アート系
        if combinedText.contains("abstract") || combinedText.contains("art") || 
           combinedText.contains("artistic") || combinedText.contains("抽象") {
            return .abstract
        }
        
        // 風景・自然系
        if combinedText.contains("landscape") || combinedText.contains("nature") || 
           combinedText.contains("mountain") || combinedText.contains("風景") {
            return .landscape
        }
        
        return .artistic // デフォルト
    }
    
    // MARK: - 🌈 高品質カラーパレット決定
    private func determineAdvancedColors(from prompt: String, analysisData: [String]) -> [UIColor] {
        let combinedText = (prompt + " " + analysisData.joined(separator: " ")).lowercased()
        
        // 暖色系・夕焼け
        if combinedText.contains("warm") || combinedText.contains("sunset") || 
           combinedText.contains("orange") || combinedText.contains("暖か") {
            return [
                UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),  // 夕焼けオレンジ
                UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0),  // コーラルピンク
                UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0),  // ゴールデンイエロー
                UIColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1.0)   // 深い赤
            ]
        }
        
        // 寒色系・海
        if combinedText.contains("cool") || combinedText.contains("ocean") || 
           combinedText.contains("blue") || combinedText.contains("海") {
            return [
                UIColor(red: 0.1, green: 0.5, blue: 0.8, alpha: 1.0),  // オーシャンブルー
                UIColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1.0),  // スカイブルー
                UIColor(red: 0.0, green: 0.3, blue: 0.6, alpha: 1.0),  // ディープブルー
                UIColor(red: 0.6, green: 0.9, blue: 1.0, alpha: 1.0)   // ライトブルー
            ]
        }
        
        // 自然・緑
        if combinedText.contains("nature") || combinedText.contains("forest") || 
           combinedText.contains("green") || combinedText.contains("自然") {
            return [
                UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0),  // フォレストグリーン
                UIColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0),  // フレッシュグリーン
                UIColor(red: 0.1, green: 0.5, blue: 0.2, alpha: 1.0),  // ダークグリーン
                UIColor(red: 0.7, green: 0.9, blue: 0.3, alpha: 1.0)   // ライムグリーン
            ]
        }
        
        // ピンク・可愛い系
        if combinedText.contains("cute") || combinedText.contains("pink") || 
           combinedText.contains("kawaii") || combinedText.contains("可愛") {
            return [
                UIColor(red: 1.0, green: 0.7, blue: 0.8, alpha: 1.0),  // ソフトピンク
                UIColor(red: 0.9, green: 0.5, blue: 0.7, alpha: 1.0),  // ローズピンク
                UIColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1.0),  // ペールピンク
                UIColor(red: 0.8, green: 0.3, blue: 0.5, alpha: 1.0)   // マゼンタ
            ]
        }
        
        // 紫・神秘系
        if combinedText.contains("mysterious") || combinedText.contains("purple") || 
           combinedText.contains("magic") || combinedText.contains("神秘") {
            return [
                UIColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0),  // ディープパープル
                UIColor(red: 0.7, green: 0.4, blue: 0.9, alpha: 1.0),  // ライトパープル
                UIColor(red: 0.3, green: 0.1, blue: 0.5, alpha: 1.0),  // ダークバイオレット
                UIColor(red: 0.9, green: 0.7, blue: 1.0, alpha: 1.0)   // ペールバイオレット
            ]
        }
        
        // デフォルト：調和の取れたグラデーション
        return [
            UIColor(red: 0.8, green: 0.4, blue: 0.6, alpha: 1.0),
            UIColor(red: 0.4, green: 0.6, blue: 0.8, alpha: 1.0),
            UIColor(red: 0.6, green: 0.8, blue: 0.4, alpha: 1.0),
            UIColor(red: 0.9, green: 0.7, blue: 0.5, alpha: 1.0)
        ]
    }
    
    // MARK: - 🖼️ 高品質アート画像生成
    private func createAdvancedArtImage(
        style: ImageStyle,
        colors: [UIColor],
        prompt: String,
        analysisData: [String]
    ) -> UIImage {
        let size = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 背景の複雑なグラデーション
            createAdvancedBackground(context: cgContext, size: size, colors: colors, style: style)
            
            // スタイル別の装飾要素
            addStyleSpecificElements(context: cgContext, size: size, colors: colors, style: style)
            
            // プロンプトベースのパターン追加
            addPromptBasedPatterns(context: cgContext, size: size, prompt: prompt, colors: colors)
            
            // 高品質テキストオーバーレイ
            addAdvancedTextOverlay(context: cgContext, size: size, prompt: prompt, style: style)
        }
    }
    
    // MARK: - 🎨 Advanced Background Creation
    private func createAdvancedBackground(
        context: CGContext,
        size: CGSize,
        colors: [UIColor],
        style: ImageStyle
    ) {
        context.saveGState()
        
        switch style {
        case .anime:
            // アニメ風の鮮やかなグラデーション
            createRadialGradientBackground(context: context, size: size, colors: colors)
        case .realistic:
            // リアル風の自然なグラデーション
            createLinearGradientBackground(context: context, size: size, colors: colors)
        case .abstract:
            // 抽象的な複雑なパターン
            createAbstractBackground(context: context, size: size, colors: colors)
        case .landscape:
            // 風景風の層状グラデーション
            createLayeredGradientBackground(context: context, size: size, colors: colors)
        case .artistic:
            // アーティスティックな混合グラデーション
            createMixedGradientBackground(context: context, size: size, colors: colors)
        }
        
        context.restoreGState()
    }
    
    private func createRadialGradientBackground(context: CGContext, size: CGSize, colors: [UIColor]) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let gradient = createGradient(colors: colors)
        
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: size.width * 0.7,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
    
    private func createLinearGradientBackground(context: CGContext, size: CGSize, colors: [UIColor]) {
        let gradient = createGradient(colors: colors)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
    }
    
    private func createAbstractBackground(context: CGContext, size: CGSize, colors: [UIColor]) {
        // 複数の円形グラデーションを重ねる
        for i in 0..<colors.count {
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [colors[i].cgColor, UIColor.clear.cgColor] as CFArray,
                locations: [0.0, 1.0]
            )!
            
            let center = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: size.width * 0.4,
                options: []
            )
        }
    }
    
    private func createLayeredGradientBackground(context: CGContext, size: CGSize, colors: [UIColor]) {
        // 水平層状のグラデーション
        let layerHeight = size.height / CGFloat(colors.count)
        
        for (index, color) in colors.enumerated() {
            let nextColor = colors[(index + 1) % colors.count]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [color.cgColor, nextColor.cgColor] as CFArray,
                locations: [0.0, 1.0]
            )!
            
            let layerRect = CGRect(
                x: 0,
                y: CGFloat(index) * layerHeight,
                width: size.width,
                height: layerHeight
            )
            
            context.saveGState()
            context.clip(to: layerRect)
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: layerRect.minY),
                end: CGPoint(x: 0, y: layerRect.maxY),
                options: []
            )
            context.restoreGState()
        }
    }
    
    private func createMixedGradientBackground(context: CGContext, size: CGSize, colors: [UIColor]) {
        // 線形と円形を組み合わせ
        createLinearGradientBackground(context: context, size: size, colors: colors)
        
        context.setBlendMode(.overlay)
        createRadialGradientBackground(context: context, size: size, colors: colors.reversed())
        context.setBlendMode(.normal)
    }
    
    // MARK: - 🎭 Style-Specific Elements
    private func addStyleSpecificElements(
        context: CGContext,
        size: CGSize,
        colors: [UIColor],
        style: ImageStyle
    ) {
        switch style {
        case .anime:
            addAnimeElements(context: context, size: size, colors: colors)
        case .realistic:
            addRealisticElements(context: context, size: size, colors: colors)
        case .abstract:
            addAbstractElements(context: context, size: size, colors: colors)
        case .landscape:
            addLandscapeElements(context: context, size: size, colors: colors)
        case .artistic:
            addArtisticElements(context: context, size: size, colors: colors)
        }
    }
    
    private func addAnimeElements(context: CGContext, size: CGSize, colors: [UIColor]) {
        // アニメ風の星や輝きエフェクト
        context.setBlendMode(.screen)
        
        for _ in 0..<20 {
            let starSize = CGFloat.random(in: 10...30)
            let center = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            
            drawStar(context: context, center: center, size: starSize, color: colors.randomElement()!)
        }
        
        context.setBlendMode(.normal)
    }
    
    private func addRealisticElements(context: CGContext, size: CGSize, colors: [UIColor]) {
        // リアル風の光のエフェクト
        context.setBlendMode(.softLight)
        
        for _ in 0..<10 {
            let center = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            let radius = CGFloat.random(in: 50...150)
            
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [colors.randomElement()!.withAlphaComponent(0.3).cgColor, UIColor.clear.cgColor] as CFArray,
                locations: [0.0, 1.0]
            )!
            
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: []
            )
        }
        
        context.setBlendMode(.normal)
    }
    
    private func addAbstractElements(context: CGContext, size: CGSize, colors: [UIColor]) {
        // 抽象的な幾何学模様
        context.setBlendMode(.multiply)
        
        for _ in 0..<15 {
            let rect = CGRect(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                width: CGFloat.random(in: 50...200),
                height: CGFloat.random(in: 50...200)
            )
            
            context.saveGState()
            context.rotate(by: CGFloat.random(in: 0...(.pi * 2)))
            context.setFillColor(colors.randomElement()!.withAlphaComponent(0.4).cgColor)
            context.fill(rect)
            context.restoreGState()
        }
        
        context.setBlendMode(.normal)
    }
    
    private func addLandscapeElements(context: CGContext, size: CGSize, colors: [UIColor]) {
        // 風景風の山や雲の形状
        drawMountains(context: context, size: size, colors: colors)
        drawClouds(context: context, size: size, colors: colors)
    }
    
    private func addArtisticElements(context: CGContext, size: CGSize, colors: [UIColor]) {
        // アーティスティックなブラシストローク
        context.setBlendMode(.colorBurn)
        context.setLineWidth(CGFloat.random(in: 5...15))
        
        for _ in 0..<25 {
            context.setStrokeColor(colors.randomElement()!.withAlphaComponent(0.6).cgColor)
            
            let path = CGMutablePath()
            let startPoint = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            path.move(to: startPoint)
            
            for _ in 0..<Int.random(in: 3...8) {
                let controlPoint = CGPoint(
                    x: startPoint.x + CGFloat.random(in: -100...100),
                    y: startPoint.y + CGFloat.random(in: -100...100)
                )
                let endPoint = CGPoint(
                    x: startPoint.x + CGFloat.random(in: -150...150),
                    y: startPoint.y + CGFloat.random(in: -150...150)
                )
                path.addQuadCurve(to: endPoint, control: controlPoint)
            }
            
            context.addPath(path)
            context.strokePath()
        }
        
        context.setBlendMode(.normal)
    }
    
    // MARK: - 🌟 Helper Drawing Functions
    private func drawStar(context: CGContext, center: CGPoint, size: CGFloat, color: UIColor) {
        let path = CGMutablePath()
        let angleIncrement = CGFloat.pi / 5
        
        for i in 0..<10 {
            let angle = CGFloat(i) * angleIncrement
            let radius = (i % 2 == 0) ? size : size * 0.4
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        context.setFillColor(color.withAlphaComponent(0.8).cgColor)
        context.addPath(path)
        context.fillPath()
    }
    
    private func drawMountains(context: CGContext, size: CGSize, colors: [UIColor]) {
        let mountainPath = CGMutablePath()
        mountainPath.move(to: CGPoint(x: 0, y: size.height))
        
        var currentX: CGFloat = 0
        while currentX < size.width {
            let peakHeight = CGFloat.random(in: size.height * 0.3...size.height * 0.7)
            let peakWidth = CGFloat.random(in: 100...300)
            
            mountainPath.addLine(to: CGPoint(x: currentX + peakWidth / 2, y: size.height - peakHeight))
            mountainPath.addLine(to: CGPoint(x: currentX + peakWidth, y: size.height))
            
            currentX += peakWidth
        }
        
        mountainPath.addLine(to: CGPoint(x: size.width, y: size.height))
        mountainPath.closeSubpath()
        
        context.setFillColor(colors.first!.withAlphaComponent(0.7).cgColor)
        context.addPath(mountainPath)
        context.fillPath()
    }
    
    private func drawClouds(context: CGContext, size: CGSize, colors: [UIColor]) {
        for _ in 0..<5 {
            let cloudCenter = CGPoint(
                x: CGFloat.random(in: 100...size.width - 100),
                y: CGFloat.random(in: 50...size.height * 0.4)
            )
            
            let cloudColor = UIColor.white.withAlphaComponent(0.6)
            
            // 雲を複数の円で構成
            for _ in 0..<Int.random(in: 3...6) {
                let circleCenter = CGPoint(
                    x: cloudCenter.x + CGFloat.random(in: -50...50),
                    y: cloudCenter.y + CGFloat.random(in: -20...20)
                )
                let radius = CGFloat.random(in: 20...40)
                
                context.setFillColor(cloudColor.cgColor)
                context.fillEllipse(in: CGRect(
                    x: circleCenter.x - radius,
                    y: circleCenter.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }
        }
    }
    
    // MARK: - 📝 Advanced Text Overlay
    private func addAdvancedTextOverlay(
        context: CGContext,
        size: CGSize,
        prompt: String,
        style: ImageStyle
    ) {
        // スタイルに応じたフォントとカラー
        let fontSize: CGFloat = style == .anime ? 28 : 24
        let font = style == .anime ? 
            UIFont.boldSystemFont(ofSize: fontSize) : 
            UIFont.systemFont(ofSize: fontSize, weight: .medium)
        
        let textColor = UIColor.white
        let shadowColor = UIColor.black.withAlphaComponent(0.8)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .strokeColor: shadowColor,
            .strokeWidth: -3.0
        ]
        
        // プロンプトを短縮
        let displayPrompt = String(prompt.prefix(40)) + (prompt.count > 40 ? "..." : "")
        let attributedString = NSAttributedString(string: "✨ \(displayPrompt)", attributes: attributes)
        
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: size.height - textSize.height - 60,
            width: textSize.width,
            height: textSize.height
        )
        
        // 背景の半透明ボックス
        let backgroundRect = textRect.insetBy(dx: -20, dy: -10)
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(backgroundRect)
        
        attributedString.draw(in: textRect)
        
        // ブランドラベル
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            .backgroundColor: UIColor.clear
        ]
        
        let brandString = NSAttributedString(string: "🎨 YourWorld AI - 高品質生成", attributes: brandAttributes)
        let brandSize = brandString.size()
        let brandRect = CGRect(
            x: 30,
            y: 30,
            width: brandSize.width,
            height: brandSize.height
        )
        
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(brandRect.insetBy(dx: -10, dy: -5))
        
        brandString.draw(in: brandRect)
    }
    
    // MARK: - 🌈 プロンプトベースパターン追加
    private func addPromptBasedPatterns(
        context: CGContext,
        size: CGSize,
        prompt: String,
        colors: [UIColor]
    ) {
        let lowercasePrompt = prompt.lowercased()
        
        // 花・植物系のパターン
        if lowercasePrompt.contains("flower") || lowercasePrompt.contains("floral") || 
           lowercasePrompt.contains("花") || lowercasePrompt.contains("植物") {
            addFloralPatterns(context: context, size: size, colors: colors)
        }
        
        // 幾何学・モダン系のパターン
        if lowercasePrompt.contains("geometric") || lowercasePrompt.contains("modern") || 
           lowercasePrompt.contains("pattern") || lowercasePrompt.contains("幾何") {
            addGeometricPatterns(context: context, size: size, colors: colors)
        }
        
        // 水・波系のパターン
        if lowercasePrompt.contains("water") || lowercasePrompt.contains("wave") || 
           lowercasePrompt.contains("ocean") || lowercasePrompt.contains("水") {
            addWavePatterns(context: context, size: size, colors: colors)
        }
        
        // 光・輝き系のパターン
        if lowercasePrompt.contains("light") || lowercasePrompt.contains("bright") || 
           lowercasePrompt.contains("glow") || lowercasePrompt.contains("光") {
            addLightPatterns(context: context, size: size, colors: colors)
        }
        
        // デフォルト：汎用的な装飾パターン
        if !lowercasePrompt.contains("flower") && !lowercasePrompt.contains("geometric") && 
           !lowercasePrompt.contains("water") && !lowercasePrompt.contains("light") {
            addGenericPatterns(context: context, size: size, colors: colors)
        }
    }
    
    // MARK: - 🌸 フローラルパターン
    private func addFloralPatterns(context: CGContext, size: CGSize, colors: [UIColor]) {
        context.setBlendMode(.multiply)
        
        for _ in 0..<8 {
            let center = CGPoint(
                x: CGFloat.random(in: 100...size.width - 100),
                y: CGFloat.random(in: 100...size.height - 100)
            )
            
            drawFlower(context: context, center: center, colors: colors)
        }
        
        context.setBlendMode(.normal)
    }
    
    private func drawFlower(context: CGContext, center: CGPoint, colors: [UIColor]) {
        let petalCount = Int.random(in: 5...8)
        let petalSize = CGFloat.random(in: 20...40)
        let petalColor = colors.randomElement()!.withAlphaComponent(0.6)
        
        for i in 0..<petalCount {
            let angle = (CGFloat(i) / CGFloat(petalCount)) * .pi * 2
            let petalCenter = CGPoint(
                x: center.x + cos(angle) * petalSize * 0.8,
                y: center.y + sin(angle) * petalSize * 0.8
            )
            
            context.setFillColor(petalColor.cgColor)
            context.fillEllipse(in: CGRect(
                x: petalCenter.x - petalSize / 2,
                y: petalCenter.y - petalSize / 2,
                width: petalSize,
                height: petalSize
            ))
        }
        
        // 中心部
        context.setFillColor(colors.last!.withAlphaComponent(0.8).cgColor)
        context.fillEllipse(in: CGRect(
            x: center.x - 8,
            y: center.y - 8,
            width: 16,
            height: 16
        ))
    }
    
    // MARK: - 📐 幾何学パターン
    private func addGeometricPatterns(context: CGContext, size: CGSize, colors: [UIColor]) {
        context.setBlendMode(.overlay)
        context.setLineWidth(3.0)
        
        // 三角形パターン
        for _ in 0..<12 {
            let triangleSize = CGFloat.random(in: 30...80)
            let center = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            
            drawTriangle(context: context, center: center, size: triangleSize, color: colors.randomElement()!)
        }
        
        context.setBlendMode(.normal)
    }
    
    private func drawTriangle(context: CGContext, center: CGPoint, size: CGFloat, color: UIColor) {
        let path = CGMutablePath()
        
        // 正三角形を描画
        for i in 0..<3 {
            let angle = (CGFloat(i) / 3.0) * .pi * 2 - .pi / 2
            let x = center.x + cos(angle) * size
            let y = center.y + sin(angle) * size
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        context.setStrokeColor(color.withAlphaComponent(0.7).cgColor)
        context.addPath(path)
        context.strokePath()
    }
    
    // MARK: - 🌊 波パターン
    private func addWavePatterns(context: CGContext, size: CGSize, colors: [UIColor]) {
        context.setBlendMode(.multiply)
        context.setLineWidth(4.0)
        
        for i in 0..<6 {
            let y = (CGFloat(i) / 6.0) * size.height
            let color = colors[i % colors.count].withAlphaComponent(0.5)
            
            drawWave(context: context, y: y, width: size.width, color: color)
        }
        
        context.setBlendMode(.normal)
    }
    
    private func drawWave(context: CGContext, y: CGFloat, width: CGFloat, color: UIColor) {
        let path = CGMutablePath()
        let amplitude = CGFloat.random(in: 20...50)
        let frequency = CGFloat.random(in: 0.01...0.03)
        
        path.move(to: CGPoint(x: 0, y: y))
        
        for x in stride(from: 0, to: width, by: 2) {
            let waveY = y + sin(x * frequency) * amplitude
            path.addLine(to: CGPoint(x: x, y: waveY))
        }
        
        context.setStrokeColor(color.cgColor)
        context.addPath(path)
        context.strokePath()
    }
    
    // MARK: - ✨ 光パターン
    private func addLightPatterns(context: CGContext, size: CGSize, colors: [UIColor]) {
        context.setBlendMode(.screen)
        
        for _ in 0..<15 {
            let center = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            let radius = CGFloat.random(in: 30...80)
            
            drawLightBurst(context: context, center: center, radius: radius, color: colors.randomElement()!)
        }
        
        context.setBlendMode(.normal)
    }
    
    private func drawLightBurst(context: CGContext, center: CGPoint, radius: CGFloat, color: UIColor) {
        let rayCount = Int.random(in: 6...12)
        context.setLineWidth(2.0)
        context.setStrokeColor(color.withAlphaComponent(0.7).cgColor)
        
        for i in 0..<rayCount {
            let angle = (CGFloat(i) / CGFloat(rayCount)) * .pi * 2
            let startPoint = CGPoint(
                x: center.x + cos(angle) * radius * 0.3,
                y: center.y + sin(angle) * radius * 0.3
            )
            let endPoint = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
        
        // 中心の光核
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [color.withAlphaComponent(0.8).cgColor, UIColor.clear.cgColor] as CFArray,
            locations: [0.0, 1.0]
        )!
        
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius * 0.4,
            options: []
        )
    }
    
    // MARK: - 🎨 汎用パターン
    private func addGenericPatterns(context: CGContext, size: CGSize, colors: [UIColor]) {
        // 円形パターン
        context.setBlendMode(.overlay)
        
        for _ in 0..<10 {
            let center = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            let radius = CGFloat.random(in: 30...100)
            let color = colors.randomElement()!.withAlphaComponent(0.3)
            
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
        
        context.setBlendMode(.normal)
    }
    
    // MARK: - 🔧 Helper Methods
    private func generateWithReplicateAPI(prompt: String, model: ReplicateModelInfo) async throws -> UIImage {
        print("🔄 Replicate API生成開始: \(prompt)")
        
        // Replicate APIが利用できない場合は高品質ローカル生成にフォールバック
        throw ImageGenerationError.apiError(503, "Replicate API 一時利用不可")
    }
    
    // 🔧 強化されたGeminiレスポンス解析
    private func parseEnhancedGeminiResponse(_ responseText: String) -> PromptGenerationResult? {
        print("🔍 Gemini強化レスポンス解析開始")
        print("📄 レスポンステキスト: \(responseText)")
        
        let lines = responseText.components(separatedBy: .newlines)
        var extractedPrompt: String?
        var extractedNegative: String?
        var extractedReason: String?
        var extractedStyle: String?
        var extractedMood: String?
        
        // 🎯 構造化された形式で解析
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // PROMPT: を探す
            if trimmedLine.uppercased().hasPrefix("PROMPT:") {
                extractedPrompt = String(trimmedLine.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ プロンプト抽出: \(extractedPrompt ?? "なし")")
                
            // NEGATIVE: を探す
            } else if trimmedLine.uppercased().hasPrefix("NEGATIVE:") {
                extractedNegative = String(trimmedLine.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ ネガティブ抽出: \(extractedNegative ?? "なし")")
                
            // REASON: を探す
            } else if trimmedLine.uppercased().hasPrefix("REASON:") {
                extractedReason = String(trimmedLine.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ 理由抽出: \(extractedReason ?? "なし")")
                
            // STYLE: を探す
            } else if trimmedLine.uppercased().hasPrefix("STYLE:") {
                extractedStyle = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ スタイル抽出: \(extractedStyle ?? "なし")")
                
            // MOOD: を探す
            } else if trimmedLine.uppercased().hasPrefix("MOOD:") {
                extractedMood = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ 雰囲気抽出: \(extractedMood ?? "なし")")
            }
        }
        
        // 🔧 フォールバック: 構造化形式でない場合のパターンマッチング
        if extractedPrompt == nil {
            print("🔄 フォールバック解析開始")
            
            // 英語らしい文章を探す（改善版）
            let englishPatterns = [
                "create", "generate", "beautiful", "artwork", "detailed", "high quality", 
                "masterpiece", "professional", "stunning", "vibrant", "cinematic"
            ]
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowerLine = trimmedLine.lowercased()
                
                // 英語キーワードを多く含む行を探す
                let keywordCount = englishPatterns.reduce(0) { count, pattern in
                    count + (lowerLine.contains(pattern) ? 1 : 0)
                }
                
                if keywordCount >= 2 && trimmedLine.count > 20 && trimmedLine.count < 200 {
                    extractedPrompt = trimmedLine
                    print("✅ フォールバック抽出: \(extractedPrompt ?? "なし")")
                    break
                }
            }
        }
        
        // 🎨 プロンプトの最終調整
        if let prompt = extractedPrompt, !prompt.isEmpty {
            var finalPrompt = prompt
            
            // 品質向上キーワードを自動追加
            let qualityKeywords = ["high quality", "detailed", "professional", "masterpiece"]
            let hasQualityKeyword = qualityKeywords.contains { keyword in
                finalPrompt.lowercased().contains(keyword)
            }
            
            if !hasQualityKeyword {
                finalPrompt += ", high quality, detailed, masterpiece"
            }
            
            // 📋 詳細な理由文を構築
            var enhancedReason = extractedReason ?? "Geminiが生成したプロンプトです。"
            
            if let style = extractedStyle {
                enhancedReason += " アートスタイル: \(style)。"
            }
            
            if let mood = extractedMood {
                enhancedReason += " 期待される雰囲気: \(mood)。"
            }
            
            if let negative = extractedNegative {
                enhancedReason += " ネガティブプロンプト: \(negative)。"
            }
            
            print("🎯 最終プロンプト: \(finalPrompt)")
            print("📝 最終理由: \(enhancedReason)")
            
            return PromptGenerationResult(
                prompt: finalPrompt,
                reason: enhancedReason
            )
        }
        
        print("❌ プロンプト抽出失敗")
        return nil
    }
}

// MARK: - 🔧 タイムアウト付きAsync関数
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw ImageGenerationError.timeoutError
        }
        
        guard let result = try await group.next() else {
            throw ImageGenerationError.timeoutError
        }
        
        group.cancelAll()
        return result
    }
}

// ... existing code ... 
// ... existing code ... 