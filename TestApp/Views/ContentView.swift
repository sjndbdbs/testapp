import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var storage = StorageManager()
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var createType: ItemType = .folder
    @State private var showMediaPicker = false
    @State private var showFilePicker = false
    @State private var mediaIsVideo = false

    var body: some View {
        NavigationStack {
            FileListView(
                items: storage.rootItems,
                storage: storage,
                parent: nil
            )
            .navigationTitle("备忘录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { createType = .folder; showCreateSheet = true } label: {
                            Label("新建文件夹", systemImage: "folder.badge.plus")
                        }
                        Button { createType = .note; showCreateSheet = true } label: {
                            Label("新建笔记", systemImage: "doc.badge.plus")
                        }
                        Divider()
                        Button { mediaIsVideo = false; showMediaPicker = true } label: {
                            Label("添加图片", systemImage: "photo.badge.plus")
                        }
                        Button { mediaIsVideo = true; showMediaPicker = true } label: {
                            Label("添加视频", systemImage: "video.badge.plus")
                        }
                        Button { showFilePicker = true } label: {
                            Label("导入文件", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateSheet(name: $newName, type: createType) {
                    if createType == .folder {
                        storage.createFolder(named: newName)
                    } else {
                        storage.createNote(named: newName)
                    }
                    newName = ""; showCreateSheet = false
                }
            }
            .sheet(isPresented: $showMediaPicker) {
                MediaPickerView(isVideo: mediaIsVideo) { data, name in
                    storage.addMedia(named: name, data: data, isVideo: mediaIsVideo)
                    showMediaPicker = false
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPickerView { url in
                    storage.addFile(url: url)
                    showFilePicker = false
                }
            }
        }
        .environmentObject(storage)
    }
}

// MARK: - File List (used recursively)
struct FileListView: View {
    let items: [FolderItem]
    @ObservedObject var storage: StorageManager
    let parent: FolderItem?
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var createType: ItemType = .folder
    @State private var showMediaPicker = false
    @State private var showFilePicker = false
    @State private var mediaIsVideo = false

    var body: some View {
        List {
            ForEach(items) { item in
                if item.isFolder {
                    NavigationLink(value: item) {
                        Label(item.name, systemImage: "folder.fill")
                            .foregroundColor(.orange)
                    }
                } else if item.type == .image {
                    NavigationLink(value: item) {
                        Label(item.name, systemImage: "photo.fill")
                            .foregroundColor(.blue)
                    }
                } else if item.type == .video {
                    NavigationLink(value: item) {
                        Label(item.name, systemImage: "video.fill")
                            .foregroundColor(.purple)
                    }
                } else if item.type == .file {
                    HStack {
                        Label(item.originalFilename ?? item.name, systemImage: "doc.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Button {
                            if let tmp = storage.copyToTemp(item) {
                                let av = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
                                if let vc = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let root = vc.windows.first?.rootViewController {
                                    root.present(av, animated: true)
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                } else {
                    NavigationLink(value: item) {
                        Label(item.name, systemImage: "doc.text.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            .onDelete { offsets in
                for i in offsets { storage.deleteItem(items[i]) }
            }
        }
        .navigationTitle(parent?.name ?? "备忘录")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { createType = .folder; showCreateSheet = true } label: {
                        Label("新建文件夹", systemImage: "folder.badge.plus")
                    }
                    Button { createType = .note; showCreateSheet = true } label: {
                        Label("新建笔记", systemImage: "doc.badge.plus")
                    }
                    Divider()
                    Button { mediaIsVideo = false; showMediaPicker = true } label: {
                        Label("添加图片", systemImage: "photo.badge.plus")
                    }
                    Button { mediaIsVideo = true; showMediaPicker = true } label: {
                        Label("添加视频", systemImage: "video.badge.plus")
                    }
                    Button { showFilePicker = true } label: {
                        Label("导入文件", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: FolderItem.self) { item in
            if item.isFolder {
                FileListView(
                    items: item.children ?? [],
                    storage: storage,
                    parent: item
                )
            } else if item.type == .image || item.type == .video {
                MediaDetailView(item: item)
            } else {
                NoteEditorView(item: item)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateSheet(name: $newName, type: createType) {
                if createType == .folder {
                    storage.createFolder(named: newName, in: parent)
                } else {
                    storage.createNote(named: newName, in: parent)
                }
                newName = ""; showCreateSheet = false
            }
        }
        .sheet(isPresented: $showMediaPicker) {
            MediaPickerView(isVideo: mediaIsVideo) { data, name in
                storage.addMedia(named: name, data: data, isVideo: mediaIsVideo, in: parent)
                showMediaPicker = false
            }
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPickerView { url in
                storage.addFile(url: url, in: parent)
                showFilePicker = false
            }
        }
    }
}
