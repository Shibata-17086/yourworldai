# yourworldai プロジェクト - トラブルシューティング

## dyld_shared_cache_extract_dylibs エラーが発生した場合

### 解決手順
1. **プロジェクトクリーン**:
   ```bash
   xcodebuild clean -project yourworldai.xcodeproj
   ```

2. **DerivedData削除**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

3. **必要に応じてシステムキャッシュ更新**:
   ```bash
   sudo update_dyld_shared_cache -force
   ```

4. **Xcodeを再起動してビルド**

### 原因
- 古いビルドキャッシュの破損
- Xcode バージョン間でのキャッシュ競合
- macOS システムライブラリキャッシュの問題

### 予防策
- 週1回程度 DerivedData をクリア
- Xcode アップデート後は必ずクリーンビルド
- 大きな変更後はクリーンビルドを実行

### 環境情報
- Xcode: 16.0 (Build version 16A242)
- macOS: darwin 24.5.0
- プロジェクト: yourworldai (iOS 18.0+)

### 最終更新
2025年5月26日 - エラー解決済み 

# YourWorld AI アプリケーション・トラブルシューティングガイド

## 🚨 発表会用: Vertex AI エラー対策

### 問題: Vertex AI Imagen 3で画像生成できない

#### 原因1: アクセストークンの期限切れ
**症状:** 認証エラー（HTTP 401）が発生
**解決方法:**
```bash
# ターミナルで最新のアクセストークンを取得
gcloud auth print-access-token

# 取得したトークンを以下のファイルに貼り付け:
# yourworldai/GoogleCloudeConfig.swift の vertexApiKey
# yourworldai/VertexAIModels.swift の manualToken
```

#### 原因2: プロジェクト設定の問題
**症状:** プロジェクトIDエラーまたは権限エラー（HTTP 403）
**確認事項:**
- プロジェクトID: `yourworldai-445900`
- リージョン: `us-central1`
- 必要な権限: Vertex AI User, Storage Object Viewer

#### 原因3: ネットワーク接続の問題
**症状:** タイムアウトエラーまたはネットワークエラー
**対策:**
1. インターネット接続を確認
2. アプリが自動的にReplicateモデルにフォールバック
3. それでも失敗する場合はデモ画像生成機能が作動

### 🔄 自動フォールバック機能

アプリには3段階のフォールバック機能が実装されています：

1. **Vertex AI Imagen 3** (最高品質)
   ↓ エラー時
2. **Replicate Miaomiao Haremモデル** (確実に動作)
   ↓ APIキー無効時  
3. **デモ画像生成機能** (オフラインでも動作)

### 📊 発表会当日のチェックリスト

#### 開始前（5分前）
- [ ] インターネット接続確認
- [ ] アクセストークン有効性確認（`gcloud auth print-access-token`）
- [ ] アプリ起動テスト

#### 問題発生時
1. **コンソールログを確認**
   - Xcodeの Debug area でエラーメッセージを確認
   - "❌", "⚠️", "🚨" マークのログをチェック

2. **段階的な対処**
   ```
   Step 1: Vertex AIエラー → 自動的にReplicate切り替え
   Step 2: Replicateエラー → デモ画像生成
   Step 3: デモ画像でプレゼンテーション継続
   ```

3. **緊急時のスキップ**
   - 画像生成に時間がかかる場合は既存の評価画像を使用
   - デモ画像でアプリの機能説明を継続

### 🛠️ 緊急修正コマンド

アクセストークン更新（1分で完了）:
```bash
# 1. 新しいトークンを取得
gcloud auth print-access-token

# 2. 出力されたトークンをコピー

# 3. Xcodeで以下を検索・置換:
# 検索: "ya29.a0AW4Xtxj" で始まる現在のトークン
# 置換: 新しいトークン
```

### 📞 発表会サポート連絡先

問題が解決しない場合:
- 技術サポート: [連絡先情報]
- 緊急時: デモ画像機能を使用してプレゼンテーション継続

---

## 既存のトラブルシューティング

// ... existing code ... 