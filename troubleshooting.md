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