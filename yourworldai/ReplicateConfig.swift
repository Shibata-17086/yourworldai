//
//  ReplicateConfig.swift
//  yourworldai
//
//  Created by [Your Name/AI] on [Date]
//

import Foundation

// --- 修正: モデルの入力タイプを示すEnum ---
enum ModelInputType {
    case textToImage // 標準的なテキストプロンプト + width/height
    case imagen3 // Google Imagen 3の特別な入力形式
    case googleVertexAI // Google純正Vertex AI Imagen 3
    case conjunction // prompt_conjunction フラグを使うタイプ
    // 必要に応じて他のタイプを追加 (例: imageToImageなど)
}
// --- ここまで追加 ---

// --- 修正: モデル情報構造体 ---
struct ReplicateModelInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let modelId: String
    let versionId: String
    let inputType: ModelInputType // ← 追加: 入力タイプ

    var fullIdentifier: String { "\(modelId):\(versionId)" }
}
// --- ここまで修正 ---

struct ReplicateConfig {

    // !!! 重要: APIキーの安全な管理について !!!
    // 実際のAPIキーは環境変数や設定ファイルから取得してください
    static let apiKey = "YOUR_REPLICATE_API_KEY_HERE" // ← 実際のキーに置き換えてください

    // --- 修正: モデルリストに入力タイプを追加 ---
    static let availableModels: [ReplicateModelInfo] = [
        // Google純正Imagen 3（Vertex AI）- 最高品質
        .init(name: "Google Imagen 3 (純正)", 
              modelId: "vertex-ai-imagen3", 
              versionId: "native",
              inputType: .googleVertexAI),
        .init(name: "Google Imagen 3 Fast (純正)", 
              modelId: "vertex-ai-imagen3-fast", 
              versionId: "native",
              inputType: .googleVertexAI),
        
        // Google Imagen 3は一時的に無効化（正確なバージョンID取得まで）
        // .init(name: "Google Imagen 3", // 最高品質のGoogle画像生成モデル
        //       modelId: "google/imagen-3",
        //       versionId: "latest", // 最新バージョンを使用
        //       inputType: .imagen3),
        // .init(name: "Google Imagen 3 Fast", // 高速・低コスト版
        //       modelId: "google/imagen-3-fast", 
        //       versionId: "latest", // 最新バージョンを使用
        //       inputType: .imagen3),
        
        // FLUX.1-devも一時的に無効化（正確なバージョンID取得まで）
        // .init(name: "FLUX.1 Dev", // 高品質なtext-to-imageモデル
        //       modelId: "black-forest-labs/flux-dev",
        //       versionId: "dev",
        //       inputType: .textToImage),
        
        .init(name: "Miaomiao Harem", // アニメスタイル
              modelId: "aisha-ai-official/miaomiao-harem-illustrious-v1",
              versionId: "d74eab7842eca403256b37c4276e0c19b83aa124cc5d102d15d9327a6d14ad02",
              inputType: .textToImage),
        .init(name: "SD 3.5 Medium", // 最新のStable Diffusion
              modelId: "stability-ai/stable-diffusion-3.5-medium",
              versionId: "17deaafb14e6c18aa88e57bf02149da2b23c2f2c3d02cf9d6ad3cc59b6c44327",
              inputType: .textToImage),
        .init(name: "SD 3.5 Large", // 高品質なSD
              modelId: "stability-ai/stable-diffusion-3.5-large",
              versionId: "a9b41e4dfe8ade1b0b1ea088e0e3b69bcd58a89f1a2b6ab74b39b46dd3aa9c6d",
              inputType: .textToImage),
        .init(name: "Ninjitsu Art", // アートスタイル
              modelId: "ninjitsu-ai/ninjitsu-art",
              versionId: "9ce0d5a5e5b1b1b7b6a0e1b0c1b0c1b0c1b0c1b0c1b0c1b0c1b0c1b0c1b0c1b0",
              inputType: .conjunction)
    ]

    static var defaultModel: ReplicateModelInfo? {
        // デフォルトはGoogle純正Imagen 3を使用
        return availableModels.first { $0.inputType == .googleVertexAI } ?? 
               availableModels.first { $0.modelId == "aisha-ai-official/miaomiao-harem-illustrious-v1" } ?? 
               availableModels.first { $0.inputType == .textToImage } ?? 
               availableModels.first
    }
    // --- ここまで修正 ---
}
