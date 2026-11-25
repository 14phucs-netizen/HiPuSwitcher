import Foundation

extension Bundle {
    private static let swizzleInitWithPath: Void = {
        let originalSelector = #selector(Bundle.init(path:))
        let swizzledSelector = #selector(Bundle.init(customPath:))
        
        guard let originalMethod = class_getInstanceMethod(Bundle.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(Bundle.self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()
    
    /// Starts swizzling Bundle.init(path:) to redirect SwiftPM resource bundle lookups
    /// from the app bundle root to Contents/Resources.
    public static func startSwizzling() {
        _ = swizzleInitWithPath
    }
    
    @objc convenience init?(customPath: String) {
        var finalPath = customPath
        
        if !FileManager.default.fileExists(atPath: customPath) && customPath.hasSuffix(".bundle") {
            let url = URL(fileURLWithPath: customPath)
            let bundleName = url.lastPathComponent
            
            // Check if the bundle exists inside Contents/Resources/ of the main bundle
            if let resourcesURL = Bundle.main.resourceURL {
                let redirectedURL = resourcesURL.appendingPathComponent(bundleName)
                if FileManager.default.fileExists(atPath: redirectedURL.path) {
                    finalPath = redirectedURL.path
                }
            }
        }
        
        // This calls the original initWithPath because of the swizzle
        self.init(customPath: finalPath)
    }
}
