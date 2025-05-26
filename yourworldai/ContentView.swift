//
//  ContentView.swift
//  yourworldai
//
//  Created by 柴田紘希 on 2025/04/12.
//

import SwiftUI
import PhotosUI

// ImageItem, SwipeDirection (変更なし)
struct ImageItem: Identifiable {
    let id = UUID()
    let imageData: Data
    var uiImage: UIImage? { UIImage(data: imageData) }
    var description: String?
}
enum SwipeDirection { case like, unlike }

struct ContentView: View {
    // MARK: - Services
    @StateObject private var imageGenerationService = ImageGenerationService()
    @StateObject private var geminiAnalysisService = GeminiAnalysisService()
    
    // MARK: - State Variables
    @State private var imageItems: [ImageItem] = []
    @State private var swipeResults: [UUID: (direction: SwipeDirection, description: String?)] = [:]
    @State private var showGenerateButton: Bool = false
    @State private var generatedPrompt: String = ""
    @State private var generatedReason: String = ""
    @State private var promptHistory: [String] = []
    @State private var isGenerating: Bool = false
    @State private var generatedImage: UIImage?
    @State private var errorMessage: String?
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isLoadingImages: Bool = false
    @State private var selectedModelId: UUID? = ReplicateConfig.defaultModel?.id

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            
            ScrollView {
                VStack {
                    photoPickerSection
                    
                    ZStack {
                        if isLoadingImages {
                            ProgressView("画像を読み込み・分析中...")
                        } else if imageItems.isEmpty {
                            emptyStateView
                        } else {
                            imageCardsView
                        }
                    }
                    .frame(minHeight: 400)

                    if !promptHistory.isEmpty {
                        promptHistorySection
                    }
                }
            }
        }
        .onChange(of: selectedPickerItems) {
            Task {
                await loadSelectedImages()
            }
        }
    }
    
    // MARK: - View Components
    
    private var photoPickerSection: some View {
        PhotosPicker(
            selection: $selectedPickerItems,
            maxSelectionCount: 0,
            selectionBehavior: .ordered,
            matching: .images
        ) {
            Label("評価する画像を選択", systemImage: "photo.on.rectangle.angled")
        }
        .buttonStyle(.bordered)
        .padding(.top)
        .disabled(isLoadingImages)
    }
    
    private var emptyStateView: some View {
        VStack {
            Text(showGenerateButton ? "すべての画像を評価しました。" : "評価する画像を選択してください")
                .foregroundColor(.gray)
                .padding()
            
            if showGenerateButton {
                generateButtonSection
            }
        }
    }
    
    private var generateButtonSection: some View {
        VStack {
            Text("再度画像を選択するか、生成に進んでください.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 5)
            
            Picker("生成モデル", selection: $selectedModelId) {
                ForEach(ReplicateConfig.availableModels) { model in
                    Text(model.name).tag(model.id as UUID?)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            Button("評価に基づいて画像を生成 ✨") {
                Task { await generateImage() }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
            .disabled(isGenerating || selectedModelId == nil)

            generationResultView
        }
    }
    
    private var generationResultView: some View {
        VStack {
            if isGenerating {
                ProgressView().padding(.top)
                Text("画像を生成中...").font(.caption).foregroundColor(.gray)
            } else {
                if let errorMsg = errorMessage {
                    Text("エラー: \(errorMsg)")
                        .foregroundColor(.red)
                        .padding()
                }
                
                if !generatedPrompt.isEmpty {
                    promptDisplayView
                }
                
                if let img = generatedImage {
                    Text("生成された画像:")
                        .font(.headline)
                        .padding(.top)
                    
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 300)
                        .cornerRadius(10)
                        .padding(.bottom)
                }
            }
        }
    }
    
    private var promptDisplayView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("生成に使用したプロンプト:")
                .font(.headline)
            
            Text(generatedPrompt)
                .font(.body)
            
            if !generatedReason.isEmpty {
                Text("プロンプト生成の理由:")
                    .font(.headline)
                    .padding(.top, 5)
                
                Text(generatedReason)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var imageCardsView: some View {
        ForEach(Array(zip(imageItems.indices, imageItems)), id: \.1.id) { index, currentItem in
            ImageCardView(item: currentItem, onSwiped: { itemId, direction in
                recordSwipeResult(item: currentItem, direction: direction)
                removeCard(withId: itemId)
            })
            .zIndex(Double(imageItems.count - 1 - index))
            .offset(y: CGFloat(imageItems.count - 1 - index) * -5)
            .padding(.horizontal)
        }
    }
    
    private var promptHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("プロンプト履歴")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(promptHistory.indices, id: \.self) { index in
                    VStack(alignment: .leading) {
                        Text("履歴 \(index + 1):")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(promptHistory[index])
                            .font(.caption)
                    }
                    
                    if index < promptHistory.count - 1 {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .padding(.top)
    }
    
    // MARK: - Helper Functions
    
    private func loadSelectedImages() async {
        let currentSelection = selectedPickerItems
        guard !currentSelection.isEmpty else { return }
        
        isLoadingImages = true
        imageItems.removeAll()
        swipeResults.removeAll()
        showGenerateButton = false
        generatedImage = nil
        errorMessage = nil
        generatedPrompt = ""
        generatedReason = ""
        
        var loadedImages: [ImageItem] = []
        
        for item in currentSelection {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    print("画像をロードしました。Gemini APIで分析中...")
                    let description = await geminiAnalysisService.analyzeImage(imageData: data)
                    print("分析結果(説明文): \(description ?? "分析失敗")")
                    loadedImages.append(ImageItem(imageData: data, description: description))
                } else {
                    print("画像のロードに失敗しました: \(item)")
                }
            } catch {
                print("画像ロード中にエラー: \(error)")
            }
        }
        
        imageItems = loadedImages
        isLoadingImages = false
    }

    private func removeCard(withId id: UUID) {
        imageItems.removeAll { $0.id == id }
        if imageItems.isEmpty {
            showGenerateButton = true
        }
    }
    
    private func recordSwipeResult(item: ImageItem, direction: SwipeDirection) {
        swipeResults[item.id] = (direction: direction, description: item.description)
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
        generatedPrompt = ""
        generatedReason = ""
        
        do {
            let result = try await imageGenerationService.generateFromSwipeResults(
                swipeResults,
                model: selectedModel
            )
            
            // 結果をUIに反映
            generatedImage = result.image
            generatedPrompt = result.prompt
            generatedReason = result.reason ?? "理由が生成されませんでした。"
            
            // プロンプト履歴に追加
            promptHistory.insert(result.prompt, at: 0)
            if promptHistory.count > 10 {
                promptHistory.removeLast()
            }
            
            print("--- 生成成功 ---")
            print("プロンプト: \(result.prompt)")
            print("理由: \(result.reason ?? "なし")")
            
        } catch {
            errorMessage = error.localizedDescription
            print("画像生成エラー: \(error)")
        }
        
        isGenerating = false
    }
}

// ImageCardView実装
struct ImageCardView: View {
    let item: ImageItem
    let onSwiped: (UUID, SwipeDirection) -> Void
    
    @State private var offset = CGSize.zero
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(radius: 5)
            
            if let uiImage = item.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 300, height: 400)
                    .clipped()
                    .cornerRadius(20)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 300, height: 400)
                    .overlay(
                        Text("画像を読み込めませんでした")
                            .foregroundColor(.gray)
                    )
            }
            
            // スワイプインジケーター
            if abs(offset.width) > 50 {
                Text(offset.width > 0 ? "好き" : "嫌い")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(offset.width > 0 ? .green : .red)
                    .opacity(Double(abs(offset.width) / 100))
            }
        }
        .frame(width: 300, height: 400)
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = value.translation
                    rotation = Double(value.translation.width / 10)
                }
                .onEnded { value in
                    if abs(value.translation.width) > 100 {
                        let direction: SwipeDirection = value.translation.width > 0 ? .like : .unlike
                        onSwiped(item.id, direction)
                    } else {
                        withAnimation(.spring()) {
                            offset = .zero
                            rotation = 0
                        }
                    }
                }
        )
    }
}

// Color extension
extension Color {
    static let cardBackground = Color(UIColor.systemBackground)
}

#Preview {
    ContentView()
}
