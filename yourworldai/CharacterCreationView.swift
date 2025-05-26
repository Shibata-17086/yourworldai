//
//  CharacterCreationView.swift // ← ファイル名を修正推奨
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
}

struct CharacterCreationView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImageData: [SelectedImageItem] = []
    private let maxSelectionCount = 10

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: maxSelectionCount,
                    selectionBehavior: .ordered,
                    matching: .images
                ) {
                    Label("ライブラリから画像を選択 (\(selectedImageData.count)/\(maxSelectionCount))", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .disabled(selectedImageData.count >= maxSelectionCount)

                if !selectedImageData.isEmpty {
                    Text("選択中の画像:")
                        .font(.headline)
                        .padding([.top, .horizontal])

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(selectedImageData) { item in
                                if let uiImage = item.uiImage {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(alignment: .topTrailing) {
                                            Button { removeImage(item: item) } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4)
                                        }
                                } else {
                                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 100, height: 100).cornerRadius(8).overlay { Image(systemName: "exclamationmark.triangle").foregroundColor(.red) }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                     Text("キャラクターの学習に使用する画像を10枚まで選択してください。")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding()
                }
                Spacer()
            }
            .navigationTitle("キャラ作成")
            .navigationBarTitleDisplayMode(.inline)
            // --- 修正: onChangeの形式を変更 ---
            .onChange(of: selectedItems) { // 引数なしのクロージャに変更
                Task {
                    // クロージャ内で selectedItems を直接参照
                    let currentSelection = selectedItems

                    selectedImageData.removeAll() // 既存をクリア

                    for item in currentSelection { // 直接 selectedItems を使う
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            if selectedImageData.count < maxSelectionCount {
                                selectedImageData.append(SelectedImageItem(imageData: data))
                            }
                        } else {
                            print("画像のロードに失敗しました: \(item)")
                        }
                    }
                    // 注意: PhotosPickerの選択状態のリセットは、この形式では不要になることが多い
                    // selectedItems = [] // ← 必要に応じて残すか削除
                }
            }
            // --- ここまで修正 ---
        }
    }

    private func removeImage(item: SelectedImageItem) {
        selectedImageData.removeAll { $0.id == item.id }
        // PhotosPickerの選択状態からの削除ロジックは、
        // onChangeの挙動変更により見直しが必要な場合があります。
        // 一旦コメントアウトまたは削除し、必要なら再実装します。
        // if let itemToRemove = selectedItems.first(where: { $0.itemIdentifier == itemIdentifier(for: item) }) {
        //     selectedItems.removeAll { $0.itemIdentifier == itemToRemove.itemIdentifier }
        // }
    }

    // このヘルパー関数は現状不要
    // private func itemIdentifier(for selectedItem: SelectedImageItem) -> String? { return nil }
}

#Preview {
    CharacterCreationView()
}
