import Foundation
import UIKit

class StorageManager: ObservableObject {
    @Published var rootItems: [FolderItem] = []
    private let baseURL: URL
    private let dataFile: URL

    // helper to get current working parent in any view context
    @Published var currentParent: FolderItem? = nil

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        baseURL = docs.appendingPathComponent("MemoData")
        dataFile = baseURL.appendingPathComponent("data.json")
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        load()
        if rootItems.isEmpty {
            rootItems = [FolderItem(name: "默认文件夹", type: .folder, createdAt: Date())]
            save()
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: dataFile),
              let items = try? JSONDecoder().decode([FolderItem].self, from: data) else { return }
        rootItems = items
    }

    func save() {
        guard let data = try? JSONEncoder().encode(rootItems) else { return }
        try? data.write(to: dataFile)
    }

    // MARK: - Create

    func createFolder(named name: String, in parent: FolderItem? = nil) {
        let folder = FolderItem(name: name, type: .folder, createdAt: Date())
        addItem(folder, to: parent)
    }

    func createNote(named name: String, content: String = "", in parent: FolderItem? = nil) {
        let note = FolderItem(name: name, type: .note, content: content, createdAt: Date())
        addItem(note, to: parent)
    }

    @discardableResult
    func addMedia(named name: String, data: Data, isVideo: Bool = false, in parent: FolderItem? = nil) -> FolderItem {
        let ext = isVideo ? ".mp4" : ".jpg"
        let dirName = isVideo ? "Videos" : "Images"
        let dir = baseURL.appendingPathComponent(dirName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = UUID().uuidString + ext
        try? data.write(to: dir.appendingPathComponent(filename))
        let type: ItemType = isVideo ? .video : .image
        let item = FolderItem(name: name, type: type, attachmentPath: filename, createdAt: Date())
        addItem(item, to: parent)
        return item
    }

    func addFile(url: URL, in parent: FolderItem? = nil) {
        let filesDir = baseURL.appendingPathComponent("Files")
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)
        let filename = UUID().uuidString + "_" + url.lastPathComponent
        let dest = filesDir.appendingPathComponent(filename)
        try? FileManager.default.copyItem(at: url, to: dest)
        let item = FolderItem(name: url.lastPathComponent, type: .file,
                              attachmentPath: filename, originalFilename: url.lastPathComponent,
                              createdAt: Date())
        addItem(item, to: parent)
    }

    // MARK: - Update / Delete

    func updateNote(_ note: FolderItem) {
        replaceItem(note)
    }

    func deleteItem(_ item: FolderItem) {
        removeItem(id: item.id, from: &rootItems)
        save()
    }

    // MARK: - Path helpers

    func mediaURL(for item: FolderItem) -> URL? {
        guard let path = item.attachmentPath else { return nil }
        let dirName: String
        switch item.type {
        case .video: dirName = "Videos"
        case .image: dirName = "Images"
        case .file:  dirName = "Files"
        default:     return nil
        }
        return baseURL.appendingPathComponent(dirName).appendingPathComponent(path)
    }

    func copyToTemp(_ item: FolderItem) -> URL? {
        let src = mediaURL(for: item) ?? noteFileURL(for: item)
        guard let src else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(item.originalFilename ?? item.name)
        try? FileManager.default.removeItem(at: tmp)
        try? FileManager.default.copyItem(at: src, to: tmp)
        return tmp
    }

    func noteFileURL(for item: FolderItem) -> URL? {
        guard item.type == .note else { return nil }
        let notesDir = baseURL.appendingPathComponent("Notes")
        try? FileManager.default.createDirectory(at: notesDir, withIntermediateDirectories: true)
        return notesDir.appendingPathComponent(item.id + ".txt")
    }

    // MARK: - Private

    private func addItem(_ item: FolderItem, to parent: FolderItem?) {
        if let parent = parent, let idx = rootItems.firstIndex(where: { $0.id == parent.id }) {
            rootItems[idx].children = (rootItems[idx].children ?? []) + [item]
        } else if let parent = parent, let path = findPath(to: parent.id, in: rootItems) {
            var target = rootItems
            for (i, ancestor) in path.enumerated() {
                let idx = target.firstIndex(where: { $0.id == ancestor.id })!
                if i == path.count - 1 {
                    target[idx].children = (target[idx].children ?? []) + [item]
                } else {
                    target = target[idx].children ?? []
                }
            }
        } else {
            rootItems.append(item)
        }
        save()
    }

    private func replaceItem(_ item: FolderItem) {
        if let idx = rootItems.firstIndex(where: { $0.id == item.id }) {
            rootItems[idx] = item
            save()
            return
        }
        for i in rootItems.indices {
            if replaceInChildren(item: item, in: &rootItems[i]) { save(); return }
        }
    }

    private func replaceInChildren(item: FolderItem, in parent: inout FolderItem) -> Bool {
        guard var kids = parent.children else { return false }
        if let idx = kids.firstIndex(where: { $0.id == item.id }) {
            kids[idx] = item
            parent.children = kids
            return true
        }
        for i in kids.indices {
            if replaceInChildren(item: item, in: &kids[i]) {
                parent.children = kids
                return true
            }
        }
        return false
    }

    @discardableResult
    private func removeItem(id: String, from items: inout [FolderItem]) -> Bool {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            deleteFiles(for: items[idx])
            items.remove(at: idx)
            return true
        }
        for i in items.indices {
            if var children = items[i].children, removeItem(id: id, from: &children) {
                items[i].children = children
                return true
            }
        }
        return false
    }

    private func deleteFiles(for item: FolderItem) {
        if let p = item.attachmentPath {
            let dn: String
            switch item.type {
            case .image: dn = "Images"
            case .video: dn = "Videos"
            case .file:  dn = "Files"
            default:     return
            }
            try? FileManager.default.removeItem(at: baseURL.appendingPathComponent(dn).appendingPathComponent(p))
        }
        if item.type == .note {
            if let url = noteFileURL(for: item) { try? FileManager.default.removeItem(at: url) }
        }
        if item.type == .folder {
            for child in item.children ?? [] { deleteFiles(for: child) }
        }
    }

    private func findPath(to id: String, in items: [FolderItem]) -> [FolderItem]? {
        for item in items {
            if item.id == id { return [] }
            if let children = item.children {
                if let tail = findPath(to: id, in: children) {
                    return [item] + tail
                }
            }
        }
        return nil
    }
}
