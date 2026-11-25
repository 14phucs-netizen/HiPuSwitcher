import SwiftUI
import KeyboardShortcuts
import AppKit
import UniformTypeIdentifiers
import ServiceManagement
import HiPuShared

enum DoubleTapMode: String, CaseIterable, Identifiable {
    case none = "none"
    case doubleShift = "doubleShift"
    case doubleOption = "doubleOption"
    case doubleCmd = "doubleCmd"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "Tắt (Chỉ dùng phím tắt)"
        case .doubleShift: return "Nhấn 2 lần phím Shift (⇧ ⇧)"
        case .doubleOption: return "Nhấn 2 lần phím Option (⌥ ⌥)"
        case .doubleCmd: return "Nhấn 2 lần phím Command (⌘ ⌘)"
        }
    }
}

// MARK: - ViewModel

class SettingsViewModel: ObservableObject {
    @Published var customAppPaths: [String] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(customAppPaths) {
                UserDefaults.standard.set(data, forKey: "CustomAppPaths")
            }
        }
    }
    @Published var useCustomList: Bool {
        didSet { UserDefaults.standard.set(useCustomList, forKey: "UseCustomList") }
    }
    @Published var cardStyle: CardStyle {
        didSet { UserDefaults.standard.set(cardStyle.rawValue, forKey: "CardStyle") }
    }
    @Published var showAppName: Bool {
        didSet { UserDefaults.standard.set(showAppName, forKey: "ShowAppName") }
    }
    @Published var enableHoverZoom: Bool {
        didSet { UserDefaults.standard.set(enableHoverZoom, forKey: "EnableHoverZoom") }
    }
    @Published var showCardBorder: Bool {
        didSet { UserDefaults.standard.set(showCardBorder, forKey: "ShowCardBorder") }
    }
    @Published var startAngle: Double {
        didSet { UserDefaults.standard.set(startAngle, forKey: "StartAngle") }
    }
    @Published var cardOpacity: Double {
        didSet { UserDefaults.standard.set(cardOpacity, forKey: "CardOpacity") }
    }
    @Published var cardBlur: Double {
        didSet { UserDefaults.standard.set(cardBlur, forKey: "CardBlurRadius") }
    }
    @Published var glassMode: CardGlassMode {
        didSet {
            UserDefaults.standard.set(glassMode.rawValue, forKey: "CardGlassMode")
            // Keep cardBlur synced for compatibility
            let targetBlur: Double = (glassMode == .off) ? 0.0 : 48.0
            if cardBlur != targetBlur {
                cardBlur = targetBlur
            }
        }
    }
    @Published var toneMode: String {
        didSet { UserDefaults.standard.set(toneMode, forKey: "ToneMode") }
    }
    @Published var glassTheme: GlassTheme {
        didSet { UserDefaults.standard.set(glassTheme.rawValue, forKey: "GlassTheme") }
    }
    @Published var backgroundStyle: BackgroundStyle {
        didSet {
            UserDefaults.standard.set(backgroundStyle.rawValue, forKey: "BackgroundStyle")
            // Keep glassTheme in sync for compatibility
            self.glassTheme = backgroundStyle.isLight ? .light : .dark
        }
    }
    @Published var presets: [CardPreset] = []
    @Published var newPresetName: String = ""

    @Published var wedgeSpacing: Double {
        didSet { UserDefaults.standard.set(wedgeSpacing, forKey: "WedgeSpacing") }
    }
    @Published var wedgeInnerRadius: Double {
        didSet { UserDefaults.standard.set(wedgeInnerRadius, forKey: "WedgeInnerRadius") }
    }
    @Published var wedgeOuterRadius: Double {
        didSet { UserDefaults.standard.set(wedgeOuterRadius, forKey: "WedgeOuterRadius") }
    }
    @Published var wedgeCornerRadius: Double {
        didSet { UserDefaults.standard.set(wedgeCornerRadius, forKey: "WedgeCornerRadius") }
    }
    @Published var wedgeIconSize: Double {
        didSet { UserDefaults.standard.set(wedgeIconSize, forKey: "WedgeIconSize") }
    }
    @Published var fanOverlap: Double {
        didSet { UserDefaults.standard.set(fanOverlap, forKey: "FanOverlap") }
    }
    @Published var rectSpacing: Double {
        didSet { UserDefaults.standard.set(rectSpacing, forKey: "RectSpacing") }
    }
    @Published var rectArcRadius: Double {
        didSet { UserDefaults.standard.set(rectArcRadius, forKey: "RectArcRadius") }
    }
    @Published var rectCardWidth: Double {
        didSet { UserDefaults.standard.set(rectCardWidth, forKey: "RectCardWidth") }
    }
    @Published var rectCardHeightMultiplier: Double {
        didSet { UserDefaults.standard.set(rectCardHeightMultiplier, forKey: "RectCardHeightMultiplier") }
    }
    @Published var rectCornerRadius: Double {
        didSet { UserDefaults.standard.set(rectCornerRadius, forKey: "RectCornerRadius") }
    }
    @Published var rectIconSize: Double {
        didSet { UserDefaults.standard.set(rectIconSize, forKey: "RectIconSize") }
    }
    @Published var hideInactiveApps: Bool {
        didSet { UserDefaults.standard.set(hideInactiveApps, forKey: "HideInactiveApps") }
    }
    @Published var enableMiddleClickTrigger: Bool {
        didSet {
            UserDefaults.standard.set(enableMiddleClickTrigger, forKey: "EnableMiddleClickTrigger")
            NotificationCenter.default.post(name: Notification.Name("MiddleClickTriggerChanged"), object: nil)
        }
    }
    @Published var doubleTapMode: DoubleTapMode {
        didSet {
            UserDefaults.standard.set(doubleTapMode.rawValue, forKey: "DoubleTapMode")
        }
    }
    @Published var enableFnShiftTrigger: Bool {
        didSet {
            UserDefaults.standard.set(enableFnShiftTrigger, forKey: "EnableFnShiftTrigger")
        }
    }
    
    @Published var launchAtLogin: Bool = false {
        didSet {
            toggleLaunchAtLogin(launchAtLogin)
        }
    }
    
    @Published var isAccessibilityGranted: Bool = false
    
    init() {
        let dtRaw = UserDefaults.standard.string(forKey: "DoubleTapMode") ?? "none"
        self.doubleTapMode = DoubleTapMode(rawValue: dtRaw) ?? .none
        self.enableFnShiftTrigger = UserDefaults.standard.bool(forKey: "EnableFnShiftTrigger")
        self.enableMiddleClickTrigger = UserDefaults.standard.bool(forKey: "EnableMiddleClickTrigger")
        self.useCustomList = UserDefaults.standard.bool(forKey: "UseCustomList")
        self.cardStyle = CardStyle(rawValue: UserDefaults.standard.string(forKey: "CardStyle") ?? "") ?? .wedge
        
        if UserDefaults.standard.object(forKey: "ShowAppName") == nil {
            self.showAppName = true
        } else {
            self.showAppName = UserDefaults.standard.bool(forKey: "ShowAppName")
        }
        
        self.enableHoverZoom = true

        if UserDefaults.standard.object(forKey: "ShowCardBorder") == nil {
            self.showCardBorder = true
        } else {
            self.showCardBorder = UserDefaults.standard.bool(forKey: "ShowCardBorder")
        }
        
        self.startAngle    = UserDefaults.standard.object(forKey: "StartAngle")    as? Double ?? -70.0
        self.cardOpacity   = UserDefaults.standard.object(forKey: "CardOpacity")    as? Double ?? 0.65
        let loadedBlur     = UserDefaults.standard.object(forKey: "CardBlurRadius") as? Double ?? 48.0
        self.cardBlur      = loadedBlur
        if let rawMode = UserDefaults.standard.string(forKey: "CardGlassMode"),
           let mode = CardGlassMode(rawValue: rawMode) {
            self.glassMode = mode
        } else {
            self.glassMode = loadedBlur > 0.5 ? .blur : .off
        }
        let bgStyleStr = UserDefaults.standard.string(forKey: "BackgroundStyle") ?? "Glass Dark"
        let loadedBgStyle = BackgroundStyle(rawValue: bgStyleStr) ?? .glassDark
        if let savedTone = UserDefaults.standard.string(forKey: "ToneMode") {
            self.toneMode = savedTone
        } else {
            self.toneMode = loadedBgStyle.isLight ? "light" : "dark"
        }
        self.glassTheme = GlassTheme(rawValue: UserDefaults.standard.string(forKey: "GlassTheme") ?? "Light") ?? .light
        self.backgroundStyle = loadedBgStyle
        
        self.wedgeSpacing  = UserDefaults.standard.object(forKey: "WedgeSpacing")  as? Double ?? 36.0
        self.wedgeInnerRadius  = UserDefaults.standard.object(forKey: "WedgeInnerRadius")  as? Double ?? 100.0
        self.wedgeOuterRadius  = UserDefaults.standard.object(forKey: "WedgeOuterRadius")  as? Double ?? 210.0
        self.wedgeCornerRadius = UserDefaults.standard.object(forKey: "WedgeCornerRadius") as? Double ?? 12.0
        self.wedgeIconSize = UserDefaults.standard.object(forKey: "WedgeIconSize") as? Double ?? 48.0
        self.fanOverlap    = UserDefaults.standard.object(forKey: "FanOverlap")    as? Double ?? 8.0
        self.rectSpacing   = UserDefaults.standard.object(forKey: "RectSpacing")   as? Double ?? 32.0
        self.rectArcRadius = UserDefaults.standard.object(forKey: "RectArcRadius") as? Double ?? 180.0
        self.rectCardWidth = UserDefaults.standard.object(forKey: "RectCardWidth") as? Double ?? 88.0
        self.rectCardHeightMultiplier = UserDefaults.standard.object(forKey: "RectCardHeightMultiplier") as? Double ?? 1.25
        self.rectCornerRadius = UserDefaults.standard.object(forKey: "RectCornerRadius") as? Double ?? 16.0
        self.rectIconSize = UserDefaults.standard.object(forKey: "RectIconSize") as? Double ?? 64.0
        self.hideInactiveApps = UserDefaults.standard.bool(forKey: "HideInactiveApps")
        
        self.launchAtLogin = LaunchAtLoginHelper.isEnabled
        
        if let data = UserDefaults.standard.data(forKey: "CustomAppPaths"),
           let paths = try? JSONDecoder().decode([String].self, from: data) {
            self.customAppPaths = paths
        }
        
        loadPresets()
        checkAccessibility()
    }

    static let builtInPresetIDs: Set<String> = [
        "default_non_background",
        "default_blur_fan",
        "default_blur_rectangle",
        "default_liquid_glass"
    ]

    func loadPresets() {
        let builtInDefaults: [CardPreset] = [
            CardPreset(
                id: "default_non_background",
                name: "Non-Background",
                cardStyle: "Wedge",
                wedgeSpacing: 34.0,
                wedgeInnerRadius: 110.0,
                wedgeOuterRadius: 180.0,
                wedgeCornerRadius: 0.0,
                wedgeIconSize: 78.0,
                fanOverlap: 10.0,
                rectSpacing: 22.0,
                rectArcRadius: 170.0,
                rectCardWidth: 90.0,
                rectCardHeightMultiplier: 1.15,
                rectCornerRadius: 30.0,
                rectIconSize: 40.0,
                showAppName: true,
                enableHoverZoom: true,
                startAngle: -180.0,
                cardOpacity: 0.0,
                glassTheme: "Dark",
                backgroundStyle: BackgroundStyle.solidDark.rawValue,
                glassMode: CardGlassMode.off.rawValue,
                showCardBorder: false
            ),
            CardPreset(
                id: "default_blur_fan",
                name: "Blur-Fan",
                cardStyle: "Wedge",
                wedgeSpacing: 40.0,
                wedgeInnerRadius: 85.0,
                wedgeOuterRadius: 180.0,
                wedgeCornerRadius: 60.0,
                wedgeIconSize: 36.0,
                fanOverlap: 8.0,
                rectSpacing: 22.0,
                rectArcRadius: 170.0,
                rectCardWidth: 90.0,
                rectCardHeightMultiplier: 1.15,
                rectCornerRadius: 30.0,
                rectIconSize: 40.0,
                showAppName: true,
                enableHoverZoom: true,
                startAngle: -180.0,
                cardOpacity: 0.18,
                glassTheme: "Dark",
                backgroundStyle: BackgroundStyle.glassDark.rawValue,
                glassMode: CardGlassMode.blur.rawValue,
                showCardBorder: true
            ),
            CardPreset(
                id: "default_blur_rectangle",
                name: "Blur-Rectangle",
                cardStyle: "Rectangular",
                wedgeSpacing: 40.0,
                wedgeInnerRadius: 85.0,
                wedgeOuterRadius: 180.0,
                wedgeCornerRadius: 60.0,
                wedgeIconSize: 36.0,
                fanOverlap: 8.0,
                rectSpacing: 22.0,
                rectArcRadius: 170.0,
                rectCardWidth: 90.0,
                rectCardHeightMultiplier: 1.15,
                rectCornerRadius: 30.0,
                rectIconSize: 45.0,
                showAppName: true,
                enableHoverZoom: true,
                startAngle: -75.0,
                cardOpacity: 0.18,
                glassTheme: "Dark",
                backgroundStyle: BackgroundStyle.glassDark.rawValue,
                glassMode: CardGlassMode.blur.rawValue,
                showCardBorder: true
            ),
            CardPreset(
                id: "default_liquid_glass",
                name: "Liquid glass",
                cardStyle: "Rectangular",
                wedgeSpacing: 40.0,
                wedgeInnerRadius: 85.0,
                wedgeOuterRadius: 180.0,
                wedgeCornerRadius: 60.0,
                wedgeIconSize: 36.0,
                fanOverlap: 8.0,
                rectSpacing: 25.0,
                rectArcRadius: 170.0,
                rectCardWidth: 90.0,
                rectCardHeightMultiplier: 1.15,
                rectCornerRadius: 30.0,
                rectIconSize: 45.0,
                showAppName: true,
                enableHoverZoom: true,
                startAngle: -75.0,
                cardOpacity: 0.5,
                glassTheme: "Dark",
                backgroundStyle: BackgroundStyle.glassDark.rawValue,
                glassMode: CardGlassMode.liquidGlass.rawValue,
                showCardBorder: false
            )
        ]

        if let data = UserDefaults.standard.data(forKey: "SavedPresets"),
           let decoded = try? JSONDecoder().decode([CardPreset].self, from: data),
           decoded.contains(where: { Self.builtInPresetIDs.contains($0.id) }) {
            self.presets = decoded
        } else {
            self.presets = builtInDefaults
            savePresetsToDefaults(builtInDefaults)
        }
    }
    
    func savePresetsToDefaults(_ list: [CardPreset]) {
        if let encoded = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(encoded, forKey: "SavedPresets")
        }
    }
    
    func saveCurrentAsPreset(name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newPreset = CardPreset(
            id: UUID().uuidString,
            name: name,
            cardStyle: cardStyle.rawValue,
            wedgeSpacing: wedgeSpacing,
            wedgeInnerRadius: wedgeInnerRadius,
            wedgeOuterRadius: wedgeOuterRadius,
            wedgeCornerRadius: wedgeCornerRadius,
            wedgeIconSize: wedgeIconSize,
            fanOverlap: fanOverlap,
            rectSpacing: rectSpacing,
            rectArcRadius: rectArcRadius,
            rectCardWidth: rectCardWidth,
            rectCardHeightMultiplier: rectCardHeightMultiplier,
            rectCornerRadius: rectCornerRadius,
            rectIconSize: rectIconSize,
            showAppName: showAppName,
            enableHoverZoom: enableHoverZoom,
            startAngle: startAngle,
            cardOpacity: cardOpacity,
            glassTheme: glassTheme.rawValue,
            backgroundStyle: backgroundStyle.rawValue,
            glassMode: glassMode.rawValue,
            showCardBorder: showCardBorder
        )
        
        presets.append(newPreset)
        savePresetsToDefaults(presets)
        newPresetName = ""
    }
    
    func applyPreset(_ preset: CardPreset) {
        self.cardStyle = CardStyle(rawValue: preset.cardStyle) ?? .wedge
        self.wedgeSpacing = preset.wedgeSpacing
        self.wedgeInnerRadius = preset.wedgeInnerRadius
        self.wedgeOuterRadius = preset.wedgeOuterRadius
        self.wedgeCornerRadius = preset.wedgeCornerRadius
        self.wedgeIconSize = preset.wedgeIconSize
        self.fanOverlap = preset.fanOverlap
        self.rectSpacing = preset.rectSpacing
        self.rectArcRadius = preset.rectArcRadius
        self.rectCardWidth = preset.rectCardWidth
        self.rectCardHeightMultiplier = preset.rectCardHeightMultiplier
        self.rectCornerRadius = preset.rectCornerRadius
        self.rectIconSize = preset.rectIconSize
        self.showAppName = preset.showAppName
        self.enableHoverZoom = true
        self.startAngle = preset.startAngle
        self.cardOpacity = preset.cardOpacity
        self.backgroundStyle = BackgroundStyle(rawValue: preset.backgroundStyle) ?? .glassDark
        self.glassTheme = GlassTheme(rawValue: preset.glassTheme) ?? .dark
        self.toneMode = self.backgroundStyle.isLight ? "light" : "dark"
        if let modeRaw = preset.glassMode, let mode = CardGlassMode(rawValue: modeRaw) {
            self.glassMode = mode
        } else {
            self.glassMode = self.backgroundStyle.hasBlur ? .blur : .off
        }
        self.showCardBorder = preset.showCardBorder ?? true
    }
    
    func deletePreset(_ preset: CardPreset) {
        guard !Self.builtInPresetIDs.contains(preset.id) else { return }
        presets.removeAll { $0.id == preset.id }
        savePresetsToDefaults(presets)
    }

    func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = L10n.shared.t("Thêm", "Add")

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK else { return }
            self?.addApps(at: panel.urls)
        }

        // Dùng sheet gắn vào cửa sổ Settings để hộp thoại luôn nổi lên trên cùng
        // (app chạy ở chế độ accessory nên runModal dễ bị che khuất).
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            handle(panel.runModal())
        }
    }

    /// Thêm nhiều ứng dụng một lần, bỏ qua mục trùng và mục không phải .app.
    func addApps(at urls: [URL]) {
        let newPaths = urls
            .filter { $0.pathExtension == "app" }
            .map(\.path)
            .filter { !customAppPaths.contains($0) }
        guard !newPaths.isEmpty else { return }
        customAppPaths += newPaths
    }

    func moveApps(from source: IndexSet, to destination: Int) {
        customAppPaths.move(fromOffsets: source, toOffset: destination)
    }
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
        LaunchAtLoginHelper.setEnabled(enabled)
    }
    
    func checkAccessibility() {
        self.isAccessibilityGranted = AXIsProcessTrusted()
    }
    
    func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        AXIsProcessTrustedWithOptions(options)
        
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAccessibility()
        }
    }
    
    func resetToDefaults() {
        if let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        
        // Reset properties in memory instantly
        self.useCustomList = false
        self.cardStyle = .wedge
        self.showAppName = true
        self.enableHoverZoom = true
        self.showCardBorder = true
        self.startAngle = -70.0
        self.cardOpacity = 0.65
        self.cardBlur = 48.0
        self.glassMode = .blur
        self.toneMode = "dark"
        self.backgroundStyle = .glassDark
        self.glassTheme = .dark
        
        self.wedgeSpacing = 36.0
        self.wedgeInnerRadius = 100.0
        self.wedgeOuterRadius = 210.0
        self.wedgeCornerRadius = 12.0
        self.wedgeIconSize = 48.0
        self.fanOverlap = 8.0
        
        self.rectSpacing = 32.0
        self.rectArcRadius = 180.0
        self.rectCardWidth = 88.0
        self.rectCardHeightMultiplier = 1.25
        self.rectCornerRadius = 16.0
        self.rectIconSize = 64.0
        self.hideInactiveApps = false
        self.enableMiddleClickTrigger = false
        self.doubleTapMode = .none
        self.enableFnShiftTrigger = false
        self.customAppPaths = []
        
        loadPresets()
        checkAccessibility()
    }


}

