import SwiftUI

struct ContentView: View {
    @StateObject private var storage = StorageManager()
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var createType: ItemType = .folder
    @State private var selectedFolder: FolderItem?
    @State private var navigationPath: [FolderItem] = []
    @State private var showImagePicker = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            FileListView(
                items: storage.rootItems,
                storage: storage,
                navigationPath: $navigationPath,
                showImagePicker: $showImagePicker
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
                        Button { showImagePicker = true } label: {
                            Label("添加图片", systemImage: "photo.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: FolderItem.self) { folder in
                FileListView(
                    items: folder.children ?? [],
                    storage: storage,
                    navigationPath: $navigationPath,
                    title: folder.name,
                    parent: folder,
                    showImagePicker: $showImagePicker
                )
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateSheet(name: $newName, type: createType) {
                    if createType == .folder {
                        storage.createFolder(named: newName, in: selectedFolder)
                    } else {
                        storage.createNote(named: newName, in: selectedFolder)
                    }
                    newName = ""
                    showCreateSheet = false
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView { data, name in
                    storage.addImage(named: name, data: data, to: selectedFolder)
                    showImagePicker = false
                }
            }
        }
        .environmentObject(storage)
    }
}

struct FileListView: View {
    let items: [FolderItem]
    @ObservedObject var storage: StorageManager
    @Binding var navigationPath: [FolderItem]
    var title: String? = nil
    var parent: FolderItem? = nil
    @Binding var showImagePicker: Bool

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
                } else {
                    NavigationLink(value: item) {
                        Label(item.name, systemImage: "doc.text.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            .onDelete { offsets in
                for i in offsets {
                    storage.deleteItem(items[i])
                }
            }
        }
        .navigationTitle(title ?? "备忘录")
        .navigationDestination(for: FolderItem.self) { item in
            if item.isFolder {
                FileListView(
                    items: item.children ?? [],
                    storage: storage,
                    navigationPath: $navigationPath,
                    title: item.name,
                    parent: item,
                    showImagePicker: $showImagePicker
                )
            } else if item.type == .image {
                ImageDetailView(item: item)
            } else {
                NoteEditorView(item: item)
            }
        }
    }
}
