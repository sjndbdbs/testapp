import Foundation

enum ItemType: String, Codable {
    case folder
    case note
    case image
    case video
    case file
}

struct FolderItem: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var name: String
    var type: ItemType
    var children: [FolderItem]?
    var content: String?
    var attachmentPath: String?
    var originalFilename: String? // for imported files
    var createdAt: Date

    var isFolder: Bool { type == .folder }
}
