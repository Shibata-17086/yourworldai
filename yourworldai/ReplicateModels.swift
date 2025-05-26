//
//  ReplicateModels.swift
//  yourworldai
//
//  Created by [Your Name/AI] on [Date]
//

import Foundation

// --- Replicate API レスポンス用 Codable 構造体 (変更なし) ---
struct ReplicatePredictionResponse: Codable {
    let id: String
    let version: String?
    let urls: Urls?
    let status: String
    let input: InputData? // レスポンスのinputはモデルによって異なる可能性あり (汎用的な型にするか要検討)
    let output: [URL]?
    let error: String?
    let logs: String?
    let metrics: Metrics?

    struct Urls: Codable { let get: URL; let cancel: URL? }
    // レスポンスに含まれるInputの仮定義 (より厳密にするならAnyCodableなどを使う)
    struct InputData: Codable {
        let prompt: String?
        let width: Int?
        let height: Int?
        let num_outputs: Int?
        let prompt_conjunction: Bool?
    }
    struct Metrics: Codable { let predict_time: Double? }
}


// --- Replicate API リクエスト用 ---

// モデルタイプごとの具体的なInput構造体 (変更なし)
struct TextToImageInput: Codable { // Codableのまま (Encodableだけでも良い)
    let prompt: String
    var width: Int? = 1024
    var height: Int? = 1024
    var num_outputs: Int? = 1
}

// Google Imagen 3用の拡張Input構造体
struct Imagen3Input: Codable {
    let prompt: String
    var aspect_ratio: String? = "1:1" // 1:1, 3:4, 4:3, 9:16, 16:9
    var num_outputs: Int? = 1
    var negative_prompt: String? = nil
    var output_format: String? = "png" // png, jpg, webp
    var output_quality: Int? = 80 // 1-100
    var disable_safety_checker: Bool? = false
}

struct ConjunctionInput: Codable { // Codableのまま (Encodableだけでも良い)
    let prompt_conjunction: Bool
}

// InputデータをラップするEnum (変更なし)
enum ReplicateInputData: Encodable {
    case textToImage(TextToImageInput)
    case imagen3(Imagen3Input) // Imagen 3用を追加
    case conjunction(ConjunctionInput)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .textToImage(let input): try container.encode(input)
        case .imagen3(let input): try container.encode(input)
        case .conjunction(let input): try container.encode(input)
        }
    }
}

// --- 修正: リクエスト全体の構造体 ---
// プロトコル準拠を Codable から Encodable に変更
struct ReplicatePredictionRequest: Encodable {
    let version: String // versionIdのみを渡す
    let input: ReplicateInputData // 型はEnumのまま
}
// --- ここまで修正 ---
