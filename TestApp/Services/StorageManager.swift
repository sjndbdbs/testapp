import Foundation
import UIKit

class StorageManager: ObservableObject {
    @Published var rootItems: [FolderItem] = []
    private let baseURL: URL
    private let dataFile: URL

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

    func createFolder(named name: String, in parent: FolderItem? = nil) {
        let folder = FolderItem(name: name, type: .folder, createdAt: Date())
        if var parent = parent, let idx = findIndex(of: parent.id, in: &rootItems) {
            rootItems[idx].children = (rootItems[idx].children ?? []) + [folder]
        } else {
            rootItems.append(folder)
        }
        save()
    }

    func createNote(named name: String, content: String = "", in parent: FolderItem? = nil) {
        let note = FolderItem(name: name, type: .note, content: content, createdAt: Date())
        if var parent = parent, let idx = findIndex(of: parent.id, in: &rootItems) {
            rootItems[idx].children = (rootItems[idx].children ?? []) + [note]
        } else {
            rootItems.append(note)
        }
        save()
    }

    func updateNote(_ note: FolderItem) {
        if let idx = findIndex(of: note.id, in: &rootItems) {
            rootItems[idx] = note
            save()
        }
    }

    func deleteItem(_ item: FolderItem) {
        removeItem(id: item.id, from: &rootItems)
        save()
    }

    func addImage(named name: String, data: Data, to parent: FolderItem? = nil) {
        let imgDir = baseURL.appendingPathComponent("Images")
        try? FileManager.default.createDirectory(at: imgDir, withIntermediateDirectories: true)
        let filename = UUID().uuidString + ".jpg"
        try? data.write(to: imgDir.appendingPathComponent(filename))
        let img = FolderItem(name: name, type: .image, attachmentPath: filename, createdAt: Date())
        if var parent = parent, let idx = findIndex(of: parent.id, in: &rootItems) {
            rootItems[idx].children = (rootItems[idx].children ?? []) + [img]
        } else {
            rootItems.append(img)
        }
        save()
    }

    func imageURL(for item: FolderItem) -> URL? {
        guard let path = item.attachmentPath else { return nil }
        return baseURL.appendingPathComponent("Images").appendingPathComponent(path)
    }

    // MARK: - helpers

    private func findIndex(of id: String, in items: inout [FolderItem]) -> Int? {
        items.firstIndex { $0.id == id }
    }

    @discardableResult
    private func removeItem(id: String, from items: inout [FolderItem]) -> Bool {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            if items[idx].type == .folder {
                // also delete children files
                for child in items[idx].children ?? [] {
                    if let p = child.attachmentPath {
                        try? FileManager.default.removeItem(at: baseURL.appendingPathComponent("Images").appendingPathComponent(p))
                    }
                }
            }
            if let p = items[idx].attachmentPath {
                try? FileManager.default.removeItem(at: baseURL.appendingPathComponent("Images").appendingPathComponent(p))
            }
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
}
