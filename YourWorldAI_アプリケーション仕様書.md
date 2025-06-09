# YourWorld AI - アプリケーション仕様書

## 概要

YourWorld AIは、ユーザーの画像の好みを学習し、AIが好みに基づいた新しい画像を生成するiOSアプリケーションです。画像評価のスワイプ機能、AI分析、画像生成、循環学習機能を組み合わせた先進的な好み学習システムを提供します。

## 技術スタック

- **フレームワーク**: SwiftUI
- **対象OS**: iOS (iPhone/iPad)
- **AI API**:
  - Google Gemini API (画像分析)
  - Google Vertex AI Imagen 3 (画像生成)
  - Replicate API (代替画像生成)

## アプリケーション構造

### メインアプリ (`yourworldai.swift`)
- **エントリーポイント**: `@main struct yourworldaiApp`
- **タブベース構造**:
  1. **評価タブ**: `ContentView()` - 画像評価・学習システム
  2. **直接生成タブ**: `DirectGenerationView()` - テキストプロンプトからの直接生成
  3. **キャラ作成タブ**: `CharacterCreationView()` - キャラクター特化の画像選択・作成

## 主要機能

### 1. 画像評価・学習システム (`ContentView.swift`)

#### データ構造
```swift
struct ImageItem: Identifiable {
    let id = UUID()
    let imageData: Data
    var uiImage: UIImage?
    var description: String?
}

enum SwipeDirection { 
    case like, unlike 
}
```

#### 核心ワークフロー
1. **画像選択**: PhotosPicker使用、複数選択対応
2. **スワイプ評価**: Tinder風のスワイプで好き嫌い評価
3. **AI詳細分析**: Gemini APIでスワイプ結果の詳細分析
4. **プロンプト生成**: 評価結果からGeminiがプロンプト生成
5. **AI画像生成**: Vertex AI Imagen 3で新画像生成
6. **循環学習**: 生成画像を次の評価サイクルに追加

#### 主要State変数
```swift
@State private var imageItems: [ImageItem] = []
@State private var swipeResults: [UUID: (direction: SwipeDirection, description: String?)] = [:]
@State private var evaluationResults: [ImageEvaluationResult] = []
@State private var showGenerateButton: Bool = false
@State private var generatedImage: UIImage?
@State private var isGenerating: Bool = false
```

#### UI構成
- **ヘッダー**: アプリ名・説明
- **写真選択ボタン**: PhotosPicker統合
- **スワイプカード**: 重なり合うカードUI、ドラッグ&スワイプ対応
- **評価分析セクション**: Gemini分析結果の表示（折りたたみ可能）
- **生成結果**: 生成画像・プロンプト・理由の表示
- **循環学習ボタン**: 生成画像を評価に追加

### 2. 画像分析サービス (`GeminiAnalysisService.swift`)

#### 主要メソッド
```swift
func analyzeImage(imageData: Data) async -> String?
func evaluateSwipedImage(imageData: Data, swipeDirection: SwipeDirection) async -> ImageEvaluationResult?
func batchEvaluateImages(_ evaluations: [(imageData: Data, swipeDirection: SwipeDirection)]) async -> [ImageEvaluationResult]
```

#### 評価結果構造
```swift
struct ImageEvaluationResult: Identifiable {
    let id = UUID()
    let swipeDirection: SwipeDirection
    let analysisText: String
    let timestamp: Date
}
```

#### 分析内容
- **評価理由の推測**
- **視覚的特徴分析**: スタイル、色彩、構図、雰囲気
- **魅力的要素/改善要素**の特定
- **学習ポイント**の抽出

### 3. 画像生成サービス (`ImageGenerationService.swift`)

#### 生成結果構造
```swift
struct GenerationResult {
    let image: UIImage
    let prompt: String
    let reason: String?
}
```

#### 主要メソッド
```swift
func generateFromSwipeResults(
    _ swipeResults: [UUID: (direction: SwipeDirection, description: String?)],
    evaluationResults: [ImageEvaluationResult] = [],
    model: ReplicateModelInfo
) async throws -> GenerationResult

func generateDirectly(
    prompt: String,
    model: ReplicateModelInfo
) async throws -> GenerationResult
```

