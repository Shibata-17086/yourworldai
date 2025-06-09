//
//  ContentView.swift
//  yourworldai
//
//  Created by 柴田紘希 on 2025/04/12.
//

import SwiftUI
import PhotosUI

// 🚀 最適化されたImageItem
struct ImageItem: Identifiable {
    let id = UUID()
    let imageData: Data
    private var _uiImage: UIImage?
    private var _displayImage: UIImage?  // 表示用の最適化画像
    var description: String?
    
    // 🔧 明示的なイニシャライザー
    init(imageData: Data, description: String? = nil) {
        self.imageData = imageData
        self.description = description
        self._uiImage = nil
        self._displayImage = nil
    }
    
    // 🔧 遅延ロードでメモリ最適化
    mutating func getUIImage() -> UIImage? {
        if _uiImage == nil {
            _uiImage = UIImage(data: imageData)
        }
        return _uiImage
    }
    
    // 読み取り専用プロパティ（軽量版）
    var uiImage: UIImage? {
        return UIImage(data: imageData)
    }
    
    // 🚀 表示用最適化画像（キャッシュ付き）
    var displayImage: UIImage? {
        mutating get {
            if _displayImage != nil {
                return _displayImage
            }
            
            // すでに最適化済みのデータから画像を生成
            if let image = UIImage(data: imageData) {
                _displayImage = image
                return image
            }
            
            return nil
        }
    }
    
    // 🔧 キャッシュ機能付き最適化画像（廃止予定）
    mutating func getOptimizedUIImage() -> UIImage? {
        return displayImage
    }
    
    // 読み取り専用の最適化画像（高速版）
    var optimizedUIImage: UIImage? {
        // データがすでに最適化されているので、そのまま返す
        return UIImage(data: imageData)
    }
    
    // 🧹 メモリ解放メソッド
    mutating func clearCache() {
        _uiImage = nil
        _displayImage = nil
    }
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
    
    // 画像評価関連
    @State private var evaluationResults: [ImageEvaluationResult] = []
    @State private var isEvaluating = false
    @State private var pendingEvaluations: [(id: UUID, direction: SwipeDirection)] = []
    @State private var showEvaluationError = false
    @State private var evaluationErrorMessage = ""
    
    // 学習分析関連の状態変数
    @State private var userPreferenceAnalysis: UserPreferenceAnalysis? = nil
    @State private var isAnalyzingPreferences = false
    @State private var showPreferenceAnalysis = false
    @State private var optimizedPrompt: String = ""
    @State private var isOptimizingPrompt = false
    @State private var selectedEvaluationTab = "統計"  // タブ選択用
    
    // 🚀 パフォーマンス最適化用
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    @State private var apiRetryCount = 0
    private let maxRetryCount = 3

    // 新しい状態変数
    @State private var promptToOptimize = ""
    @State private var showEvaluationResults = false
    @State private var isAddingToEvaluation = false
    
    init() {
        _selectedModelId = State(initialValue: ReplicateConfig.availableModels.first?.id)
    }

