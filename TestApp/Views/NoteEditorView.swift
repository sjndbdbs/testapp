import SwiftUI
import UniformTypeIdentifiers
import AVKit

// MARK: - Note Editor
struct NoteEditorView: View {
    @EnvironmentObject var storage: StorageManager
    @State var item: FolderItem
    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏：粘贴 | 复制 | 保存
            HStack(spacing: 12) {
                Button { text = UIPasteboard.general.string ?? "" } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button { UIPasteboard.general.string = text } label: {
                    Label("复制全文", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(text.isEmpty)

                Spacer()

                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            Divider()

            TextEditor(text: $text)
                .padding(.horizontal, 8)
        }
        .onAppear { text = item.content ?? "" }
        .onDisappear { save() }
        .navigationTitle(item.name)
    }

    private func save() {
        var updated = item
        updated.content = text
        storage.updateNote(updated)
    }
}

// MARK: - Media Detail
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
            .navigationTitle(type == .folder ? "新建文件夹" : "新建笔记")
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

// MARK: - Media Picker
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
                onPick(data, "VID_\(Int(Date().timeIntervalSince1970))")
                picker.dismiss(animated: true)
                return
            }
            if let img = info[.originalImage] as? UIImage,
               let data = img.jpegData(compressionQuality: 0.8) {
                onPick(data, "IMG_\(Int(Date().timeIntervalSince1970))")
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
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .data, .pdf, .text, .plainText, .image,
            .movie, .audio, .archive, .spreadsheet
        ])
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
