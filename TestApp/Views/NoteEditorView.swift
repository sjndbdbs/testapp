import SwiftUI

struct NoteEditorView: View {
    @EnvironmentObject var storage: StorageManager
    @State var item: FolderItem
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .focused($focused)
                .padding()
                .onAppear { text = item.content ?? "" }
                .onDisappear {
                    var updated = item
                    updated.content = text
                    storage.updateNote(updated)
                }
        }
        .navigationTitle(item.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    var updated = item
                    updated.content = text
                    storage.updateNote(updated)
                }
            }
        }
    }
}

struct ImageDetailView: View {
    let item: FolderItem
    @EnvironmentObject var storage: StorageManager

    var body: some View {
        Group {
            if let url = storage.imageURL(for: item),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .navigationTitle(item.name)
            } else {
                Text("无法加载图片")
            }
        }
    }
}

struct CreateSheet: View {
    @Binding var name: String
    let type: ItemType
    let onCreate: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField(type == .folder ? "文件夹名" : "笔记标题", text: $name)
            }
            .navigationTitle(type == .folder ? "新建文件夹" : "新建笔记")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { onCreate() }
                        .disabled(name.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onCreate() }
                }
            }
        }
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    let onPick: (Data, String) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (Data, String) -> Void
        init(onPick: @escaping (Data, String) -> Void) { self.onPick = onPick }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage,
               let data = img.jpegData(compressionQuality: 0.8) {
                let name = "IMG_\(Date().timeIntervalSince1970)"
                onPick(data, name)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