    var body: some View {
        ZStack {
            // 🔧 軽量化されたグラデーション背景
            backgroundGradient
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 25) {
                    // ヘッダー
                    headerView
                    
                    // 写真選択セクション
                    photoPickerSection
                    
                    // メインカードエリア
                    ZStack {
                        if isLoadingImages {
                            loadingView
                        } else if imageItems.isEmpty {
                            emptyStateView
                        } else {
                            imageCardsView
                        }
                    }
                    .frame(minHeight: 450)
                    
                    // 画像評価結果セクション
                    if !evaluationResults.isEmpty || isEvaluating {
                        evaluationResultsSection
                    }

                    if !promptHistory.isEmpty {
                        promptHistorySection
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
            }
        }
        .onChange(of: selectedPickerItems) { _, _ in
            Task {
                await loadSelectedImages()
            }
        }
        // 🔧 メモリ警告対応
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            clearImageCache()
        }
        // 🔧 バックグラウンド対応
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            startBackgroundTask()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            endBackgroundTask()
        }
    }
    
    // MARK: - Optimized View Components
    
    // 軽量化されたグラデーション
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.95, green: 0.4, blue: 0.27),
                Color(red: 0.96, green: 0.35, blue: 0.74)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("YourWorld AI")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(radius: 1)
            
            Text("画像から好みを学習してAIが生成")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.top, 20)
    }
    
    private var photoPickerSection: some View {
        PhotosPicker(
            selection: $selectedPickerItems,
            maxSelectionCount: 0,
            selectionBehavior: .ordered,
            matching: .images
        ) {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("画像を選択して評価開始")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(radius: 4)
        }
        .disabled(isLoadingImages)
        .opacity(isLoadingImages ? 0.6 : 1.0)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("画像を分析中...")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.1))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 25) {
            if showGenerateButton {
                generateCompletedView
            } else {
                initialEmptyView
            }
        }
    }
    
    private var initialEmptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.artframe")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.white.opacity(0.8))
            
            Text("好みの画像を選択")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("スワイプして好き嫌いを教えてください")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.1))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    private var generateCompletedView: some View {
        VStack(spacing: 25) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(.white)
            
            Text("評価完了！")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            generateButtonSection
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.15))
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(radius: 5)
    }
    
    private var generateButtonSection: some View {
        VStack(spacing: 20) {
            Text("好みに基づいてAIが画像を生成します")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            Picker("生成モデル", selection: $selectedModelId) {
                ForEach(ReplicateConfig.availableModels) { model in
                    Text(model.name)
                        .font(.system(size: 14, weight: .medium))
                        .tag(model.id as UUID?)
                }
            }
            .pickerStyle(.segmented)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
            
            Button("AIに画像を生成させる ✨") {
                Task { await generateImage() }
            }
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.green.opacity(0.8))
            )
            .shadow(radius: 5)
            .disabled(isGenerating || selectedModelId == nil)
            .opacity((isGenerating || selectedModelId == nil) ? 0.6 : 1.0)

            generationResultView
        }
    }
    
    private var generationResultView: some View {
        VStack(spacing: 20) {
            if isGenerating {
                VStack(spacing: 15) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                    
                    Text("AIが画像を生成中...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    if apiRetryCount > 0 {
                        Text("再試行中... (\(apiRetryCount)/\(maxRetryCount))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white.opacity(0.1))
                )
            } else {
                if let errorMsg = errorMessage {
                    Text("⚠️ \(errorMsg)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(15)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.2))
                        )
                }
                
                if !generatedPrompt.isEmpty {
                    promptDisplayView
                }
                
                if let img = generatedImage {
                    VStack(spacing: 15) {
                        Text("✨ 生成された画像")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 320, maxHeight: 320)
                            .cornerRadius(20)
                            .shadow(radius: 8)
                        
                        Button(isAddingToEvaluation ? "✅ 追加しました" : "📊 この画像を評価に追加") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                addGeneratedImageToEvaluation()
                            }
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(isAddingToEvaluation ? Color.green.opacity(0.8) : Color.blue.opacity(0.8))
                        )
                        .shadow(radius: 4)
                        .disabled(isAddingToEvaluation)
                        .scaleEffect(isAddingToEvaluation ? 1.05 : 1.0)
                        
                        Text("この画像を新しい評価サイクルに追加して、さらに精度の高い好みを学習させます")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                    )
                }
            }
        }
    }
    
    private var promptDisplayView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("📝 生成プロンプト")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(generatedPrompt)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(15)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
            
            if !generatedReason.isEmpty {
                Text("💡 生成理由")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(generatedReason)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var imageCardsView: some View {
        ZStack {
            ForEach(Array(zip(imageItems.indices, imageItems)), id: \.1.id) { index, currentItem in
                OptimizedImageCard(item: currentItem, onSwiped: { itemId, direction in
                    recordSwipeResult(item: currentItem, direction: direction)
                    removeCard(withId: itemId)
                })
                .zIndex(Double(imageItems.count - 1 - index))
                .offset(y: CGFloat(index) * -8)
                .scaleEffect(1.0 - CGFloat(index) * 0.04)
                .opacity(1.0 - Double(index) * 0.15)
            }
        }
    }
    
    private var promptHistorySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("プロンプト履歴")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(promptHistory.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("履歴 \(index + 1)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                            
                            Text(Date(), style: .time)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Text(promptHistory[index])
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(3)
                    }
                    .padding(15)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    
                    if index < promptHistory.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.2))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(radius: 5)
        }
    }

    // MARK: - 評価結果表示UI
    
    private var evaluationResultsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("画像評価分析")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isEvaluating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
                
                Button(showEvaluationResults ? "折りたたむ" : "詳細を見る") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showEvaluationResults.toggle()
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white.opacity(0.2))
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }
            
            if isEvaluating {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                    
                    Text("AIが画像を評価分析中...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white.opacity(0.1))
                )
            }
            
            // タブ付き評価結果UI
            if !evaluationResults.isEmpty {
                VStack(spacing: 16) {
                    // タブ選択
                    HStack(spacing: 0) {
                        ForEach(["統計", "履歴", "学習分析"], id: \.self) { tab in
                            Button(action: { selectedEvaluationTab = tab }) {
                                Text(tab)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selectedEvaluationTab == tab ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(selectedEvaluationTab == tab ? Color.white.opacity(0.3) : Color.clear)
                                    )
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // タブコンテンツ
                    switch selectedEvaluationTab {
                    case "統計":
                        evaluationStatisticsView
                        
                    case "履歴":
                        if showEvaluationResults {
                            evaluationDetailsView
                        }
                        
                    case "学習分析":
                        preferenceAnalysisView
                        
                    default:
                        EmptyView()
                    }
                }
            } else {
                Text("まだ評価がありません。画像をスワイプして評価を開始してください！")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
                    .padding()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 5)
    }
    
    private var evaluationDetailsView: some View {
        LazyVStack(spacing: 15) {
            ForEach(evaluationResults) { result in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: result.directionIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(result.directionColor)
                        
                        Text("評価: \(result.directionText)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(result.timestamp, style: .time)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text(result.analysisText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(2)
                        .lineLimit(showEvaluationResults ? nil : 3)
                }
                .padding(15)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .stroke(result.directionColor.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 🚀 最適化されたHelper Functions
    
    private func loadSelectedImages() async {
        let currentSelection = selectedPickerItems
        guard !currentSelection.isEmpty else { return }
        
        isLoadingImages = true
        
        // 🧹 既存データのクリーンアップ
        clearImageCache()
        
        // 既存のAI生成画像を保持
        let existingGeneratedImages = imageItems.filter { item in
            item.description?.starts(with: "AI生成画像") == true
        }
        
        // リセット処理
        swipeResults.removeAll()
        showGenerateButton = false
        generatedImage = nil
        errorMessage = nil
        generatedPrompt = ""
        generatedReason = ""
        evaluationResults.removeAll()
        isAddingToEvaluation = false
        apiRetryCount = 0
        
        var loadedImages: [ImageItem] = []
        
        // 🚀 並列処理で高速化 + 事前最適化
        await withTaskGroup(of: ImageItem?.self) { group in
        for item in currentSelection {
                group.addTask {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                            // 🔧 データサイズ制限（メモリ最適化）
                            if data.count > 10_000_000 { // 10MB制限
                                print("⚠️ 画像サイズが大きすぎます: \(data.count) bytes")
                                return nil
                            }
                            
                            // 🚀 事前に画像を最適化
                            if let optimizedData = optimizeImageData(data) {
                                return ImageItem(imageData: optimizedData, description: nil)
                } else {
                                return ImageItem(imageData: data, description: nil)
                }
                        }
                        return nil
            } catch {
                print("画像ロード中にエラー: \(error)")
                        return nil
                    }
                }
            }
            
            for await result in group {
                if let imageItem = result {
                    loadedImages.append(imageItem)
                }
            }
        }
        
        // 画像組み合わせ
        imageItems = existingGeneratedImages + loadedImages
        isLoadingImages = false
        
        print("✅ 最適化済み画像ロード完了")
        print("📊 AI生成画像: \(existingGeneratedImages.count)枚")
        print("📊 新選択画像: \(loadedImages.count)枚")
        print("📊 合計評価対象: \(imageItems.count)枚")
    }
    
    // 🚀 画像データの事前最適化
    private func optimizeImageData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        
        let maxSize: CGFloat = 800 // フリック用に少し大きめ
        
        // すでに小さい画像はそのまま返す
        if image.size.width <= maxSize && image.size.height <= maxSize {
            // JPEG圧縮のみ適用
            return image.jpegData(compressionQuality: 0.9)
        }
        
        // リサイズ処理
        let scale = min(maxSize / image.size.width, maxSize / image.size.height)
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        // 高品質リサイズ
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        format.preferredRange = .standard
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let optimizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // 最適化されたJPEGデータを返す
        return optimizedImage.jpegData(compressionQuality: 0.85)
    }

    private func removeCard(withId id: UUID) {
        // 🧹 削除時にメモリクリア
        if let index = imageItems.firstIndex(where: { $0.id == id }) {
            imageItems[index].clearCache()
        }
        imageItems.removeAll { $0.id == id }
        
        if imageItems.isEmpty {
            showGenerateButton = true
        }
    }
    
    private func recordSwipeResult(item: ImageItem, direction: SwipeDirection) {
        swipeResults[item.id] = (direction: direction, description: nil)
        
        // 🚀 スワイプ時の詳細評価分析（エラー処理強化）
        Task {
            await evaluateSwipedImageWithRetry(imageData: item.imageData, direction: direction)
        }
    }
    
    // 🔧 リトライ機能付き評価分析
    private func evaluateSwipedImageWithRetry(imageData: Data, direction: SwipeDirection) async {
        isEvaluating = true
        var currentRetry = 0
        
        while currentRetry <= maxRetryCount {
            if let evaluation = await geminiAnalysisService.evaluateSwipedImage(
                imageData: imageData, 
                swipeDirection: direction
            ) {
                await MainActor.run {
                    evaluationResults.append(evaluation)
                    print("✅ 画像評価完了: \(direction == .like ? "好き" : "嫌い")")
    }
                break
            } else {
                currentRetry += 1
                if currentRetry <= maxRetryCount {
                    print("⚠️ 評価分析失敗、リトライ中... (\(currentRetry)/\(maxRetryCount))")
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒待機
                } else {
                    print("❌ 評価分析が最大リトライ回数に達しました")
                    // フォールバック: 簡易評価結果を作成
                    let fallbackEvaluation = ImageEvaluationResult(
                        swipeDirection: direction,
                        analysisText: "この画像を\(direction == .like ? "好き" : "嫌い")と評価しました。詳細な分析は現在利用できません。",
                        timestamp: Date()
                    )
                    await MainActor.run {
                        evaluationResults.append(fallbackEvaluation)
                    }
                }
            }
        }
        
        isEvaluating = false
    }

    // 🔧 画像生成の最適化（リトライ機能付き）
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
        apiRetryCount = 0
        
        // 🚀 バックグラウンドタスク開始
        startBackgroundTask()
        
        var success = false
        while apiRetryCount <= maxRetryCount && !success {
        do {
            let result = try await imageGenerationService.generateFromSwipeResults(
                swipeResults,
                    evaluationResults: evaluationResults,
                model: selectedModel
            )
            
            // 結果をUIに反映
            generatedImage = result.image
            generatedPrompt = result.prompt
            generatedReason = result.reason ?? "理由が生成されませんでした。"
            
            // プロンプト履歴に追加
            promptHistory.insert(result.prompt, at: 0)
                if promptHistory.count > 5 { // 履歴を5件に制限
                promptHistory.removeLast()
            }
            
                success = true
                print("✅ 画像生成成功（評価分析反映版）")
            
        } catch {
                apiRetryCount += 1
                if apiRetryCount <= maxRetryCount {
                    print("⚠️ 画像生成失敗、リトライ中... (\(apiRetryCount)/\(maxRetryCount))")
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機
                } else {
                    errorMessage = "画像生成に失敗しました: \(error.localizedDescription)"
                    print("❌ 画像生成が最大リトライ回数に達しました: \(error)")
                }
            }
        }
        
        isGenerating = false
        endBackgroundTask()
    }
    
    private func addGeneratedImageToEvaluation() {
        guard let img = generatedImage else { 
            print("⚠️ 生成画像が見つかりません")
            return 
        }
        
        // アニメーション開始
        isAddingToEvaluation = true
        
        // UIImageをDataに変換
        guard let imageData = img.jpegData(compressionQuality: 0.8) else {
            print("⚠️ 生成画像のデータ変換に失敗")
            isAddingToEvaluation = false
            return
        }
        
        // ImageItemを作成
        let description = "AI生成画像: \(generatedPrompt.prefix(50))\(generatedPrompt.count > 50 ? "..." : "")"
        let newImageItem = ImageItem(
            imageData: imageData, 
            description: description
        )
        
        // 少し遅延を入れてアニメーション効果を見せる
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 既存の画像リストに生成画像を追加（先頭に挿入）
            self.imageItems.insert(newImageItem, at: 0)
            
            // 生成ボタンを非表示にして、スワイプ評価モードに戻る
            self.showGenerateButton = false
            
            // 生成画像をクリア（重複評価を避けるため）
            self.generatedImage = nil
            self.generatedPrompt = ""
            self.generatedReason = ""
            
            // アニメーション終了
            self.isAddingToEvaluation = false
            
            print("✅ 生成画像を評価対象に追加しました")
        }
    }
    
    // 🧹 メモリ管理機能
    private func clearImageCache() {
        for i in 0..<imageItems.count {
            imageItems[i].clearCache()
        }
    }
    
    // 🔧 バックグラウンド処理管理
    private func startBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ImageGeneration") {
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // 新しい学習分析ビュー
    private var preferenceAnalysisView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 分析ボタン
            Button(action: analyzeUserPreferences) {
                HStack {
                    if isAnalyzingPreferences {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "brain.head.profile")
                    }
                    Text(isAnalyzingPreferences ? "分析中..." : "好みのパターンを分析")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(evaluationResults.count >= 5 ? Color.blue : Color.gray)
                )
            }
            .disabled(evaluationResults.count < 5 || isAnalyzingPreferences)
            
            if evaluationResults.count < 5 {
                Text("💡 5回以上の評価が必要です（現在: \(evaluationResults.count)回）")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
            }
            
            // 分析結果表示
            if let analysis = userPreferenceAnalysis {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🎯 あなたの好みの特徴")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    ForEach(analysis.preferredFeatures, id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(feature)
                                .font(.system(size: 14))
                        }
                    }
                    
                    Text("❌ 避ける傾向のある要素")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.top, 8)
                    
                    ForEach(analysis.avoidedElements, id: \.self) { element in
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(element)
                                .font(.system(size: 14))
                        }
                    }
                    
                    Text("💡 推奨事項")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.top, 8)
                    
                    ForEach(analysis.recommendations, id: \.self) { recommendation in
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text(recommendation)
                                .font(.system(size: 14))
                        }
                    }
                    
                    // プロンプト最適化セクション
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🚀 プロンプト最適化")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.top, 8)
                        
                        Text("好みに基づいて画像生成プロンプトを最適化します")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("プロンプトを入力", text: $promptToOptimize)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button(action: optimizePrompt) {
                                if isOptimizingPrompt {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                            }
                            .disabled(promptToOptimize.isEmpty || isOptimizingPrompt)
                            .foregroundColor(.blue)
                        }
                        
                        if !optimizedPrompt.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("最適化されたプロンプト:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(optimizedPrompt)
                                    .font(.system(size: 14))
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.05))
                )
            }
        }
        .padding()
    }

    // 分析機能の実装
    private func analyzeUserPreferences() {
        Task {
            do {
                isAnalyzingPreferences = true
                let analysis = try await geminiAnalysisService.analyzeUserPreferences(from: evaluationResults)
                await MainActor.run {
                    userPreferenceAnalysis = analysis
                    isAnalyzingPreferences = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzingPreferences = false
                    print("好み分析エラー: \(error)")
                }
            }
        }
    }
    
    private func optimizePrompt() {
        guard let analysis = userPreferenceAnalysis, !promptToOptimize.isEmpty else { return }
        
        Task {
            do {
                isOptimizingPrompt = true
                let optimized = try await geminiAnalysisService.optimizePromptBasedOnPreferences(
                    basePrompt: promptToOptimize,
                    preferences: analysis
                )
                await MainActor.run {
                    optimizedPrompt = optimized
                    isOptimizingPrompt = false
                }
            } catch {
                await MainActor.run {
                    isOptimizingPrompt = false
                    print("プロンプト最適化エラー: \(error)")
                }
            }
        }
    }

    // 統計ビュー
    private var evaluationStatisticsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("評価統計")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            if !evaluationResults.isEmpty {
                VStack(spacing: 8) {
                    // 基本統計
                    HStack {
                        StatCard(title: "総評価数", value: "\(evaluationResults.count)", icon: "star.fill", color: .orange)
                        StatCard(title: "好評価", value: "\(evaluationResults.filter { $0.swipeDirection == .like }.count)", icon: "heart.fill", color: .green)
                        StatCard(title: "低評価", value: "\(evaluationResults.filter { $0.swipeDirection == .unlike }.count)", icon: "hand.thumbsdown.fill", color: .red)
                    }
                    
                    // 評価率
                    HStack {
                        let likeCount = evaluationResults.filter { $0.swipeDirection == .like }.count
                        let likeRate = Double(likeCount) / Double(evaluationResults.count) * 100
                        
                        StatCard(title: "好評価率", value: String(format: "%.1f%%", likeRate), icon: "percent", color: .blue)
                        StatCard(title: "今日の評価", value: "\(todayEvaluationCount)", icon: "calendar", color: .purple)
                        StatCard(title: "最新評価", value: lastEvaluationTime, icon: "clock.fill", color: .gray)
                    }
                    
                    // 傾向分析
                    if evaluationResults.count >= 5 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("📊 学習傾向")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            let recentResults = Array(evaluationResults.suffix(10))
                            let recentLikes = recentResults.filter { $0.swipeDirection == .like }.count
                            let trend = recentLikes >= 6 ? "最近はポジティブな傾向" : 
                                       recentLikes <= 3 ? "最近は選択的な傾向" : "バランスの取れた評価"
                            
                            Text(trend)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                    }
                }
            } else {
                Text("まだ評価がありません。画像をスワイプして評価を開始してください！")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }

    // 計算プロパティを追加
    private var todayEvaluationCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return evaluationResults.filter { 
            Calendar.current.startOfDay(for: $0.timestamp) == today 
        }.count
    }
    
    private var lastEvaluationTime: String {
        guard let lastEvaluation = evaluationResults.last else { return "なし" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: lastEvaluation.timestamp)
    }
}

