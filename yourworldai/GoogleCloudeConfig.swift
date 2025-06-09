//
//  GoogleCloudConfig.swift
//  yourworldai
//
//  Created by [Your Name/AI] on [Date]
//

import Foundation

struct GoogleCloudConfig {

    // !!! 重要: APIキーの安全な管理について !!!
    // このファイルにAPIキーを直接記述するのはテスト目的のみにしてください。
    // Gitリポジトリにコミットしないでください。
    // 安全な管理方法 (Info.plist, .xcconfig, 環境変数, サーバーサイドなど) を検討してください。
    
    // Google Cloud Vision API
    static let visionApiKey = "YOUR_GOOGLE_CLOUD_VISION_API_KEY" // ← ここにあなたのVision APIキーを入れる！
    
    // Google Cloud Vertex AI API設定
    // 例: projectId = "my-project-12345"
    static let projectId = "yourworldai" // ← 正しいGoogle CloudプロジェクトID
    static let location = "us-central1" // ← Imagen 3が利用可能なリージョン
    
    // 🚨 発表会用: 最新アクセストークン（2025年6月24日取得）
    // ⏰ 注意：アクセストークンは約1時間で期限切れになります
    static let vertexApiKey = "YOUR_VERTEX_ACCESS_TOKEN_HERE" // ← 最新アクセストークン
    
    // 方法2: サービスアカウントキーファイルのパス（推奨）
    static let serviceAccountKeyPath: String? = nil // ← サービスアカウントキーJSONファイルのパス
    // 例: static let serviceAccountKeyPath: String? = "/path/to/service-account-key.json"
    
    // Imagen 3モデル設定
    static let imagen3Model = "imagen-3.0-generate-001"
    static let imagen3FastModel = "imagen-3.0-fast-generate-001"
    
    // Vertex AI APIエンドポイント
    static var vertexAIEndpoint: String {
        return "https://\(location)-aiplatform.googleapis.com/v1/projects/\(projectId)/locations/\(location)/publishers/google/models/"
    }
}

/*
## 🚨 発表会用設定完了！

### 現在の設定状況:
✅ プロジェクトID: yourworldai-445900
✅ リージョン: us-central1  
✅ 最新アクセストークン: 取得済み（1時間有効）

### 発表会当日のトラブルシューティング:
1. Vertex AIエラーが発生した場合:
   - 自動的にReplicateモデルにフォールバック
   - デモ画像生成機能が作動

2. アクセストークン期限切れの場合:
   ターミナルで以下を実行して更新：
   ```bash
   gcloud auth print-access-token
   ```
   取得したトークンをvertexApiKeyに貼り付け

3. 緊急時のフォールバック:
   - Miaomiao Haremモデル（確実に動作）
   - デモ画像生成機能（APIなしでも動作）

### 利用可能なリージョン:
- us-central1 (現在使用中)
- us-east4  
- us-west1
- europe-west4

### 必要な権限:
- Vertex AI User (roles/aiplatform.user)
- Storage Object Viewer (roles/storage.objectViewer)
*/
