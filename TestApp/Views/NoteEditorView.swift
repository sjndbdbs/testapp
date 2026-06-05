import SwiftUI
import UniformTypeIdentifiers
import AVKit

// MARK: - Note Editor
struct NoteEditorView: View {
    @EnvironmentObject var storage: StorageManager
    @State var item: FolderItem
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .focused($focused)
            .padding()
            .onAppear {
                text = item.content ?? ""
                focused = true
            }
            .onDisappear { save() }
            .navigationTitle(item.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                }
            }
    }

    private func save() {
        var updated = item
        updated.content = text
        storage.updateNote(updated)
    }
}

// MARK: - Media Detail (image & video)
struct MediaDetailView: View {
    let item: FolderItem
    @EnvironmentObject var storage: StorageManager

    var body: some View {
        Group {
            if item.type == .video, let url = storage.mediaURL(for: item) {
                VideoPlayer(player: AVPlayer(url: url))
                    .navigationTitle(item.name)
            } else if let url = storage.mediaURL(for: item),
                      let data = try? Data(contentsOf: url),
                      let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .navigationTitle(item.name)
            } else {
                Text("无法加载")
            }
        }
    }
}

// MARK: - Create Sheet
struct CreateSheet: View {
    @Binding var name: String
    let type: ItemType
    let onCreate: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField(type == .folder ? "文件夹名" : "笔记标题", text: $name)
            }
            .navigationTitle(type == .folder ? "新建文件夹" :
                             type == .note ? "新建笔记" : "新建")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { onCreate() }.disabled(name.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onCreate() }
                }
            }
        }
    }
}

// MARK: - Media Picker (photo + video)
struct MediaPickerView: UIViewControllerRepresentable {
    let isVideo: Bool
    let onPick: (Data, String) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = isVideo ? ["public.movie"] : ["public.image"]
        if isVideo { picker.videoQuality = .typeMedium }
        return picker
    }

    func updateUIViewController(_ uiVC: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (Data, String) -> Void
        init(onPick: @escaping (Data, String) -> Void) { self.onPick = onPick }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let videoURL = info[.mediaURL] as? URL,
               let data = try? Data(contentsOf: videoURL) {
                let name = "VID_\(Int(Date().timeIntervalSince1970))"
                onPick(data, name)
                picker.dismiss(animated: true)
                return
            }
            if let img = info[.originalImage] as? UIImage,
               let data = img.jpegData(compressionQuality: 0.8) {
                let name = "IMG_\(Int(Date().timeIntervalSince1970))"
                onPick(data, name)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker
struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data, UTType.pdf, UTType.text, UTType.plainText, UTType.image, UTType.movie, UTType.audio, UTType.archive, UTType.spreadsheet])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiVC: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let gotAccess = url.startAccessingSecurityScopedResource()
            defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
            onPick(url)
        }
    }
}