// 高度に最適化されたImageCardView
struct OptimizedImageCard: View {
    let item: ImageItem  // @Stateを削除してパフォーマンス向上
    let onSwiped: (UUID, SwipeDirection) -> Void
    
    @State private var offset = CGSize.zero
    @State private var rotation: Double = 0
    @State private var isDragging = false
    @State private var cachedImage: UIImage? = nil  // 画像キャッシュ
    
    // パフォーマンス最適化: スワイプ状態のdebouncing
    private var swipeIntensity: Double {
        min(abs(offset.width) / 120.0, 1.0)
    }
    
    private var showSwipeIndicator: Bool {
        abs(offset.width) > 60
    }
    
    var body: some View {
        ZStack {
            // シンプルなカード背景
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white)
                .shadow(radius: isDragging ? 8 : 4)
            
            if let uiImage = cachedImage ?? item.optimizedUIImage {
                VStack(spacing: 0) {
                    // 最適化された画像部分
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 320, height: 400)
                        .clipped()
                        .cornerRadius(25)
                    
                    // シンプルな下部エリア
                    VStack(spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("評価してください")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                if let description = item.description, description.starts(with: "AI生成画像") {
                                    Text("🤖 AI生成画像")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.blue.opacity(0.2))
                                        )
                                } else {
                                Text("左右にスワイプ")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // シンプルなアイコン
                            HStack(spacing: 8) {
                                Image(systemName: "hand.point.left.fill")
                                    .foregroundColor(.red.opacity(0.6))
                                    .font(.system(size: 14))
                                
                                Image(systemName: "hand.point.right.fill")
                                    .foregroundColor(.green.opacity(0.6))
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .onAppear {
                    // 画像を一度だけキャッシュ
                    if cachedImage == nil {
                        cachedImage = item.optimizedUIImage
                    }
                }
            } else {
                // エラー表示も最適化
                VStack(spacing: 10) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("画像を読み込めませんでした")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(width: 320, height: 460)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.gray.opacity(0.1))
                )
            }
            
