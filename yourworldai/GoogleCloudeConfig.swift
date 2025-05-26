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
    static let projectId = "yourworldai" // ← Google Cloudプロジェクトのプロジェクトid
    static let location = "us-central1" // ← Imagen 3が利用可能なリージョン
    
    // 認証設定（以下のいずれかを使用）
    // 方法1: 手動で取得したアクセストークン（開発用）
    static let vertexApiKey = "AIzaSyBpGZBU0--IvoZbw5HTjNBYv95yAT9Mzf8" // ← 旧設定（現在は使用されない）
    
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
## Google Cloud Vertex AI Imagen 3 の設定方法

### 開発用セットアップ（簡単）:
1. ターミナルでGoogle Cloud CLIをセットアップ:
   ```bash
   gcloud auth login
   gcloud config set project yourworldai
   gcloud auth application-default login
   ```

2. アクセストークンを取得:
   ```bash
   gcloud auth print-access-token
   ```

3. 取得したトークンをVertexAIModels.swiftの`manualToken`変数に貼り付け

### プロダクション用セットアップ（推奨）:
1. Google Cloud Console でサービスアカウントを作成
2. Vertex AI User権限を付与
3. サービスアカウントキー（JSON）をダウンロード
4. `serviceAccountKeyPath`にキーファイルのパスを設定

利用可能なリージョン:
- us-central1 (推奨)
- us-east4  
- us-west1
- europe-west4

必要な権限:
- Vertex AI User (roles/aiplatform.user)
- Storage Object Viewer (roles/storage.objectViewer)
*/
