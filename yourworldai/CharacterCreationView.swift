//
//  CharacterCreationView.swift
//  yourworldai
//
//  Created by [Your Name/AI] on [Date]
//

import SwiftUI
import PhotosUI

struct SelectedImageItem: Identifiable, Equatable {
    let id = UUID()
    let imageData: Data
    var uiImage: UIImage? { UIImage(data: imageData) }
    
    // 最適化: 小さなサムネイル画像を事前生成
    var thumbnailImage: UIImage? {
        guard let original = uiImage else { return nil }
        let thumbnailSize: CGFloat = 120
        
        let scale = min(thumbnailSize / CGFloat(original.size.width), thumbnailSize / CGFloat(original.size.height))
        let newSize = CGSize(
            width: CGFloat(original.size.width) * scale, 
            height: CGFloat(original.size.height) * scale
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        original.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail
    }
}

struct CharacterCreationView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImageData: [SelectedImageItem] = []
    @State private var isLoading = false
    private let maxSelectionCount = 10

    var body: some View {
        NavigationView {
            ZStack {
                // 軽量化されたグラデーション背景
                backgroundGradient
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 30) {
                        // ヘッダー
                        headerView
                        
                        // 写真選択ボタン
                        photoPickerButton
                        
                        // 選択画像グリッド
                        if !selectedImageData.isEmpty {
                            selectedImagesGrid
                        } else {
                            emptyStateView
                        }
                        
                        // 進行状況とガイド
                        if !selectedImageData.isEmpty {
                            progressView
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarHidden(true)
            .onChange(of: selectedItems) { _, _ in
                Task {
                    await loadSelectedImages()
                }
            }
        }
    }
    
    // MARK: - Optimized View Components
    
    // 軽量化されたグラデーション
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.30, green: 0.60, blue: 0.95),
                Color(red: 0.25, green: 0.70, blue: 0.85)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Text("キャラクター作成")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(radius: 1)
            
            Text("学習用画像を\(maxSelectionCount)枚まで選択")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            // シンプルな進行ドット
            HStack(spacing: 6) {
                ForEach(0..<maxSelectionCount, id: \.self) { index in
                    Circle()
                        .fill(index < selectedImageData.count ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 8)
        }
        .padding(.top, 20)
    }
    
    private var photoPickerButton: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: maxSelectionCount,
            selectionBehavior: .ordered,
            matching: .images
        ) {
            HStack(spacing: 15) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("画像を選択")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(selectedImageData.count)/\(maxSelectionCount) 枚選択済み")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 25)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    )
            )
            .shadow(radius: 5)
        }
        .disabled(selectedImageData.count >= maxSelectionCount || isLoading)
        .opacity((selectedImageData.count >= maxSelectionCount || isLoading) ? 0.6 : 1.0)
    }
    
    private var selectedImagesGrid: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("選択中の画像")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("すべて削除") {
                    selectedImageData.removeAll()
                    selectedItems.removeAll()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.red.opacity(0.2))
                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                )
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(selectedImageData) { item in
                    optimizedImageCard(for: item)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 5)
    }
    
    // 最適化された画像カード
    private func optimizedImageCard(for item: SelectedImageItem) -> some View {
        ZStack {
            if let thumbnail = item.thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 120)
                    .clipped()
                    .cornerRadius(15)
                    .overlay(
                        // シンプルな削除ボタン
                        Button {
                            removeImage(item: item)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(8),
                        alignment: .topTrailing
                    )
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 120)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red.opacity(0.7))
                            
                            Text("エラー")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    )
                    .shadow(radius: 2)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 25) {
            Image(systemName: "photo.artframe")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 10) {
                Text("学習用画像を選択")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("キャラクターの特徴を学習するための\n画像を最大\(maxSelectionCount)枚まで選択できます")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            // 簡素化された機能説明
            VStack(spacing: 15) {
                simpleFeatureCard(
                    icon: "brain.head.profile",
                    title: "AI学習",
                    description: "選択した画像からキャラクターの特徴を学習"
                )
                
                simpleFeatureCard(
                    icon: "wand.and.stars",
                    title: "自動生成",
                    description: "学習結果を基に新しい画像を自動生成"
                )
                
                simpleFeatureCard(
                    icon: "slider.horizontal.3",
                    title: "カスタマイズ",
                    description: "好みに合わせて生成設定を調整可能"
                )
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 5)
    }
    
    // 軽量化された機能カード
    private func simpleFeatureCard(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.08))
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    private var progressView: some View {
        VStack(spacing: 15) {
            // シンプルな進行状況バー
            VStack(spacing: 8) {
                HStack {
                    Text("選択進行状況")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(selectedImageData.count)/\(maxSelectionCount)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                ProgressView(value: Double(selectedImageData.count), total: Double(maxSelectionCount))
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(4)
            }
            
            // 簡素化された推奨メッセージ
            Group {
                if selectedImageData.count < 3 {
                    Text("💡 より良い結果のために3枚以上の画像を選択することをお勧めします")
                        .foregroundColor(.yellow.opacity(0.9))
                } else if selectedImageData.count >= maxSelectionCount {
                    Text("✅ 最大枚数に達しました！学習を開始できます")
                        .foregroundColor(.green.opacity(0.9))
                } else {
                    Text("👍 良い感じです！さらに画像を追加するか学習を開始しましょう")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .font(.system(size: 13, weight: .medium))
            .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.08))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 3)
    }
    
    // MARK: - Helper Functions
    
    private func loadSelectedImages() async {
        let currentSelection = selectedItems
        guard !currentSelection.isEmpty else { return }
        
        isLoading = true
        selectedImageData.removeAll()
        
        for item in currentSelection {
            if let data = try? await item.loadTransferable(type: Data.self) {
                if selectedImageData.count < maxSelectionCount {
                    await MainActor.run {
                        selectedImageData.append(SelectedImageItem(imageData: data))
                    }
                }
            } else {
                print("画像のロードに失敗しました: \(item)")
            }
        }
        
        isLoading = false
    }

    private func removeImage(item: SelectedImageItem) {
        selectedImageData.removeAll { $0.id == item.id }
    }
}

#Preview {
    CharacterCreationView()
}
