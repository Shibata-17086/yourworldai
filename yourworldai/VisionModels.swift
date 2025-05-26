//
//  VisionModels.swift
//  yourworldai
//
//  Created by [Your Name/AI] on [Date]
//

import Foundation

// Vision API (images:annotate) のレスポンス構造体 (ラベル検出用)
struct VisionAnnotateResponse: Codable {
    let responses: [VisionImageAnnotationResponse]?
}

struct VisionImageAnnotationResponse: Codable {
    let labelAnnotations: [LabelAnnotation]?
    let error: VisionError? // エラー情報が含まれる場合
}

struct LabelAnnotation: Codable {
    let mid: String? // Machine ID (知識グラフID)
    let description: String? // ラベル名 (例: "Cat", "Dog", "Sky")
    let score: Float? // 信頼度スコア (0.0 ~ 1.0)
    let topicality: Float?
}

// Vision APIのエラーレスポンス構造体 (簡易版)
struct VisionError: Codable {
    let code: Int?
    let message: String?
}