// MARK: - Sidebar Tabs

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general
    case triggers
    case appearance
    case apps
    case about

    var id: String { rawValue }

    var label: String {
        let l = L10n.shared
        switch self {
        case .general:    return l.t("Cài đặt chung", "General")
        case .triggers:   return l.t("Kích hoạt", "Shortcuts")
        case .appearance: return l.t("Giao diện", "Appearance")
        case .apps:       return l.t("Ứng dụng", "Applications")
        case .about:      return l.t("Giới thiệu", "About")
        }
    }

    var subtitle: String {
        let l = L10n.shared
        switch self {
        case .general:
            return l.t("Quản lý ngôn ngữ, quyền hệ thống, khởi động cùng macOS và thống kê.",
                       "Manage language, system permissions, startup, and usage statistics.")
        case .triggers:
            return l.t("Thiết lập phím tắt toàn hệ thống, nhấn đúp phím bổ trợ và chuột giữa.",
                       "Configure global keyboard shortcuts, double-tap modifiers, and middle click.")
        case .appearance:
            return l.t("Tuỳ chỉnh kiểu thẻ, hiệu ứng kính, kích thước và cấu hình hiển thị Launcher.",
                       "Customize card style, glass effects, geometry, and visual presets.")
        case .apps:
            return l.t("Chọn danh sách ứng dụng hiển thị và sắp xếp thứ tự trên Launcher.",
                       "Choose which applications appear and reorder them in the Launcher.")
        case .about:
            return l.t("Thông tin phiên bản, quyền riêng tư và mã nguồn mở của HiPu Switcher.",
                       "Version info, privacy details, and open-source notices for HiPu Switcher.")
        }
    }

    var icon: String {
        switch self {
        case .general:    return "gearshape.fill"
        case .triggers:   return "keyboard.fill"
        case .appearance: return "paintbrush.fill"
        case .apps:       return "square.grid.2x2.fill"
        case .about:      return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general:    return Color(nsColor: .systemGray)
        case .triggers:   return .orange
        case .appearance: return .blue
        case .apps:       return .indigo
        case .about:      return Color(nsColor: .systemGray)
        }
    }

    var searchKeywords: [String] {
        switch self {
        case .general:
            return ["cài đặt chung", "general", "trợ năng", "accessibility", "khởi động", "login", "thống kê", "khôi phục", "reset"]
        case .triggers:
            return ["kích hoạt", "trigger", "phím tắt", "shortcut", "hotkey", "nhấn đúp", "double tap", "shift", "option", "command", "chuột giữa", "middle click"]
        case .appearance:
            return ["giao diện", "appearance", "cánh quạt", "wedge", "chữ nhật", "rectangular", "kính", "glass", "nền", "icon", "preset", "cấu hình", "bo góc", "bán kính"]
        case .apps:
            return ["ứng dụng", "apps", "danh sách", "tuỳ chỉnh", "custom", "ẩn", "launcher"]
        case .about:
            return ["giới thiệu", "about", "phiên bản", "version", "hỗ trợ", "quyền riêng tư", "mã nguồn mở", "mẹo"]
        }
    }

    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return true }
        if label.lowercased().contains(trimmed) { return true }
        return searchKeywords.contains(where: { $0.contains(trimmed) })
    }
}