            // 最適化されたスワイプオーバーレイ
            if showSwipeIndicator {
                swipeOverlay
            }
        }
        .frame(width: 320, height: 460)
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .scaleEffect(isDragging ? 0.98 : 1.0)
        .gesture(swipeGesture)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: offset)
    }
    
    // 軽量化されたスワイプオーバーレイ
    private var swipeOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.3 * swipeIntensity))
            
            VStack(spacing: 8) {
                Image(systemName: offset.width > 0 ? "heart.fill" : "xmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(offset.width > 0 ? .green : .red)
                
                Text(offset.width > 0 ? "好き" : "嫌い")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(0.8 + 0.4 * swipeIntensity)
        }
        .opacity(swipeIntensity)
    }
    
    // 最適化されたジェスチャー
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
                rotation = Double(value.translation.width / 20.0)
                isDragging = true
            }
            .onEnded { value in
                isDragging = false
                
                if abs(value.translation.width) > 100 {
                    let direction: SwipeDirection = value.translation.width > 0 ? .like : .unlike
                    
                    // シンプルなスワイプアウト
                    withAnimation(.easeOut(duration: 0.3)) {
                        offset = CGSize(
                            width: value.translation.width > 0 ? 400 : -400,
                            height: value.translation.height
                        )
                        rotation = Double(offset.width / 15.0)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onSwiped(item.id, direction)
                    }
                } else {
                    // シンプルなリセット
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = .zero
                        rotation = 0
                    }
                }
            }
    }
    
}

// 統計カードコンポーネント
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(radius: 1)
        )
    }
}

#Preview {
    ContentView()
}
