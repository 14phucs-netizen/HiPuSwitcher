import Foundation
import ServiceManagement

public struct LaunchAtLoginHelper {
    private static let cachedIsSupported: Bool = {
        // 1. Verify path first (must be inside an Applications folder)
        // This prevents App Translocation issues when run directly from Downloads/DMG.
        let path = Bundle.main.bundlePath
        let lowerPath = path.lowercased()
        let isInApplications = lowerPath.hasPrefix("/applications/") || lowerPath.contains("/applications/")
        guard isInApplications else {
            return false
        }

        // 2. Run codesign once in a subprocess to check for a valid TeamIdentifier.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-d", "--verbose", path]

        let pipe = Pipe()
        task.standardError = pipe // codesign prints details to stderr

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if output.contains("TeamIdentifier=") && !output.contains("TeamIdentifier=not set") {
                    return true
                }
            }
        } catch {
            print("Failed to run codesign subprocess: \(error)")
        }

        return false
    }()

    public static var isSupported: Bool {
        cachedIsSupported
    }
    
    public static var isEnabled: Bool {
        guard isSupported else { return false }
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    public static func setEnabled(_ enabled: Bool) {
        guard isSupported else { return }
        
        if #available(macOS 13.0, *) {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    do {
                        try SMAppService.mainApp.register()
                    } catch {
                        print("Failed to register launch at login: \(error)")
                    }
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    SMAppService.mainApp.unregister { error in
                        if let error = error {
                            print("Failed to unregister launch at login: \(error)")
                        }
                    }
                }
            }
        }
    }
}
