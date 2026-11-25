import SwiftUI
import Combine
import AppKit
import Fuse

enum CardGlassMode: String, CaseIterable, Identifiable, Codable {
    case off         = "off"
    case blur        = "blur"
    case liquidGlass = "liquidGlass"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:         return L10n.shared.t("Tắt", "Off")
        case .blur:        return "Blur"
        case .liquidGlass: return "Liquid Glass"
        }
    }
}

enum CardStyle: String {
    case rectangular = "Rectangular"
    case wedge = "Wedge"
}

enum GlassTheme: String {
    case dark = "Dark"
    case light = "Light"
}

// MARK: - Background Styles (Figma)
enum BackgroundStyle: String, CaseIterable, Identifiable, Codable {
    case glassDark = "Glass Dark"
    case glassLight = "Glass Light"
    case solidLight = "Solid Light"
    case glassGradientDark = "Glass Gradient Dark"
    case glassSolidDark = "Glass Solid Dark"
    case glassSolidLight = "Glass Solid Light"
    case solidDark = "Solid Dark"
    case glassGradientBlue = "Glass Gradient Blue"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .glassDark: return "Glass Tối (Style 1)"
        case .glassLight: return "Glass Sáng (Style 2)"
        case .solidLight: return "Lấp đầy Sáng (Style 3)"
        case .glassGradientDark: return "Glass Gradient Tối (Style 4)"
        case .glassSolidDark: return "Glass Đen đặc (Style 5)"
        case .glassSolidLight: return "Glass Trắng đặc (Style 6)"
        case .solidDark: return "Lấp đầy Tối (Style 7)"
        case .glassGradientBlue: return "Glass Gradient Xanh (Style 8)"
        }
    }
    
    var hasBlur: Bool {
        switch self {
        case .solidLight, .solidDark:
            return false
        default:
            return true
        }
    }
    
    var isLight: Bool {
        switch self {
        case .glassLight, .solidLight, .glassSolidLight:
            return true
        default:
            return false
        }
    }
    
    func fill(isSelected: Bool) -> AnyShapeStyle {
        switch self {
        case .glassDark:
            return AnyShapeStyle(Color.black.opacity(isSelected ? 0.60 : 0.40))
        case .glassLight:
            return AnyShapeStyle(Color.white.opacity(isSelected ? 0.50 : 0.30))
        case .solidLight:
            if isSelected {
                return AnyShapeStyle(Color(red: 221/255, green: 221/255, blue: 221/255))
            } else {
                return AnyShapeStyle(Color.white)
            }
        case .glassGradientDark:
            let startOpacity = isSelected ? 0.70 : 0.50
            let endOpacity = isSelected ? 0.30 : 0.10
            return AnyShapeStyle(LinearGradient(
                colors: [Color.black.opacity(startOpacity), Color.white.opacity(endOpacity)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .glassSolidDark:
            if isSelected {
                return AnyShapeStyle(Color(red: 66/255, green: 66/255, blue: 66/255))
            } else {
                return AnyShapeStyle(Color.black)
            }
        case .glassSolidLight:
            if isSelected {
                return AnyShapeStyle(Color(red: 221/255, green: 221/255, blue: 221/255))
            } else {
                return AnyShapeStyle(Color.white)
            }
        case .solidDark:
            if isSelected {
                return AnyShapeStyle(Color(red: 66/255, green: 66/255, blue: 66/255))
            } else {
                return AnyShapeStyle(Color.black)
            }
        case .glassGradientBlue:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 54/255, green: 32/255, blue: 1.0), Color(red: 1/255, green: 24/255, blue: 68/255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
    }
    
    var selectedOverlayFill: AnyShapeStyle {
        switch self {
        case .glassGradientBlue:
            return AnyShapeStyle(Color.white.opacity(0.10))
        default:
            return AnyShapeStyle(Color.clear)
        }
    }
    
    func strokeGradient(isSelected: Bool) -> LinearGradient {
        let isLight = self.isLight
        let opStart = isSelected ? (isLight ? 0.55 : 0.48) : (isLight ? 0.35 : 0.24)
        let opEnd = isLight ? 0.16 : 0.08
        
        switch self {
        case .glassGradientBlue:
            return LinearGradient(
                colors: [Color.white.opacity(isSelected ? 0.8 : 0.4), Color.blue.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.white.opacity(opStart), Color.white.opacity(opEnd)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    func tooltipFill() -> AnyShapeStyle {
        switch self {
        case .glassDark:
            return AnyShapeStyle(Color.black.opacity(0.85))
        case .glassLight:
            return AnyShapeStyle(Color.white.opacity(0.85))
        case .solidLight:
            return AnyShapeStyle(Color.white)
        case .glassGradientDark:
            return AnyShapeStyle(LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .glassSolidDark:
            return AnyShapeStyle(Color.black)
        case .glassSolidLight:
            return AnyShapeStyle(Color.white)
        case .solidDark:
            return AnyShapeStyle(Color.black)
        case .glassGradientBlue:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 54/255, green: 32/255, blue: 1.0).opacity(0.9), Color(red: 1/255, green: 24/255, blue: 68/255).opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
    }
    
    var tooltipTextColor: Color {
        self.isLight ? .black : .white
    }
    
    var tooltipStrokeColor: Color {
        switch self {
        case .glassGradientBlue:
            return Color.white.opacity(0.3)
        default:
            return self.isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.2)
        }
    }
}

// MARK: - Card Preset
struct CardPreset: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    
    var cardStyle: String
    var wedgeSpacing: Double
    var wedgeInnerRadius: Double
    var wedgeOuterRadius: Double
    var wedgeCornerRadius: Double
    var wedgeIconSize: Double
    var fanOverlap: Double
    
    var rectSpacing: Double
    var rectArcRadius: Double
    var rectCardWidth: Double
    var rectCardHeightMultiplier: Double
    var rectCornerRadius: Double
    var rectIconSize: Double
    
    public var showAppName: Bool
    public var enableHoverZoom: Bool
    public var startAngle: Double
    public var cardOpacity: Double
    public var glassTheme: String
    public var backgroundStyle: String
    public var glassMode: String?
    public var showCardBorder: Bool?
}

class LauncherViewModel: ObservableObject {
    var usageCounts: [String: Int] = [:]
    @Published var runningBundleIds: Set<String> = []
    @Published var audioPlayingBundleIds: Set<String> = []
    @Published var results: [AppItem] = []
    @Published var selectedIndex: Int = 0
    @Published var searchText: String = ""
    
    var useCustomList: Bool = false
    @Published var cardStyle: CardStyle = .wedge
    @Published var showAppName: Bool = true
    @Published var enableHoverZoom: Bool = true
    @Published var startAngle: Double = -70.0
    @Published var cardOpacity: Double = 0.85
    @Published var glassTheme: GlassTheme = .dark
    @Published var backgroundStyle: BackgroundStyle = .glassDark
    @Published var hideInactiveApps: Bool = false
    
    @Published var wedgeIconSize: Double = 48.0
    @Published var fanOverlap: Double = 8.0
    @Published var wedgeSpacing: Double = 36.0
    @Published var wedgeInnerRadius: Double = 100.0
    @Published var wedgeOuterRadius: Double = 210.0
    @Published var wedgeCornerRadius: Double = 12.0
    
    // Rectangular Specific
    @Published var rectSpacing: Double = 32.0
    @Published var rectArcRadius: Double = 180.0
    @Published var rectCardWidth: Double = 88.0
    @Published var rectCardHeightMultiplier: Double = 1.25
    @Published var rectCornerRadius: Double = 16.0
    @Published var rectIconSize: Double = 64.0
    @Published var showCardBorder: Bool = true
    @Published var cardBlur: Double = 48.0
    @Published var glassMode: CardGlassMode = .blur

    private let fuse = Fuse()
    private var defaultsObserver: AnyCancellable?

    init() {
        loadUsageCounts()
        refreshApps()
        
        // Gộp các thay đổi liên tiếp (ví dụ kéo slider trong Settings) thành một lần làm mới.
        defaultsObserver = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshApps()
            }
    }
    
    func refreshApps() {
        useCustomList = UserDefaults.standard.bool(forKey: "UseCustomList")
        hideInactiveApps = UserDefaults.standard.bool(forKey: "HideInactiveApps")
        
        let styleStr = UserDefaults.standard.string(forKey: "CardStyle") ?? "Wedge"
        cardStyle = CardStyle(rawValue: styleStr) ?? .wedge
        
        if UserDefaults.standard.object(forKey: "ShowAppName") == nil {
            showAppName = true
        } else {
            showAppName = UserDefaults.standard.bool(forKey: "ShowAppName")
        }
        
        enableHoverZoom = true

        if UserDefaults.standard.object(forKey: "ShowCardBorder") == nil {
            showCardBorder = true
        } else {
            showCardBorder = UserDefaults.standard.bool(forKey: "ShowCardBorder")
        }
        
        startAngle = UserDefaults.standard.object(forKey: "StartAngle") as? Double ?? -70.0
        cardOpacity = UserDefaults.standard.object(forKey: "CardOpacity") as? Double ?? 0.65
        cardBlur = UserDefaults.standard.object(forKey: "CardBlurRadius") as? Double ?? 48.0
        if let rawMode = UserDefaults.standard.string(forKey: "CardGlassMode"),
           let mode = CardGlassMode(rawValue: rawMode) {
            glassMode = mode
        } else {
            glassMode = cardBlur > 0.5 ? .blur : .off
        }
        glassTheme = GlassTheme(rawValue: UserDefaults.standard.string(forKey: "GlassTheme") ?? "Dark") ?? .dark
        
        let bgStyleStr = UserDefaults.standard.string(forKey: "BackgroundStyle") ?? "Glass Dark"
        var resolvedStyle = BackgroundStyle(rawValue: bgStyleStr) ?? .glassDark
        if UserDefaults.standard.string(forKey: "ToneMode") == "auto" {
            let isSystemDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hasBlur = resolvedStyle.hasBlur
            resolvedStyle = isSystemDark ? (hasBlur ? .glassDark : .solidDark) : (hasBlur ? .glassLight : .solidLight)
        }
        backgroundStyle = resolvedStyle
        
        // Load Wedge
        wedgeSpacing = UserDefaults.standard.object(forKey: "WedgeSpacing") as? Double ?? 36.0
        wedgeInnerRadius = UserDefaults.standard.object(forKey: "WedgeInnerRadius") as? Double ?? 100.0
        wedgeOuterRadius = UserDefaults.standard.object(forKey: "WedgeOuterRadius") as? Double ?? 210.0
        wedgeCornerRadius = UserDefaults.standard.object(forKey: "WedgeCornerRadius") as? Double ?? 12.0
        wedgeIconSize = UserDefaults.standard.object(forKey: "WedgeIconSize") as? Double ?? 48.0
        fanOverlap = UserDefaults.standard.object(forKey: "FanOverlap") as? Double ?? 8.0
        
        // Load Rect
        rectSpacing = UserDefaults.standard.object(forKey: "RectSpacing") as? Double ?? 32.0
        rectArcRadius = UserDefaults.standard.object(forKey: "RectArcRadius") as? Double ?? 180.0
        rectCardWidth = UserDefaults.standard.object(forKey: "RectCardWidth") as? Double ?? 88.0
        rectCardHeightMultiplier = UserDefaults.standard.object(forKey: "RectCardHeightMultiplier") as? Double ?? 1.25
        rectCornerRadius = UserDefaults.standard.object(forKey: "RectCornerRadius") as? Double ?? 16.0
        rectIconSize = UserDefaults.standard.object(forKey: "RectIconSize") as? Double ?? 64.0

        var baseApps: [AppItem] = []

        if useCustomList {
            if let data = UserDefaults.standard.data(forKey: "CustomAppPaths"),
               let paths = try? JSONDecoder().decode([String].self, from: data) {
                for path in paths {
                    let url = URL(fileURLWithPath: path)
                    let name = url.deletingPathExtension().lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: path)
                    let bundleId = Bundle(path: path)?.bundleIdentifier
                    baseApps.append(AppItem(name: name, path: path, icon: icon, bundleIdentifier: bundleId))
                }
            }
        } else {
            let runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            
            baseApps = runningApps.compactMap { app -> AppItem? in
                guard let name = app.localizedName, let path = app.bundleURL?.path else { return nil }
                let icon = app.icon ?? NSWorkspace.shared.icon(forFile: path)
                return AppItem(name: name, path: path, icon: icon, bundleIdentifier: app.bundleIdentifier)
            }
        }

        // Search logic
        if searchText.isEmpty {
            if hideInactiveApps {
                let runningBundleIds = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
                baseApps = baseApps.filter { app in
                    guard let bundleId = app.bundleIdentifier else { return false }
                    return runningBundleIds.contains(bundleId)
                }
            }
            
            // Re-sort by usage
            baseApps.sort { (usageCounts[$0.bundleIdentifier ?? ""] ?? 0) > (usageCounts[$1.bundleIdentifier ?? ""] ?? 0) }
            
            // Always include Finder at the beginning
            let finderPath = "/System/Library/CoreServices/Finder.app"
            if let finderIdx = baseApps.firstIndex(where: { $0.path == finderPath }) {
                let finder = baseApps.remove(at: finderIdx)
                baseApps.insert(finder, at: 0)
            } else if !useCustomList {
                let finderIcon = NSWorkspace.shared.icon(forFile: finderPath)
                baseApps.insert(AppItem(name: "Finder", path: finderPath, icon: finderIcon, bundleIdentifier: "com.apple.finder"), at: 0)
            }
            
            self.results = baseApps
        } else {
            let allApps = AppSearcher.getAllInstalledApps()
            let searchResults = fuse.search(searchText, in: allApps.map { $0.name })
            
            var matchedApps = searchResults.map { result in
                allApps[result.index]
            }
            
            // Re-sort matched apps by usage and score
            // Fuse score: 0 is perfect match, 1 is no match.
            // We want to prioritize usage for similar scores.
            matchedApps.sort { a, b in
                let countA = usageCounts[a.bundleIdentifier ?? ""] ?? 0
                let countB = usageCounts[b.bundleIdentifier ?? ""] ?? 0
                if countA != countB {
                    return countA > countB
                }
                return false // Keep Fuse's original order (score-based)
            }
            
            self.results = matchedApps
        }
        
        if selectedIndex >= results.count {
            selectedIndex = max(0, results.count - 1)
        }
        
        if searchText.isEmpty {
            refreshLiveStatuses()
        } else {
            // Update only the running apps, skipping costly AppleScript queries while typing
            let running = Set(
                NSWorkspace.shared.runningApplications
                    .compactMap(\.bundleIdentifier)
            )
            runningBundleIds = running
        }
    }


    func resetSearch() {
        searchText = ""
        refreshApps()
    }

    func loadUsageCounts() {
        usageCounts = UserDefaults.standard.dictionary(forKey: "UsageCounts") as? [String: Int] ?? [:]
    }

    func launchSelected(hidePanel: @escaping () -> Void) {
        guard selectedIndex >= 0 && selectedIndex < results.count else { return }
        let app = results[selectedIndex]
        let appURL = URL(fileURLWithPath: app.path)
        let bundleId = app.bundleIdentifier

        if let bundleId = bundleId {
            usageCounts[bundleId, default: 0] += 1
            UserDefaults.standard.set(usageCounts, forKey: "UsageCounts")
        }

        // Hide our launcher panel FIRST so WindowServer doesn't bounce focus back to the current Space.
        hidePanel()

        let resolvedURL = bundleId.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) } ?? appURL

        let runningApp: NSRunningApplication? = bundleId.flatMap { id in
            NSRunningApplication.runningApplications(withBundleIdentifier: id)
                .first { !$0.isTerminated }
        } ?? NSWorkspace.shared.runningApplications.first {
            !$0.isTerminated && $0.bundleURL?.standardizedFileURL == resolvedURL.standardizedFileURL
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        // Finder special behavior: always open/focus on the CURRENT Space instead of
        // pulling the user back to an older Space where another Finder window lives.
        if bundleId == "com.apple.finder" {
            openFinderInCurrentSpace(runningApp: runningApp)
            return
        }

        if let runningApp = runningApp {
            if runningApp.isHidden {
                runningApp.unhide()
            }
            // macOS 14+ Cooperative Activation: explicitly yield activation so macOS
            // switches to the Space/Desktop where the target app's windows live.
            if #available(macOS 14.0, *) {
                NSApp.yieldActivation(to: runningApp)
            }
            runningApp.activate(options: [.activateAllWindows])

            // Also send reopen via openApplication (mimics clicking the Dock icon:
            // triggers Space switching, unminimizes minimized windows, and opens a Finder window if none exist).
            NSWorkspace.shared.openApplication(at: resolvedURL, configuration: config, completionHandler: nil)
        } else {
            NSWorkspace.shared.openApplication(at: resolvedURL, configuration: config, completionHandler: nil)
        }
    }

    private func openFinderInCurrentSpace(runningApp: NSRunningApplication?) {
        // 1. Check if Finder already has a regular window on the CURRENT Space.
        // `.optionOnScreenOnly` only lists windows belonging to the active Space.
        if let finder = runningApp, hasVisibleWindowOnCurrentSpace(pid: finder.processIdentifier) {
            if finder.isHidden {
                finder.unhide()
            }
            if #available(macOS 14.0, *) {
                NSApp.yieldActivation(to: finder)
            }
            finder.activate(options: [])
            return
        }

        // 2. No Finder window on the current Space → open a new Finder window right here
        // using the user's configured Finder default ("New Finder windows show", defaulting to Recents).
        let targetURL = defaultFinderTargetURL()
        DispatchQueue.global(qos: .userInitiated).async {
            let source: String
            if let path = targetURL?.path {
                let escaped = path
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                source = """
                tell application id "com.apple.finder"
                    make new Finder window to (POSIX file "\(escaped)" as alias)
                    activate
                end tell
                """
            } else {
                source = """
                tell application id "com.apple.finder"
                    make new Finder window
                    activate
                end tell
                """
            }
            var error: NSDictionary?
            let script = NSAppleScript(source: source)
            script?.executeAndReturnError(&error)

            if error != nil {
                // Fallback if Automation permission for Finder is not granted
                let fallbackURL = targetURL ?? FileManager.default.homeDirectoryForCurrentUser
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(fallbackURL)
                }
            }
        }
    }

    private func defaultFinderTargetURL() -> URL? {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        if FileManager.default.fileExists(atPath: downloads.path) {
            return downloads
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private func hasVisibleWindowOnCurrentSpace(pid: pid_t) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return windowList.contains { info in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat else {
                return false
            }
            return width > 50 && height > 50
        }
    }

    func moveSelectionUp() {
        if selectedIndex > 0 { selectedIndex -= 1 }
    }
    func moveSelectionDown() {
        if selectedIndex < results.count - 1 { selectedIndex += 1 }
    }

    func refreshLiveStatuses() {
        let running = Set(
            NSWorkspace.shared.runningApplications
                .compactMap(\.bundleIdentifier)
        )
        runningBundleIds = running

        var playing: Set<String> = []
        if isPlayerAppActivelyPlaying(bundleId: "com.apple.Music") {
            playing.insert("com.apple.Music")
        }
        if isPlayerAppActivelyPlaying(bundleId: "com.spotify.client") {
            playing.insert("com.spotify.client")
        }
        audioPlayingBundleIds = playing
    }

    func isRunning(app: AppItem) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }
        return runningBundleIds.contains(bundleId)
    }

    func isAudioPlaying(app: AppItem) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }
        return audioPlayingBundleIds.contains(bundleId)
    }

    func runningApplication(for app: AppItem) -> NSRunningApplication? {
        if let bundleId = app.bundleIdentifier {
            return NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleId)
                .first
        }

        return NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.path == app.path
        }
    }

    func canQuit(app: AppItem) -> Bool {
        guard app.bundleIdentifier != "com.apple.finder" else { return false }
        return runningApplication(for: app) != nil
    }

    @discardableResult
    func quit(app: AppItem) -> Bool {
        guard let runningApp = runningApplication(for: app), canQuit(app: app) else {
            return false
        }

        let didRequestTerminate = runningApp.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.refreshApps()
        }
        return didRequestTerminate
    }

    private func isPlayerAppActivelyPlaying(bundleId: String) -> Bool {
        // Prevent calling AppleScript if the application is not running (prevents auto-launching/blocking)
        guard runningBundleIds.contains(bundleId) else {
            return false
        }
        
        let scriptSource: String
        switch bundleId {
        case "com.apple.Music":
            scriptSource = "tell application id \"com.apple.Music\" to if player state is playing then return \"playing\" else return \"not\""
        case "com.spotify.client":
            scriptSource = "tell application id \"com.spotify.client\" to if player state is playing then return \"playing\" else return \"not\""
        default:
            return false
        }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else {
            return false
        }
        let result = script.executeAndReturnError(&error)
        if error != nil {
            return false
        }
        return (result.stringValue ?? "") == "playing"
    }
}
