//
//  DirectGenerationView.swift
//  yourworldai
//
//  Created by [Your Name/AI] on [Date]
//

import SwiftUI

struct DirectGenerationView: View {
    // MARK: - Services
    @StateObject private var imageGenerationService = ImageGenerationService()
    
    // MARK: - State Variables
    @State private var promptText: String = ""
    @State private var isGenerating: Bool = false
    @State private var generatedImage: UIImage?
    @State private var errorMessage: String?
    @State private var selectedModelId: UUID? = ReplicateConfig.defaultModel?.id

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    modelSpecificPromptInput
                    
                    Picker("生成モデル", selection: $selectedModelId) {
                        ForEach(ReplicateConfig.availableModels) { model in 
                            Text(model.name).tag(model.id as UUID?) 
                        }
                    }
                    .pickerStyle(.menu)

                    Button("画像を生成する") {
                        hideKeyboard()
                        Task { await generateImage() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating || selectedModelId == nil || shouldDisableButton)

                    generationResultView
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("直接生成")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var modelSpecificPromptInput: some View {
        if let model = ReplicateConfig.availableModels.first(where: { $0.id == selectedModelId }) {
            switch model.inputType {
            case .textToImage:
                VStack(alignment: .leading, spacing: 8) {
                    Text("プロンプトを入力してください:")
                        .font(.headline)
                    
                    TextEditor(text: $promptText)
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.5), width: 1)
                        .cornerRadius(5)
                }
                
            case .imagen3:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Imagen 3用のプロンプトを入力してください:")
                        .font(.headline)
                    
                    TextEditor(text: $promptText)
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.5), width: 1)
                        .cornerRadius(5)
                    
                    Text("Imagen 3は自然言語での詳細な説明に優れています。")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
            case .googleVertexAI:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Google純正Imagen 3用のプロンプトを入力してください:")
                        .font(.headline)
                    
                    TextEditor(text: $promptText)
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.5), width: 1)
                        .cornerRadius(5)
                    
                    Text("Google純正Imagen 3は最高品質の画像生成が可能です。自然言語で詳細に記述してください。")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
            case .conjunction:
                Text("選択中のモデルはテキストプロンプトを使用しません。")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    @ViewBuilder
    private var generationResultView: some View {
        if isGenerating {
            VStack {
                ProgressView().padding(.top)
                Text("画像を生成中...").font(.caption).foregroundColor(.gray)
            }
        } else {
            VStack {
                if let errorMsg = errorMessage {
                    Text("エラー: \(errorMsg)")
                        .foregroundColor(.red)
                        .padding()
                }
                
                if let img = generatedImage {
                    VStack {
                        Text("生成された画像:")
                            .font(.headline)
                            .padding(.top)
                        
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 350, maxHeight: 350)
                            .cornerRadius(10)
                            .padding(.bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var shouldDisableButton: Bool {
        guard let model = ReplicateConfig.availableModels.first(where: { $0.id == selectedModelId }) else {
            return true
        }
        
        switch model.inputType {
        case .textToImage, .imagen3, .googleVertexAI:
            return promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .conjunction:
            return false // conjunctionタイプはプロンプト不要
        }
    }
    
    // MARK: - Helper Functions
    
    private func hideKeyboard() { 
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) 
    }

    @MainActor
    private func generateImage() async {
        guard let currentSelectedModelId = selectedModelId,
              let selectedModel = ReplicateConfig.availableModels.first(where: { $0.id == currentSelectedModelId }) else { 
            errorMessage = "生成モデルが選択されていません。"
            return
        }
        
        isGenerating = true
        generatedImage = nil
        errorMessage = nil
        
        do {
            let result = try await imageGenerationService.generateDirectly(
                prompt: promptText,
                model: selectedModel
            )
            
            generatedImage = result.image
            
            print("--- 直接生成成功 ---")
            print("プロンプト: \(result.prompt)")
            print("理由: \(result.reason ?? "なし")")
            
        } catch {
            errorMessage = error.localizedDescription
            print("直接生成エラー: \(error)")
        }
        
        isGenerating = false
    }
}

#Preview { 
    DirectGenerationView() 
}
