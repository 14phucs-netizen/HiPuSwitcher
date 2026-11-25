import Foundation
import AppKit

class AppSearcher {
    static func getRunningApps() -> [AppItem] {
        var apps: [AppItem] = []
        var uniquePaths = Set<String>()
        
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.activationPolicy == .regular, let url = app.bundleURL {
                let path = url.path
                if !uniquePaths.contains(path) {
                    uniquePaths.insert(path)
                    let name = url.deletingPathExtension().lastPathComponent
                    let icon = app.icon ?? NSWorkspace.shared.icon(forFile: path)
                    let bundleId = app.bundleIdentifier
                    apps.append(AppItem(name: name, path: path, icon: icon, bundleIdentifier: bundleId))
                }
            }
        }
        return apps
    }
    
    static var cachedInstalledApps: [AppItem]? = nil
    
    static func getAllInstalledApps() -> [AppItem] {
        if let cached = cachedInstalledApps {
            return cached
        }
        
        let appDirs = ["/Applications", "/System/Applications", "/System/Library/CoreServices"]
        var apps: [AppItem] = []
        let fm = FileManager.default
        
        for dir in appDirs {
            guard let urls = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
            
            for url in urls where url.pathExtension == "app" {
                let path = url.path
                let name = url.deletingPathExtension().lastPathComponent
                let bundleId = Bundle(path: path)?.bundleIdentifier
                apps.append(AppItem(name: name, path: path, icon: nil, bundleIdentifier: bundleId))
            }
        }
        
        cachedInstalledApps = apps
        return apps
    }
}