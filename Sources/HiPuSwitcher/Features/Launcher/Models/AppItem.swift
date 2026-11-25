import Foundation
import AppKit

struct AppItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    private let _icon: NSImage?
    let bundleIdentifier: String?
    
    var icon: NSImage {
        if let icon = _icon {
            return icon
        }
        return NSWorkspace.shared.icon(forFile: path)
    }
    
    init(name: String, path: String, icon: NSImage? = nil, bundleIdentifier: String?) {
        self.name = name
        self.path = path
        self._icon = icon
        self.bundleIdentifier = bundleIdentifier
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.path == rhs.path
    }
}