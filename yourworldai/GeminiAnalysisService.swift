//
//  GeminiAnalysisService.swift
//  yourworldai
//

import Foundation

// MARK: - Gemini分析サービス
@MainActor
class GeminiAnalysisService: ObservableObject {
    
    // MARK: - 画像分析
    func analyzeImage(imageData: Data) async -> String? {
        guard !GeminiConfig.apiKey.isEmpty, 
              GeminiConfig.apiKey != "YOUR_GEMINI_API_KEY" else {
            print("Gemini APIキーが設定されていません")
            return nil
        }
        
        guard let base64Image = imageData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("画像のBase64エンコードに失敗")
            return nil
        }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(GeminiConfig.visionModel):generateContent?key=\(GeminiConfig.apiKey)"
        guard let url = URL(string: urlString) else {
            print("無効なURL: \(urlString)")
            return nil
        }
        
        let requestPayload = GeminiGenerateContentRequest(
            contents: [
                .init(parts: [
                    .init(text: "この画像について詳しく説明してください。アート、スタイル、色彩、構図、雰囲気などの視覚的特徴を含めて日本語で回答してください。"),
                    .init(mimeType: "image/jpeg", data: base64Image)
                ])
            ]
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestPayload)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("無効なレスポンス")
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                print("Gemini API エラー - Status: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("エラー詳細: \(errorString)")
                }
                return nil
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
            return geminiResponse.candidates?.first?.content?.parts?.first?.text
            
        } catch {
            print("Gemini API 呼び出しエラー: \(error)")
            return nil
        }
    }
    
    // MARK: - 複数画像の並列分析
    func analyzeImages(_ imageDatas: [Data]) async -> [String?] {
        await withTaskGroup(of: (Int, String?).self, returning: [String?].self) { group in
            var results: [String?] = Array(repeating: nil, count: imageDatas.count)
            
            for (index, imageData) in imageDatas.enumerated() {
                group.addTask { [weak self] in
                    let description = await self?.analyzeImage(imageData: imageData)
                    return (index, description)
                }
            }
            
            for await (index, description) in group {
                results[index] = description
            }
            
            return results
        }
    }
} 