#### 対応生成モデル
```swift
enum ModelInputType {
    case textToImage // 標準的なテキストプロンプト
    case imagen3 // Google Imagen 3
    case googleVertexAI // Google純正Vertex AI Imagen 3
    case conjunction // プロンプト結合タイプ
}
```

### 4. 直接生成機能 (`DirectGeneration.swift`)

#### 機能概要
- テキストプロンプト入力による直接画像生成
- モデル選択対応（Imagen 3、Stable Diffusion等）
- モデル特性に応じたUI最適化

#### 対応モデル例
- Google Imagen 3 (純正/Fast)
- Stable Diffusion 3.5 (Medium/Large)
- Miaomiao Harem（アニメスタイル）
- Ninjitsu Art（アートスタイル）

### 5. キャラクター作成機能 (`CharacterCreationView.swift`)

#### 機能概要
- キャラクター特化の画像学習
- 最大10枚の学習画像選択
- サムネイル最適化されたグリッド表示
- 進行状況の視覚化

## 設定ファイル

### 1. Google Gemini設定 (`GeminiConfig.swift`)
```swift
struct GeminiConfig {
    static let apiKey = "AIzaSyBSCRDhqDmLx9LsTysbb7jF9TiPDY4xy-g"
    static let visionModel = "gemini-1.5-flash-latest"
}
```

### 2. Google Cloud設定 (`GoogleCloudeConfig.swift`)
- Vertex AI認証情報
- プロジェクトID: "yourworldai"

### 3. Replicate設定 (`ReplicateConfig.swift`)
```swift
struct ReplicateConfig {
    static let apiKey = "YOUR_REPLICATE_API_KEY_HERE"
    static let availableModels: [ReplicateModelInfo] = [...]
}
```

## 循環学習システム

### ワークフロー
1. **初期画像選択** → **スワイプ評価** → **Gemini分析** → **画像生成**
2. **生成画像を評価に追加** → **新画像と混在評価** → **より精度の高い生成**
3. **継続的な好み学習とパーソナライゼーション**

### 実装詳細
```swift
func addGeneratedImageToEvaluation() {
    // 生成画像をImageItemに変換
    let newImageItem = ImageItem(
        imageData: imageData, 
        description: "AI生成画像: \(generatedPrompt.prefix(50))..."
    )
    
    // 既存画像リストの先頭に挿入
    imageItems.insert(newImageItem, at: 0)
}

func loadSelectedImages() async {
    // AI生成画像を保持
    let existingGeneratedImages = imageItems.filter { item in
        item.description?.starts(with: "AI生成画像") == true
    }
    
    // 新選択画像と組み合わせ
    imageItems = existingGeneratedImages + loadedImages
}
```

## パフォーマンス最適化

### 画像処理最適化
```swift
var optimizedUIImage: UIImage? {
    // 400px制限でリサイズ
    let maxSize: CGFloat = 400
    // メモリ効率的なリサイズ処理
}
```

### 非同期処理
- `@MainActor`による安全なUI更新
- `TaskGroup`による並列処理
- `async/await`による適切な非同期処理

### UI最適化
- `LazyVStack`/`LazyVGrid`によるレンダリング最適化
- グラデーション背景の軽量化
- アニメーション効果の最適化

## エラーハンドリング

### 画像生成エラー
```swift
enum ImageGenerationError: LocalizedError {
    case invalidAPIKey
    case noModelSelected
    case promptGenerationFailed
    case networkError(String)
    case decodingError(String)
    case timeoutError
    case apiError(Int, String)
}
```

### API通信エラー
- 適切な日本語エラーメッセージ
- フォールバック処理
- ユーザーフィードバック

## 今後の拡張可能性

### 技術的拡張
- Core Data永続化
- CloudKit同期
- プッシュ通知
- リアルタイム学習

### 機能的拡張
- スタイル転送
- アニメーション生成
- 3D画像生成
- コラボレーション機能

## セキュリティ考慮事項

### APIキー管理
- **警告**: 現在APIキーがハードコーディング
- **推奨**: 環境変数またはKeychain使用
- **対策**: サーバーサイドプロキシ実装

### データプライバシー
- 画像データのローカル処理
- ユーザー同意の確保
- データ暗号化

## 開発環境

### 必要条件
- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

### API依存性
- Google Gemini API
- Google Vertex AI
- Replicate API

---

**更新日**: 2025年12月30日  
**バージョン**: 1.0.0  
**開発者**: 柴田紘希 