// MARK: - Root Settings View (macOS System Settings Style)

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var l10n = L10n.shared
    @State private var selectedTab: SettingsTab? = .general
    @State private var searchText: String = ""
    @State private var backStack: [SettingsTab] = []
    @State private var forwardStack: [SettingsTab] = []
    @State private var isNavigatingHistory = false

    private var primaryTabs: [SettingsTab] {
        [.general, .triggers, .appearance, .apps].filter { $0.matches(searchText) }
    }

    private var secondaryTabs: [SettingsTab] {
        [.about].filter { $0.matches(searchText) }
    }

    private var activeTab: SettingsTab {
        selectedTab ?? .general
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 225, max: 255)
        } detail: {
            Group {
                switch activeTab {
                case .general:    GeneralSettingsPane(viewModel: viewModel)
                case .triggers:   TriggerSettingsPane(viewModel: viewModel)
                case .appearance: AppearanceSettingsPane(viewModel: viewModel)
                case .apps:       AppsSettingsPane(viewModel: viewModel)
                case .about:      AboutSettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(activeTab.label)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenAboutTabAndCheckUpdates"))) { _ in
                selectedTab = .about
                UpdateChecker.shared.checkForUpdates()
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        navigateBack()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(backStack.isEmpty)
                    .help(l10n.t("Quay lại", "Back"))

                    Button {
                        navigateForward()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(forwardStack.isEmpty)
                    .help(l10n.t("Tiến tới", "Forward"))
                }
            }
        }
        .frame(minWidth: 720, idealWidth: 820, minHeight: 500, idealHeight: 580)
        .onChange(of: searchText) { _, _ in
            let visible = primaryTabs + secondaryTabs
            if let current = selectedTab, !visible.contains(current), let first = visible.first {
                selectedTab = first
            }
        }
    }

    // MARK: - Sidebar (Native macOS Liquid Glass Sidebar + Searchable)

    private var sidebar: some View {
        List(selection: tabBinding) {
            if !primaryTabs.isEmpty {
                Section {
                    ForEach(primaryTabs) { tab in
                        sidebarRow(for: tab)
                            .tag(tab)
                    }
                }
                .listSectionSeparator(.hidden)
            }

            if !secondaryTabs.isEmpty {
                Section {
                    ForEach(secondaryTabs) { tab in
                        sidebarRow(for: tab)
                            .tag(tab)
                    }
                }
                .listSectionSeparator(.hidden)
            }

            if primaryTabs.isEmpty && secondaryTabs.isEmpty {
                Text(l10n.t("Không tìm thấy mục phù hợp", "No matching settings"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: l10n.t("Tìm kiếm", "Search"))
    }

    private func sidebarRow(for tab: SettingsTab) -> some View {
        HStack(spacing: 9) {
            SettingsIconBadge(systemName: tab.icon, color: tab.tint, size: 22)
            Text(tab.label)
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    // MARK: - History Navigation

    private var tabBinding: Binding<SettingsTab?> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                guard let newValue else { return }
                selectTab(newValue)
            }
        )
    }

    private func selectTab(_ next: SettingsTab) {
        if !isNavigatingHistory, let current = selectedTab, current != next {
            backStack.append(current)
            forwardStack.removeAll()
        }
        selectedTab = next
    }

    private func navigateBack() {
        guard let previous = backStack.popLast() else { return }
        if let current = selectedTab {
            forwardStack.append(current)
        }
        isNavigatingHistory = true
        selectedTab = previous
        isNavigatingHistory = false
    }

    private func navigateForward() {
        guard let next = forwardStack.popLast() else { return }
        if let current = selectedTab {
            backStack.append(current)
        }
        isNavigatingHistory = true
        selectedTab = next
        isNavigatingHistory = false
    }
}

// MARK: - Shared macOS System Settings Components

private struct SettingsIconBadge: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        let radius = size * 0.28
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.88), color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 0.8, x: 0, y: 0.5)

            Image(systemName: systemName)
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

private struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(color.opacity(0.14), in: Capsule())
    }
}

private struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing
        }
    }
}

// MARK: - Pane: General

struct GeneralSettingsPane: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var l10n = L10n.shared
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section(l10n.t("Ngôn ngữ & Khởi động", "Language & Startup")) {
                Picker(l10n.t("Ngôn ngữ", "Language"), selection: $l10n.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }

                Toggle(l10n.t("Mở HiPu Switcher cùng khi đăng nhập", "Open HiPu Switcher at login"), isOn: $viewModel.launchAtLogin)
                    .disabled(!LaunchAtLoginHelper.isSupported)
                if !LaunchAtLoginHelper.isSupported {
                    Text(l10n.t("Yêu cầu ứng dụng được ký bằng Developer ID.", "Requires an app signed with a Developer ID."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                SettingRow(
                    title: l10n.t("Quyền Trợ năng (Accessibility)", "Accessibility Permission"),
                    subtitle: l10n.t("Cho phép nhận phím tắt toàn hệ thống và chuột giữa.", "Required for global shortcuts, double-tap, and middle click.")
                ) {
                    if viewModel.isAccessibilityGranted {
                        StatusBadge(text: l10n.t("Đã cấp quyền", "Granted"), color: .green)
                    } else {
                        HStack(spacing: 8) {
                            StatusBadge(text: l10n.t("Chưa cấp quyền", "Not Granted"), color: .red)
                            Button(l10n.t("Cấp quyền", "Grant")) { viewModel.requestAccessibility() }
                                .controlSize(.small)
                        }
                    }
                }
            } header: {
                Text(l10n.t("Quyền hệ thống", "System Permissions"))
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t("Khôi phục cài đặt gốc", "Reset to Defaults"))
                        Text(l10n.t("Đặt lại tất cả tuỳ chỉnh về giá trị mặc định ban đầu.", "Restore all preferences to their factory default values."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(l10n.t("Khôi phục…", "Reset…"), role: .destructive) {
                        showResetConfirm = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            viewModel.checkAccessibility()
        }
        .alert(l10n.t("Khôi phục cài đặt?", "Reset All Settings?"), isPresented: $showResetConfirm) {
            Button(l10n.t("Hủy", "Cancel"), role: .cancel) {}
            Button(l10n.t("Khôi phục", "Reset"), role: .destructive) {
                viewModel.resetToDefaults()
            }
        } message: {
            Text(l10n.t("Tất cả tuỳ chỉnh sẽ trở về giá trị mặc định. Không thể hoàn tác.", "All preferences will be restored to default values. This cannot be undone."))
        }
    }
}

// MARK: - Pane: Triggers (Streamlined Shortcut Flow)

struct TriggerSettingsPane: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var l10n = L10n.shared
    @State private var activeShortcut: KeyboardShortcuts.Shortcut? = KeyboardShortcuts.getShortcut(for: .toggleLauncher)

    private struct ShortcutSuggestion: Identifiable {
        let id: String
        let label: String
        let shortcut: KeyboardShortcuts.Shortcut
    }

    private let suggestions: [ShortcutSuggestion] = [
        .init(id: "opt_space", label: "⌥ Space", shortcut: .init(.space, modifiers: [.option])),
        .init(id: "cmd_shift_space", label: "⌘ ⇧ Space", shortcut: .init(.space, modifiers: [.command, .shift])),
        .init(id: "ctrl_space", label: "⌃ Space", shortcut: .init(.space, modifiers: [.control])),
        .init(id: "opt_tab", label: "⌥ Tab", shortcut: .init(.tab, modifiers: [.option]))
    ]

    var body: some View {
        Form {
            if !viewModel.isAccessibilityGranted {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.t("Cần quyền Trợ năng (Accessibility)", "Accessibility Permission Required"))
                                .font(.system(size: 13, weight: .semibold))
                            Text(l10n.t("Cấp quyền để dùng nhấn đúp phím bổ trợ, fn + Shift và chuột giữa trên mọi ứng dụng.", "Grant permission to use double-tap modifiers, fn + Shift, and middle click globally."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(l10n.t("Cấp quyền ngay", "Grant Now")) {
                            viewModel.requestAccessibility()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section {
                SettingRow(
                    title: l10n.t("Tổ hợp phím mở Launcher", "Toggle Launcher Shortcut"),
                    subtitle: l10n.t("Bấm vào ô bên phải rồi nhấn tổ hợp phím mới (Esc để hủy).", "Click the pill on the right and press your shortcut (Esc to cancel).")
                ) {
                    CustomShortcutRecorder(
                        shortcut: $activeShortcut,
                        customLabel: viewModel.enableFnShiftTrigger ? "fn ⇧" : nil,
                        onClearCustom: {
                            viewModel.enableFnShiftTrigger = false
                        }
                    ) { newShortcut in
                        if newShortcut != nil {
                            viewModel.enableFnShiftTrigger = false
                        }
                        KeyboardShortcuts.setShortcut(newShortcut, for: .toggleLauncher)
                    }
                }

                LabeledContent {
                    HStack(spacing: 6) {
                        Button {
                            viewModel.enableFnShiftTrigger = true
                            KeyboardShortcuts.setShortcut(nil, for: .toggleLauncher)
                            activeShortcut = nil
                        } label: {
                            Text("fn ⇧")
                                .font(.system(size: 11.5, weight: viewModel.enableFnShiftTrigger ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(viewModel.enableFnShiftTrigger ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4.5)
                                .background(
                                    Capsule()
                                        .fill(viewModel.enableFnShiftTrigger ? Color.accentColor : Color.primary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)

                        ForEach(suggestions) { item in
                            let isCurrent = !viewModel.enableFnShiftTrigger && activeShortcut == item.shortcut
                            Button {
                                viewModel.enableFnShiftTrigger = false
                                KeyboardShortcuts.setShortcut(item.shortcut, for: .toggleLauncher)
                                activeShortcut = item.shortcut
                            } label: {
                                Text(item.label)
                                    .font(.system(size: 11.5, weight: isCurrent ? .semibold : .medium, design: .rounded))
                                    .foregroundStyle(isCurrent ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4.5)
                                    .background(
                                        Capsule()
                                            .fill(isCurrent ? Color.accentColor : Color.primary.opacity(0.06))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t("Gợi ý phổ biến", "Popular Presets"))
                        Text(l10n.t("Chạm để gán nhanh 1 bước.", "Click to assign in one step."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(l10n.t("Phím tắt bàn phím", "Keyboard Shortcut"))
            }

            Section {
                LabeledContent {
                    Picker("", selection: $viewModel.doubleTapMode) {
                        Text(l10n.t("Tắt", "Off")).tag(DoubleTapMode.none)
                        Text("⇧ ⇧").tag(DoubleTapMode.doubleShift)
                        Text("⌥ ⌥").tag(DoubleTapMode.doubleOption)
                        Text("⌘ ⌘").tag(DoubleTapMode.doubleCmd)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t("Nhấn đúp phím bổ trợ", "Double-Tap Modifier"))
                        Text(l10n.t("Nhấn nhanh 2 lần phím Shift, Option hoặc Command.", "Quickly tap Shift, Option, or Command twice."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $viewModel.enableMiddleClickTrigger) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t("Kích hoạt bằng chuột giữa", "Middle-Click Trigger"))
                        Text(l10n.t("Nhấn con lăn chuột để mở Launcher ngay tại vị trí con trỏ.", "Click the scroll wheel to open Launcher at the cursor."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(l10n.t("Kích hoạt nhanh bổ sung", "Additional Triggers"))
            } footer: {
                Text(l10n.t("Bạn có thể dùng song song tổ hợp phím, nhấn đúp phím bổ trợ và chuột giữa.", "You can combine keyboard shortcuts, double-tap, and middle click."))
            }
        }
        .formStyle(.grouped)
        .onAppear {
            viewModel.checkAccessibility()
            activeShortcut = KeyboardShortcuts.getShortcut(for: .toggleLauncher)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.checkAccessibility()
        }
    }
}

// MARK: - Custom Non-Blocking Shortcut Recorder

private struct CustomShortcutRecorder: View {
    @Binding var shortcut: KeyboardShortcuts.Shortcut?
    var customLabel: String? = nil
    var onClearCustom: (() -> Void)? = nil
    var onChange: (KeyboardShortcuts.Shortcut?) -> Void

    @ObservedObject private var l10n = L10n.shared
    @State private var isRecording = false
    @State private var keyMonitor: Any?

    private var hasValue: Bool {
        shortcut != nil || customLabel != nil
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 6) {
                    if isRecording {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                        Text(l10n.t("Nhấn phím…", "Press keys…"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    } else if let customLabel {
                        Text(customLabel)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    } else if let shortcut {
                        Text(shortcut.description)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    } else {
                        Text(l10n.t("Ghi phím tắt", "Record Shortcut"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .frame(minWidth: 118)
                .background(
                    Capsule()
                        .fill(isRecording ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isRecording ? Color.accentColor : .clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            if hasValue && !isRecording {
                Button {
                    shortcut = nil
                    onClearCustom?()
                    onChange(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(l10n.t("Xóa phím tắt", "Clear shortcut"))
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { event in
            if event.type == .leftMouseDown {
                stopRecording()
                return event
            }

            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])

            // Esc without modifiers cancels recording
            if event.keyCode == 53 && mods.isEmpty {
                stopRecording()
                return nil
            }

            // Delete / Backspace without modifiers clears shortcut
            if (event.keyCode == 51 || event.keyCode == 117) && mods.isEmpty {
                shortcut = nil
                onChange(nil)
                stopRecording()
                return nil
            }

            // Require at least one modifier key (or a Function key F1–F12)
            let functionKeyCodes: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
            guard !mods.isEmpty || functionKeyCodes.contains(event.keyCode) else {
                NSSound.beep()
                return nil
            }

            let key = KeyboardShortcuts.Key(rawValue: Int(event.keyCode))
            let newShortcut = KeyboardShortcuts.Shortcut(key, modifiers: mods)
            shortcut = newShortcut
            onChange(newShortcut)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        isRecording = false
    }
}

// MARK: - Simplified Appearance Presets

private enum AppearanceTone: String, CaseIterable, Identifiable {
    case light = "light"
    case dark  = "dark"
    case auto  = "auto"

    var id: String { rawValue }
    var storageKey: String { rawValue }

    var label: String {
        let l = L10n.shared
        switch self {
        case .light: return l.t("Sáng", "Light")
        case .dark:  return l.t("Tối", "Dark")
        case .auto:  return l.t("Tự động", "Auto")
        }
    }
}

private enum LauncherSizeOption: String, CaseIterable, Identifiable {
    case small  = "Nhỏ"
    case medium = "Vừa"
    case large  = "Lớn"

    var id: String { rawValue }
}

private enum LauncherDensityOption: String, CaseIterable, Identifiable {
    case compact  = "Khít"
    case balanced = "Vừa"
    case spacious = "Thoáng"

    var id: String { rawValue }
}

private enum LauncherDirectionOption: String, CaseIterable, Identifiable {
    case top    = "Trên"
    case right  = "Phải"
    case bottom = "Dưới"
    case left   = "Trái"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .top:    return "arrow.up"
        case .right:  return "arrow.right"
        case .bottom: return "arrow.down"
        case .left:   return "arrow.left"
        }
    }

    var startAngle: Double {
        switch self {
        case .top:    return -65
        case .right:  return 25
        case .bottom: return 115
        case .left:   return -155
        }
    }

    static func closest(to angle: Double) -> LauncherDirectionOption {
        allCases.min { abs($0.startAngle - angle) < abs($1.startAngle - angle) } ?? .top
    }
}

// MARK: - Pane: Appearance (Flagship macOS Product UI)

struct AppearanceSettingsPane: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var l10n = L10n.shared
    @State private var previewDarkBackdrop = true
    @State private var showSavePresetPopover = false

    private let presetGridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    // MARK: Derived simple bindings

    private var currentTone: AppearanceTone {
        switch viewModel.toneMode {
        case "light": return .light
        case "auto":  return .auto
        default:      return .dark
        }
    }

    private var isGlassEnabled: Bool {
        viewModel.glassMode != .off
    }

    private func isCustomPreset(_ preset: CardPreset) -> Bool {
        !SettingsViewModel.builtInPresetIDs.contains(preset.id)
    }

    private func isPresetActive(_ preset: CardPreset) -> Bool {
        let sameStyle = preset.cardStyle == viewModel.cardStyle.rawValue
        let presetMode = preset.glassMode ?? (BackgroundStyle(rawValue: preset.backgroundStyle)?.hasBlur == true ? "blur" : "off")
        let sameMode = presetMode == viewModel.glassMode.rawValue
        let sameBorder = (preset.showCardBorder ?? true) == viewModel.showCardBorder
        let sameOpacity = abs(preset.cardOpacity - viewModel.cardOpacity) < 0.02
        let sameAngle = abs(preset.startAngle - viewModel.startAngle) < 1.0
        return sameStyle && sameMode && sameBorder && sameOpacity && sameAngle
    }

    private func presetMeta(for preset: CardPreset) -> (icon: String, subtitle: String) {
        let mode = CardGlassMode(rawValue: preset.glassMode ?? "") ?? .blur
        switch mode {
        case .liquidGlass:
            return ("sparkles", "Liquid Glass")
        case .off:
            return ("circle.dashed", l10n.t("Không nền", "No Background"))
        case .blur:
            return preset.cardStyle == "Wedge"
                ? ("fanblades.fill", l10n.t("Kính mờ · Quạt", "Blur · Fan"))
                : ("rectangle.grid.2x2.fill", l10n.t("Kính mờ · Thẻ", "Blur · Rect"))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            AppearancePreviewPanel(
                viewModel: viewModel,
                isDarkBackdrop: $previewDarkBackdrop
            )
            .frame(height: 228)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)

            unifiedForm
        }
    }

    private var unifiedForm: some View {
        Form {
            // 1. Cấu hình nhanh
            Section {
                LazyVGrid(columns: presetGridColumns, spacing: 10) {
                    ForEach(viewModel.presets) { preset in
                        presetCard(for: preset)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                HStack {
                    Text(l10n.t("Cấu hình nhanh", "Quick Presets"))
                    Spacer()
                    Button {
                        showSavePresetPopover = true
                    } label: {
                        Label(l10n.t("Lưu hiện tại", "Save Current"), systemImage: "plus")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.accentColor)
                    .popover(isPresented: $showSavePresetPopover, arrowEdge: .bottom) {
                        savePresetPopover
                    }
                }
            }

            // 2. Hiển thị & Chất liệu
            Section(l10n.t("Hiển thị & Chất liệu", "Style & Material")) {
                LabeledContent(l10n.t("Kiểu thẻ", "Card Style")) {
                    Picker("", selection: $viewModel.cardStyle) {
                        Text(l10n.t("Cánh quạt", "Fan")).tag(CardStyle.wedge)
                        Text(l10n.t("Chữ nhật", "Rectangular")).tag(CardStyle.rectangular)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

                LabeledContent(l10n.t("Giao diện", "Appearance")) {
                    HStack(spacing: 12) {
                        ForEach(AppearanceTone.allCases) { tone in
                            tonePreviewCard(tone)
                        }
                    }
                    .padding(.vertical, 4)
                }

                LabeledContent(l10n.t("Hiệu ứng kính", "Glass Effect")) {
                    Picker("", selection: $viewModel.glassMode) {
                        ForEach(CardGlassMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

                sliderRow(
                    l10n.t("Độ đục", "Opacity"),
                    value: Binding(
                        get: { viewModel.cardOpacity * 100 },
                        set: { viewModel.cardOpacity = $0 / 100 }
                    ),
                    range: 0...100, unit: "%", step: 1
                )

                Toggle(l10n.t("Hiển thị viền thẻ", "Show Card Border"), isOn: $viewModel.showCardBorder)
                Toggle(l10n.t("Hiển thị tên ứng dụng", "Show App Name"), isOn: $viewModel.showAppName)
            }

            // 4. Kích thước & Góc
            Section {
                if viewModel.cardStyle == .wedge {
                    sliderRow(l10n.t("Bán kính trong", "Inner Radius"), value: $viewModel.wedgeInnerRadius, range: 20...150, unit: "px", step: 5)
                    sliderRow(l10n.t("Bán kính ngoài", "Outer Radius"), value: $viewModel.wedgeOuterRadius, range: 100...300, unit: "px", step: 5)
                    sliderRow(l10n.t("Góc mỗi thẻ", "Card Angle"), value: $viewModel.wedgeSpacing, range: 10...60, unit: "°", step: 1)
                    sliderRow(l10n.t("Góc đè thẻ", "Overlap Angle"), value: $viewModel.fanOverlap, range: -15...25, unit: "°", step: 1)
                    sliderRow(l10n.t("Độ bo góc", "Corner Radius"), value: $viewModel.wedgeCornerRadius, range: 0...60, unit: "px", step: 1)
                    sliderRow(l10n.t("Kích thước icon", "Icon Size"), value: $viewModel.wedgeIconSize, range: 24...96, unit: "px", step: 1)
                } else {
                    sliderRow(l10n.t("Bán kính vòng cung", "Arc Radius"), value: $viewModel.rectArcRadius, range: 80...300, unit: "px", step: 5)
                    sliderRow(l10n.t("Độ rộng thẻ", "Card Width"), value: $viewModel.rectCardWidth, range: 40...160, unit: "px", step: 2)
                    sliderRow(l10n.t("Kích thước icon", "Icon Size"), value: $viewModel.rectIconSize, range: 24...128, unit: "px", step: 1)
                    sliderRow(l10n.t("Tỷ lệ chiều cao", "Height Ratio"), value: $viewModel.rectCardHeightMultiplier, range: 0.8...2.0, unit: "×", step: 0.05)
                    sliderRow(l10n.t("Khoảng cách góc", "Angle Spacing"), value: $viewModel.rectSpacing, range: 10...60, unit: "°", step: 1)
                    sliderRow(l10n.t("Độ bo góc", "Corner Radius"), value: $viewModel.rectCornerRadius, range: 0...60, unit: "px", step: 1)
                }
                sliderRow(l10n.t("Góc bắt đầu", "Start Angle"), value: $viewModel.startAngle, range: -180...180, unit: "°", step: 5)
            } header: {
                HStack {
                    Text(viewModel.cardStyle == .wedge
                         ? l10n.t("Kích thước & Góc · Cánh quạt", "Size & Angles · Fan")
                         : l10n.t("Kích thước & Góc · Chữ nhật", "Size & Angles · Rectangular"))
                    Spacer()
                    Button(l10n.t("Đặt lại mặc định", "Reset Defaults")) {
                        applySize(.medium)
                        applyDensity(.balanced)
                        applyDirection(.top)
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var savePresetPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t("Lưu cấu hình hiện tại", "Save Current Configuration"))
                .font(.headline)
            Text(l10n.t("Lưu đầy đủ kiểu thẻ, tông màu, hiệu ứng kính, độ đục, viền thẻ và mọi thông số kích thước.", "Saves card style, theme, glass effect, opacity, border, and all geometry settings."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 240, alignment: .leading)

            TextField(l10n.t("Tên cấu hình…", "Preset name…"), text: $viewModel.newPresetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit { commitSavePreset() }

            HStack {
                Spacer()
                Button(l10n.t("Hủy", "Cancel")) {
                    viewModel.newPresetName = ""
                    showSavePresetPopover = false
                }
                Button(l10n.t("Lưu", "Save")) {
                    commitSavePreset()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
    }

    private func commitSavePreset() {
        let trimmed = viewModel.newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.saveCurrentAsPreset(name: trimmed)
        showSavePresetPopover = false
    }

    private func presetCard(for preset: CardPreset) -> some View {
        let active = isPresetActive(preset)
        let meta = presetMeta(for: preset)

        return ZStack(alignment: .topTrailing) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    viewModel.applyPreset(preset)
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: meta.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(active ? Color.accentColor : .secondary)
                        Spacer()
                        if active {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(preset.name)
                            .font(.system(size: 12, weight: active ? .semibold : .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(meta.subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(active ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(active ? Color.accentColor : .clear, lineWidth: 1.8)
                )
            }
            .buttonStyle(.plain)

            if isCustomPreset(preset) {
                Button {
                    viewModel.deletePreset(preset)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .help(l10n.t("Xoá cấu hình này", "Delete this preset"))
            }
        }
    }

    // MARK: - Visual Components

    private func tonePreviewCard(_ tone: AppearanceTone) -> some View {
        let isSelected = currentTone == tone
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                applyTone(tone, glass: isGlassEnabled)
            }
        } label: {
            VStack(spacing: 6) {
                Group {
                    switch tone {
                    case .light:
                        macOSDesktopThumb(isDark: false)
                    case .dark:
                        macOSDesktopThumb(isDark: true)
                    case .auto:
                        HStack(spacing: 0) {
                            macOSDesktopThumb(isDark: false)
                                .frame(width: 36, alignment: .leading)
                                .clipped()
                            macOSDesktopThumb(isDark: true)
                                .frame(width: 36, alignment: .trailing)
                                .clipped()
                        }
                    }
                }
                .frame(width: 72, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.18),
                            lineWidth: isSelected ? 2.5 : 0.75
                        )
                )
                .shadow(color: .black.opacity(0.16), radius: 2, x: 0, y: 1)

                Text(tone.label)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func macOSDesktopThumb(isDark: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            // Hình nền xanh lam đặc trưng của macOS System Settings
            LinearGradient(
                colors: isDark
                    ? [
                        Color(red: 0.12, green: 0.16, blue: 0.44),
                        Color(red: 0.09, green: 0.25, blue: 0.62),
                        Color(red: 0.05, green: 0.08, blue: 0.24)
                      ]
                    : [
                        Color(red: 0.52, green: 0.78, blue: 0.99),
                        Color(red: 0.28, green: 0.58, blue: 0.92),
                        Color(red: 0.18, green: 0.42, blue: 0.78)
                      ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Thanh menu nhỏ phía trên
            Rectangle()
                .fill(isDark ? Color.black.opacity(0.28) : Color.white.opacity(0.35))
                .frame(height: 7)

            // Menu thả xuống với dòng chọn màu xanh dương
            VStack(alignment: .leading, spacing: 2) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(red: 0.04, green: 0.52, blue: 1.0))
                    .frame(width: 30, height: 5)
            }
            .padding(3)
            .frame(width: 38, height: 14, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isDark ? Color(red: 0.08, green: 0.13, blue: 0.36).opacity(0.85) : Color.white.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.white.opacity(isDark ? 0.16 : 0.6), lineWidth: 0.5)
            )
            .offset(x: 4, y: 9)

            // Góc cửa sổ macOS phía dưới bên phải với 3 nút đèn giao thông
            HStack(spacing: 3.5) {
                Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 5.5, height: 5.5)
                Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 5.5, height: 5.5)
                Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 5.5, height: 5.5)
                Spacer(minLength: 0)
            }
            .padding(.leading, 8)
            .padding(.top, 8)
            .frame(width: 52, height: 24, alignment: .topLeading)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0)
                    .fill(isDark ? Color(red: 0.06, green: 0.08, blue: 0.14) : Color.white.opacity(0.95))
            )
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0)
                    .strokeBorder(Color.white.opacity(isDark ? 0.15 : 0.7), lineWidth: 0.6)
            )
            .offset(x: 22, y: 24)
        }
        .frame(width: 72, height: 46)
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String, step: Double) -> some View {
        let steppedBinding = Binding<Double>(
            get: { value.wrappedValue },
            set: { newValue in
                let snapped = (newValue / step).rounded() * step
                value.wrappedValue = min(max(snapped, range.lowerBound), range.upperBound)
            }
        )
        return LabeledContent(label) {
            HStack(spacing: 8) {
                // Căn trục phải đồng bộ đúng 220pt với các Segmented Picker phía trên
                Slider(value: steppedBinding, in: range)
                    .frame(width: 168)
                Text(unit == "×" ? String(format: "%.2f×", value.wrappedValue) : "\(Int(value.wrappedValue))\(unit)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .frame(width: 220, alignment: .trailing)
        }
    }

    // MARK: - Proportional Apply Logic

    private func applyTone(_ tone: AppearanceTone, glass: Bool) {
        viewModel.toneMode = tone.storageKey
        let useDark: Bool
        switch tone {
        case .light:
            useDark = false
        case .dark:
            useDark = true
        case .auto:
            useDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        viewModel.backgroundStyle = useDark
            ? (glass ? .glassDark : .solidDark)
            : (glass ? .glassLight : .solidLight)
    }

    private func applySize(_ size: LauncherSizeOption) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if viewModel.cardStyle == .wedge {
                switch size {
                case .small:
                    viewModel.wedgeInnerRadius = 45
                    viewModel.wedgeOuterRadius = 145
                    viewModel.wedgeCornerRadius = 16
                    viewModel.wedgeIconSize = 38
                case .medium:
                    viewModel.wedgeInnerRadius = 65
                    viewModel.wedgeOuterRadius = 185
                    viewModel.wedgeCornerRadius = 20
                    viewModel.wedgeIconSize = 50
                case .large:
                    viewModel.wedgeInnerRadius = 85
                    viewModel.wedgeOuterRadius = 225
                    viewModel.wedgeCornerRadius = 24
                    viewModel.wedgeIconSize = 62
                }
            } else {
                switch size {
                case .small:
                    viewModel.rectArcRadius = 145
                    viewModel.rectCardWidth = 64
                    viewModel.rectCardHeightMultiplier = 1.25
                    viewModel.rectCornerRadius = 16
                    viewModel.rectIconSize = 38
                case .medium:
                    viewModel.rectArcRadius = 175
                    viewModel.rectCardWidth = 84
                    viewModel.rectCardHeightMultiplier = 1.25
                    viewModel.rectCornerRadius = 18
                    viewModel.rectIconSize = 54
                case .large:
                    viewModel.rectArcRadius = 205
                    viewModel.rectCardWidth = 104
                    viewModel.rectCardHeightMultiplier = 1.25
                    viewModel.rectCornerRadius = 22
                    viewModel.rectIconSize = 68
                }
            }
        }
    }

    private func applyDensity(_ density: LauncherDensityOption) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if viewModel.cardStyle == .wedge {
                switch density {
                case .compact:
                    viewModel.wedgeSpacing = 32
                    viewModel.fanOverlap = 10
                case .balanced:
                    viewModel.wedgeSpacing = 40
                    viewModel.fanOverlap = 8
                case .spacious:
                    viewModel.wedgeSpacing = 48
                    viewModel.fanOverlap = 4
                }
            } else {
                switch density {
                case .compact:
                    viewModel.rectSpacing = 22
                case .balanced:
                    viewModel.rectSpacing = 30
                case .spacious:
                    viewModel.rectSpacing = 38
                }
            }
        }
    }

    private func applyDirection(_ direction: LauncherDirectionOption) {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.startAngle = direction.startAngle
        }
    }
}

// MARK: - Appearance Preview Panel (Sticky Top)

private struct PreviewPillGlassModifier: ViewModifier {
    let isDark: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(isDark ? 0.15 : 0.45), lineWidth: 0.5)
                )
        }
    }
}

private struct AppearancePreviewPanel: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var l10n = L10n.shared
    @Binding var isDarkBackdrop: Bool
    @State private var selectedPreviewIndex: Int = 2

    var body: some View {
        ZStack {
            // 1. Khung cảnh desktop macOS thực tế (hình nền mượt + cửa sổ giả lập)
            previewWallpaper

            // 2. Lớp Background Blur cho chế độ Blur cổ điển
            if viewModel.glassMode == .blur && viewModel.cardBlur > 0.1 {
                previewWallpaper
                    .blur(radius: 16)
                    .mask {
                        PreviewLauncherView(
                            viewModel: viewModel,
                            selectedIndex: $selectedPreviewIndex,
                            maskOnly: true
                        )
                    }
            }

            // 3. Launcher phóng to rõ nét (0.42x) và hỗ trợ chọn thử từng thẻ
            PreviewLauncherView(
                viewModel: viewModel,
                selectedIndex: $selectedPreviewIndex,
                maskOnly: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                HStack {
                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDarkBackdrop.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isDarkBackdrop ? "moon.fill" : "sun.max.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(isDarkBackdrop ? l10n.t("Nền tối", "Dark BG") : l10n.t("Nền sáng", "Light BG"))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(isDarkBackdrop ? Color.white.opacity(0.92) : Color.black.opacity(0.80))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .modifier(PreviewPillGlassModifier(isDark: isDarkBackdrop))
                    }
                    .buttonStyle(.plain)
                    .help(isDarkBackdrop ? l10n.t("Thử trên nền sáng", "Preview on light background") : l10n.t("Thử trên nền tối", "Preview on dark background"))
                }
                Spacer()
            }
            .padding(12)
        }
    }

    private var previewWallpaper: some View {
        ZStack {
            // Nền gradient chuyển mượt không bị cắt cạnh
            LinearGradient(
                colors: isDarkBackdrop
                    ? [
                        Color(red: 0.07, green: 0.09, blue: 0.17),
                        Color(red: 0.13, green: 0.10, blue: 0.24),
                        Color(red: 0.07, green: 0.15, blue: 0.24)
                      ]
                    : [
                        Color(red: 0.78, green: 0.87, blue: 0.99),
                        Color(red: 0.91, green: 0.85, blue: 0.98),
                        Color(red: 0.82, green: 0.93, blue: 0.97)
                      ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Các dải sáng mềm được blur mịn để tuyệt đối không còn viền hình bầu dục cứng
            ZStack {
                Circle()
                    .fill(isDarkBackdrop ? Color(red: 0.20, green: 0.48, blue: 1.0).opacity(0.55) : Color(red: 0.35, green: 0.64, blue: 1.0).opacity(0.45))
                    .frame(width: 220, height: 220)
                    .offset(x: -140, y: -40)

                Circle()
                    .fill(isDarkBackdrop ? Color(red: 0.82, green: 0.26, blue: 0.62).opacity(0.45) : Color(red: 0.96, green: 0.54, blue: 0.76).opacity(0.40))
                    .frame(width: 210, height: 210)
                    .offset(x: 150, y: 45)

                Circle()
                    .fill(isDarkBackdrop ? Color(red: 0.12, green: 0.76, blue: 0.82).opacity(0.32) : Color(red: 0.44, green: 0.86, blue: 0.92).opacity(0.35))
                    .frame(width: 170, height: 170)
                    .offset(x: 20, y: -55)
            }
            .blur(radius: 52)
        }
    }
}

// MARK: - Pane: Applications

struct AppsSettingsPane: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var l10n = L10n.shared
    @State private var selectedApp: String?
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle(l10n.t("Dùng danh sách ứng dụng tuỳ chỉnh", "Use custom application list"), isOn: $viewModel.useCustomList)
                    Toggle(l10n.t("Ẩn ứng dụng không hoạt động", "Hide inactive applications"), isOn: $viewModel.hideInactiveApps)
                } footer: {
                    Text(l10n.t(
                        "Khi tắt danh sách tuỳ chỉnh, Launcher chỉ hiển thị các ứng dụng đang mở.",
                        "When disabled, Launcher shows currently running apps only."
                    ))
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: 145)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(l10n.t("Danh sách Launcher", "Launcher List"))
                        .font(.subheadline.weight(.semibold))
                    Text("\(viewModel.customAppPaths.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                    Spacer()
                    if !viewModel.useCustomList {
                        StatusBadge(text: l10n.t("Chưa áp dụng — bật công tắc ở trên", "Inactive — enable the toggle above"), color: .orange)
                    }
                }

                VStack(spacing: 0) {
                    Group {
                        if viewModel.customAppPaths.isEmpty {
                            ContentUnavailableView(
                                l10n.t("Chưa có ứng dụng", "No Applications"),
                                systemImage: "square.grid.2x2",
                                description: Text(l10n.t("Bấm + hoặc kéo ứng dụng (.app) vào đây.", "Click + or drag applications (.app) here."))
                            )
                        } else {
                            List(selection: $selectedApp) {
                                ForEach(viewModel.customAppPaths, id: \.self) { path in
                                    AppRowView(path: path)
                                        .tag(path)
                                }
                                .onMove(perform: viewModel.moveApps)
                            }
                            .listStyle(.inset)
                            .onDeleteCommand(perform: removeSelected)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    HStack(spacing: 4) {
                        Button { viewModel.addApp() } label: {
                            Image(systemName: "plus").frame(width: 24, height: 22)
                        }
                        .help(l10n.t("Thêm ứng dụng", "Add application"))

                        Button(action: removeSelected) {
                            Image(systemName: "minus").frame(width: 24, height: 22)
                        }
                        .disabled(selectedApp == nil)
                        .help(l10n.t("Xóa ứng dụng đã chọn", "Remove selected application"))

                        Spacer()

                        Text(l10n.t("Kéo thả để sắp xếp", "Drag to reorder"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(Color(NSColor.controlBackgroundColor))
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isDropTargeted ? Color.accentColor : .clear, lineWidth: 2)
                )
                .opacity(viewModel.useCustomList ? 1 : 0.65)
                .dropDestination(for: URL.self) { urls, _ in
                    viewModel.addApps(at: urls)
                    return !urls.isEmpty
                } isTargeted: { isDropTargeted = $0 }
            }
            .padding([.horizontal, .bottom], 20)
            .padding(.top, 4)
        }
    }

    private func removeSelected() {
        guard let sel = selectedApp,
              let idx = viewModel.customAppPaths.firstIndex(of: sel) else { return }
        viewModel.customAppPaths.remove(at: idx)
        selectedApp = nil
    }
}

// MARK: - Pane: About

struct AboutSettingsPane: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @State private var showLargeQR = false

    private var donateQRImage: NSImage? {
        if let url = Bundle.module.url(forResource: "DonateQR", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let url = Bundle.main.url(forResource: "DonateQR", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return nil
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)
                    Text(AppInfo.name)
                        .font(.title2.bold())
                    Text(l10n.t("Phiên bản \(AppInfo.version)", "Version \(AppInfo.version)"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(l10n.t("Chuyển đổi và mở ứng dụng nhanh bằng phím tắt.", "Quickly switch and launch macOS apps with shortcuts."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section {
                LabeledContent(l10n.t("Nhà phát triển", "Developer"), value: AppInfo.developer)
                LabeledContent(l10n.t("Phiên bản", "Version"), value: AppInfo.version)
                LabeledContent(l10n.t("Hệ thống", "System"), value: AppInfo.systemSummary)
            } header: {
                Text(l10n.t("Thông tin", "Information"))
            } footer: {
                Text(AppInfo.copyright)
            }

            Section {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        updateStatusLabel
                        if case .updateAvailable(let release) = updateChecker.state,
                           let notes = release.releaseNotes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 8)

                    switch updateChecker.state {
                    case .checking:
                        ProgressView()
                            .controlSize(.small)
                    case .updateAvailable(let release):
                        Button(l10n.t("Tải bản \(release.version)", "Download \(release.version)")) {
                            updateChecker.openDownload(release)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    default:
                        Button(l10n.t("Kiểm tra cập nhật", "Check for Updates")) {
                            updateChecker.checkForUpdates()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
                .padding(.vertical, 2)

                Toggle(
                    l10n.t("Tự động kiểm tra cập nhật", "Automatically check for updates"),
                    isOn: $updateChecker.autoCheckEnabled
                )
            } header: {
                Text(l10n.t("Cập nhật phần mềm", "Software Update"))
            }

            if let qrImage = donateQRImage {
                Section {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.orange)
                                Text(l10n.t("Mời PhucVang một tách cà phê", "Buy PhucVang a Coffee"))
                                    .font(.headline)
                            }
                            Text(l10n.t(
                                "Nếu HiPu Switcher giúp ích cho công việc hằng ngày của bạn, hãy quét mã QR bên cạnh để ủng hộ nhé!",
                                "If HiPu Switcher helps your daily workflow, scan the QR code to support future updates!"
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                            Button {
                                showLargeQR = true
                            } label: {
                                Label(l10n.t("Phóng to mã QR", "Enlarge QR Code"), systemImage: "qrcode.viewfinder")
                                    .font(.caption.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.top, 2)
                        }

                        Spacer(minLength: 8)

                        Button {
                            showLargeQR = true
                        } label: {
                            Image(nsImage: qrImage)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 112, height: 112)
                                .padding(8)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: .black.opacity(0.14), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .help(l10n.t("Bấm để phóng to mã QR", "Click to enlarge QR code"))
                        .popover(isPresented: $showLargeQR, arrowEdge: .trailing) {
                            VStack(spacing: 10) {
                                Image(nsImage: qrImage)
                                    .resizable()
                                    .interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 240, height: 240)
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                Text(l10n.t("Cảm ơn bạn đã ủng hộ tách cà phê! ☕️", "Thank you for the coffee! ☕️"))
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text(l10n.t("Ủng hộ tác giả", "Support"))
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var updateStatusLabel: some View {
        switch updateChecker.state {
        case .idle:
            Text(l10n.t("Phiên bản hiện tại: \(AppInfo.version)", "Current version: \(AppInfo.version)"))
                .font(.body)
        case .checking:
            Text(l10n.t("Đang kiểm tra bản cập nhật…", "Checking for updates…"))
                .font(.body)
                .foregroundStyle(.secondary)
        case .upToDate(let current):
            Label(
                l10n.t("Bạn đang dùng phiên bản mới nhất (\(current))", "You're up to date (\(current))"),
                systemImage: "checkmark.circle.fill"
            )
            .font(.callout.weight(.medium))
            .foregroundStyle(.green)
        case .updateAvailable(let release):
            Label(
                l10n.t("Có phiên bản mới: \(release.version)", "New version available: \(release.version)"),
                systemImage: "arrow.down.circle.fill"
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(.blue)
        case .notConfigured:
            Text(l10n.t(
                "Bạn đang dùng phiên bản \(AppInfo.version) (chưa cấu hình URL cập nhật).",
                "Running version \(AppInfo.version) (update feed not configured yet)."
            ))
            .font(.callout)
            .foregroundStyle(.secondary)
        case .failed:
            Label(
                l10n.t("Không thể kiểm tra cập nhật. Thử lại sau.", "Couldn't check for updates. Please try again."),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.callout)
            .foregroundStyle(.orange)
        }
    }
}

// MARK: - App Row

struct AppRowView: View {
    let path: String

    private var name: String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    private var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .interpolation(.high)
                .frame(width: 24, height: 24)
                .opacity(exists ? 1 : 0.4)
            Text(name)
                .foregroundStyle(exists ? .primary : .secondary)
            Spacer()
            if !exists {
                Label(L10n.shared.t("Không tìm thấy", "Not found"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Live Preview (used inside AppearancePreviewPanel)

struct PreviewLauncherView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var selectedIndex: Int
    var maskOnly: Bool = false

    private var mockItems: [AppItem] {
        let paths = [
            "/System/Library/CoreServices/Finder.app",
            "/Applications/Safari.app",
            "/System/Applications/Mail.app",
            "/System/Applications/Photos.app",
            "/System/Applications/Calendar.app"
        ]
        return paths.compactMap { path in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: path)
            let bundleId = Bundle(path: path)?.bundleIdentifier
            return AppItem(name: name, path: path, icon: icon, bundleIdentifier: bundleId)
        }
    }

    var body: some View {
        let totalSize: CGFloat = 800
        let scale: CGFloat = 0.42
        let apps = Array(mockItems.prefix(5))

        ZStack {
            ForEach(Array(apps.enumerated()), id: \.offset) { index, app in
                previewCard(index: index, app: app, totalSize: totalSize)
                    .zIndex(Double(apps.count - index))
                    .onTapGesture {
                        if !maskOnly {
                            selectedIndex = index
                        }
                    }
            }

            // Close button indicator matching active glass mode & style
            if !maskOnly {
                LauncherCloseButtonVisual(
                    glassMode: viewModel.glassMode,
                    backgroundStyle: viewModel.backgroundStyle,
                    cardOpacity: viewModel.cardOpacity,
                    showCardBorder: viewModel.showCardBorder,
                    isHovered: false,
                    size: 34
                )
            } else if viewModel.glassMode == .blur {
                Circle()
                    .fill(Color.white)
                    .frame(width: 34, height: 34)
            }
        }
        .frame(width: totalSize, height: totalSize)
        .scaleEffect(scale)
        .frame(width: totalSize * scale, height: totalSize * scale)
    }

    @ViewBuilder
    private func previewCard(index: Int, app: AppItem, totalSize: CGFloat) -> some View {
        let isSelected = index == selectedIndex
        if viewModel.cardStyle == .wedge {
            let midAngle = viewModel.startAngle + Double(index) * (viewModel.wedgeSpacing - viewModel.fanOverlap)
            WedgeCardView(
                app: app,
                isSelected: isSelected,
                isRunning: index == 0 || index == 2,
                isAudioPlaying: false,
                showAppName: viewModel.showAppName,
                enableHoverZoom: viewModel.enableHoverZoom,
                midAngle: midAngle,
                spacing: viewModel.wedgeSpacing,
                innerRadius: CGFloat(viewModel.wedgeInnerRadius),
                outerRadius: CGFloat(viewModel.wedgeOuterRadius),
                cornerRadius: CGFloat(viewModel.wedgeCornerRadius),
                gap: 1.0,
                viewSize: totalSize,
                iconWidth: CGFloat(viewModel.wedgeIconSize),
                fanOverlap: viewModel.fanOverlap,
                cardOpacity: viewModel.cardOpacity,
                cardBlur: viewModel.cardBlur,
                glassMode: viewModel.glassMode,
                backgroundStyle: viewModel.backgroundStyle,
                showCardBorder: viewModel.showCardBorder,
                isPreview: true,
                maskOnly: maskOnly
            )
        } else {
            let midAngle = viewModel.startAngle + Double(index) * viewModel.rectSpacing
            let r = CGFloat(viewModel.rectArcRadius)
            let rad = midAngle * .pi / 180.0
            AppCardView(
                app: app,
                isSelected: isSelected,
                isRunning: index == 0 || index == 2,
                isAudioPlaying: false,
                showAppName: viewModel.showAppName,
                enableHoverZoom: viewModel.enableHoverZoom,
                angle: midAngle,
                cardWidth: CGFloat(viewModel.rectCardWidth),
                cardHeightMultiplier: CGFloat(viewModel.rectCardHeightMultiplier),
                cardCornerRadius: CGFloat(viewModel.rectCornerRadius),
                iconSize: CGFloat(viewModel.rectIconSize),
                cardOpacity: viewModel.cardOpacity,
                cardBlur: viewModel.cardBlur,
                glassMode: viewModel.glassMode,
                backgroundStyle: viewModel.backgroundStyle,
                showCardBorder: viewModel.showCardBorder,
                isPreview: true,
                maskOnly: maskOnly
            )
            .offset(x: r * CGFloat(sin(rad)), y: -r * CGFloat(cos(rad)))
        }
    }
}


