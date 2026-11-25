import AppKit
import SwiftUI
import KeyboardShortcuts
import HiPuShared

class AppDelegate: NSObject, NSApplicationDelegate {
    var launcherPanel: FloatingPanel!
    var launcherBackdropView: NSVisualEffectView?
    var launcherHostingController: NSHostingController<LauncherView>?
    var launcherViewModel = LauncherViewModel()
    
    var globalEventMonitor: Any?
    var localEventMonitor: Any?
    var resignActiveObserver: Any?
    
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupLauncherPanel()
        setupMenuBar()
        
        // Pre-cache installed applications list in background to avoid lag on first search
        DispatchQueue.global(qos: .background).async {
            _ = AppSearcher.getAllInstalledApps()
        }
        
        KeyboardShortcuts.onKeyUp(for: .toggleLauncher) { [weak self] in
            DispatchQueue.main.async {
                self?.toggleLauncher()
            }
        }
        
        setupModifierShortcutMonitor()
        
        NotificationCenter.default.addObserver(forName: Notification.Name("MiddleClickTriggerChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.registerMiddleClickMonitor()
        }

        NotificationCenter.default.addObserver(forName: Notification.Name("AppLanguageChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.rebuildMenuBarMenu()
            self?.settingsWindow?.title = L10n.shared.t("Cài đặt", "Settings")
        }
        
        registerMiddleClickMonitor()

        // First-launch onboarding: require granting Accessibility before using the app.
        if AXIsProcessTrusted() {
            UserDefaults.standard.set(true, forKey: "HasCompletedOnboarding")
        } else if !UserDefaults.standard.bool(forKey: "HasCompletedOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.showOnboarding()
            }
        }

        // Silent background update check (once every 24h when update source is configured)
        Task { @MainActor in
            UpdateChecker.shared.checkSilentlyIfNeeded()
        }
    }
    
    var modifierMonitor: Any?
    var middleClickGlobalMonitor: Any?
    var middleClickLocalMonitor: Any?
    var wasFnShiftPressed = false
    var accessibilityTimer: Timer?
    
    func setupModifierShortcutMonitor() {
        // Local monitor always works
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        
        registerGlobalModifierMonitor()
        
        // Silently poll until the user grants Accessibility permission in Settings
        if !AXIsProcessTrusted() {
            accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.accessibilityTimer = nil
                    // Re-register global monitor now that we have permission
                    self?.registerGlobalModifierMonitor()
                    self?.registerMiddleClickMonitor()
                }
            }
        }
    }
    
    func registerMiddleClickMonitor() {
        if let existing = middleClickGlobalMonitor {
            NSEvent.removeMonitor(existing)
            middleClickGlobalMonitor = nil
        }
        if let existing = middleClickLocalMonitor {
            NSEvent.removeMonitor(existing)
            middleClickLocalMonitor = nil
        }
        
        guard UserDefaults.standard.bool(forKey: "EnableMiddleClickTrigger") else { return }
        
        // Only register global monitor when Accessibility is already granted so macOS
        // never triggers an unexpected TCC system prompt on launch.
        if AXIsProcessTrusted() {
            middleClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
                guard let self = self, event.buttonNumber == 2 else { return }
                DispatchQueue.main.async {
                    if !self.launcherPanel.isVisible {
                        self.showLauncher()
                    }
                }
            }
        }
        
        middleClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            guard let self = self, event.buttonNumber == 2 else { return event }
            DispatchQueue.main.async {
                self.toggleLauncher()
            }
            return event
        }
    }
    
    func registerGlobalModifierMonitor() {
        if let existing = modifierMonitor {
            NSEvent.removeMonitor(existing)
            modifierMonitor = nil
        }
        // Only register global keyboard modifier monitor once Accessibility is trusted;
        // calling addGlobalMonitorForEvents(.flagsChanged) before trust is granted forces
        // macOS to show the "Control this Mac / Input Monitoring" system alert on launch.
        guard AXIsProcessTrusted() else { return }
        modifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }
    
    private var lastModifierPressTime: Date = .distantPast
    private var lastPressedModifierFlags: NSEvent.ModifierFlags = []

    func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Handle fn + Shift trigger
        if UserDefaults.standard.bool(forKey: "EnableFnShiftTrigger") {
            let isFnShift = flags.contains([.function, .shift])
            if isFnShift && !wasFnShiftPressed {
                DispatchQueue.main.async { [weak self] in
                    self?.toggleLauncher()
                }
            }
            wasFnShiftPressed = isFnShift
        } else {
            wasFnShiftPressed = false
        }

        let modeRaw = UserDefaults.standard.string(forKey: "DoubleTapMode") ?? "none"
        guard modeRaw != "none" else { return }
        
        var targetModifier: NSEvent.ModifierFlags?
        if modeRaw == "doubleShift" {
            targetModifier = .shift
        } else if modeRaw == "doubleOption" {
            targetModifier = .option
        } else if modeRaw == "doubleCmd" {
            targetModifier = .command
        }
        
        guard let target = targetModifier else { return }
        
        if flags.contains(target) && !lastPressedModifierFlags.contains(target) {
            let now = Date()
            if now.timeIntervalSince(lastModifierPressTime) < 0.35 {
                DispatchQueue.main.async { [weak self] in
                    self?.toggleLauncher()
                }
                lastModifierPressTime = .distantPast
            } else {
                lastModifierPressTime = now
            }
        }
        lastPressedModifierFlags = flags
    }
    
    func setupLauncherPanel() {
        let rootView = LauncherView(
            viewModel: launcherViewModel,
            hidePanel: { [weak self] in
                self?.hideLauncher()
            },
            onBackdropUpdate: { [weak self] path, blurRadius, isLight in
                self?.updateLauncherBackdrop(path: path, blurRadius: blurRadius, isLight: isLight)
            }
        )
        launcherHostingController = NSHostingController(rootView: rootView)
        
        let panelSize = NSSize(width: 800, height: 800)
        launcherPanel = FloatingPanel(contentRect: NSRect(origin: .zero, size: panelSize), backing: .buffered, defer: false)

        // Native AppKit container: NSVisualEffectView MUST be a direct subview of contentView
        // (sibling underneath NSHostingView) so WindowServer reliably composites behind-window blur.
        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let backdrop = NSVisualEffectView(frame: container.bounds)
        backdrop.autoresizingMask = [.width, .height]
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.material = .hudWindow
        backdrop.isHidden = true
        container.addSubview(backdrop)
        self.launcherBackdropView = backdrop

        if let hostingView = launcherHostingController?.view {
            hostingView.frame = container.bounds
            hostingView.autoresizingMask = [.width, .height]
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            hostingView.layer?.borderWidth = 0
            hostingView.layer?.borderColor = NSColor.clear.cgColor
            container.addSubview(hostingView)
        }

        launcherPanel.contentView = container
        launcherPanel.isReleasedWhenClosed = false
        
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: launcherPanel, queue: .main) { [weak self] _ in
            self?.hideLauncher()
        }

        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.hideLauncher()
        }
    }

    func updateLauncherBackdrop(path: Path, blurRadius: Double, isLight: Bool) {
        guard let backdrop = launcherBackdropView else { return }

        if blurRadius <= 0.1 || path.isEmpty {
            backdrop.isHidden = true
            backdrop.maskImage = nil
            return
        }

        backdrop.isHidden = false
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        // macOS WindowServer requires BOTH alphaValue = 1.0 and maskImage alpha = 1.0
        // for behind-window blur to stay active on a borderless transparent NSPanel.
        backdrop.alphaValue = 1.0
        backdrop.appearance = NSAppearance(named: isLight ? .aqua : .darkAqua)

        backdrop.material = isLight ? .sidebar : .hudWindow

        let size = backdrop.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        let scale = launcherPanel.backingScaleFactor > 0 ? launcherPanel.backingScaleFactor : 2.0
        let pixelW = Int(size.width * scale)
        let pixelH = Int(size.height * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: pixelW,
            height: pixelH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        // Flip CGContext so SwiftUI top-left coordinates map 1:1 to AppKit window coordinates.
        // IMPORTANT: maskImage alpha MUST be 1.0 (macOS WindowServer thresholds maskImage alpha near 1.0).
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.addPath(path.cgPath)
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
        ctx.fillPath()

        if let cgImage = ctx.makeImage() {
            let maskImg = NSImage(cgImage: cgImage, size: size)
            backdrop.maskImage = maskImg
        }
    }
    
    @objc func toggleLauncher() {
        if launcherPanel.isVisible {
            hideLauncher()
        } else {
            showLauncher()
        }
    }
    
    func clampedOrigin(for size: CGSize, near mouseLocation: NSPoint) -> NSPoint {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        
        let visibleFrame = screen.visibleFrame
        
        var originX = mouseLocation.x - (size.width / 2)
        var originY = mouseLocation.y - (size.height / 2)
        
        let margin: CGFloat = 8
        originX = max(visibleFrame.minX + margin, originX)
        originX = min(visibleFrame.maxX - size.width - margin, originX)
        originY = max(visibleFrame.minY + margin, originY)
        originY = min(visibleFrame.maxY - size.height - margin, originY)
        
        return NSPoint(x: originX, y: originY)
    }
    
    func showLauncher() {
        if requiresOnboarding {
            showOnboarding()
            return
        }

        launcherViewModel.resetSearch()
        
        let mouseLoc = NSEvent.mouseLocation
        let windowSize = launcherPanel.frame.size
        let origin = clampedOrigin(for: windowSize, near: mouseLoc)
        launcherPanel.setFrameOrigin(origin)
        
        launcherPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        setupClickMonitors()
    }
    
    func hideLauncher() {
        guard launcherPanel.isVisible else { return }
        launcherPanel.orderOut(nil)
        removeClickMonitors()
    }
    
    func setupClickMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if globalEventMonitor == nil {
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.hideLauncher()
                }
            }
        }
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                let launcherVisible = self?.launcherPanel.isVisible == true
                let isOnLauncher = event.window == self?.launcherPanel || event.window?.parent == self?.launcherPanel
                
                if launcherVisible && !isOnLauncher {
                    self?.hideLauncher()
                }
                return event
            }
        }
    }
    
    func removeClickMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(named: "MenuBarIconTemplate") {
                image.isTemplate = true
                button.image = image
            } else if let path = Bundle.main.path(forResource: "MenuBarIconTemplate", ofType: "png"),
                      let image = NSImage(contentsOfFile: path) {
                image.isTemplate = true
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "HiPu Switcher")
            }
        }
        
        rebuildMenuBarMenu()
    }

    func rebuildMenuBarMenu() {
        let l = L10n.shared
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: l.t("Mở HiPu Switcher", "Show HiPu Switcher"), action: #selector(toggleLauncher), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: l.t("Cài đặt…", "Settings…"), action: #selector(openSettingsMenu), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: l.t("Kiểm tra cập nhật…", "Check for Updates…"), action: #selector(checkForUpdatesMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: l.t("Thoát", "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func openSettingsMenu() {
        openSettings()
    }

    @objc func checkForUpdatesMenu() {
        openSettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: Notification.Name("OpenAboutTabAndCheckUpdates"), object: nil)
        }
    }
    
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?

    private var requiresOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: "HasCompletedOnboarding") && !AXIsProcessTrusted()
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let view = OnboardingView { [weak self] in
                guard let self = self else { return }
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
                self.registerGlobalModifierMonitor()
                self.registerMiddleClickMonitor()
                self.openSettings()
            }
            let hostingController = NSHostingController(rootView: view)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = ""
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.contentViewController = hostingController
            window.center()
            onboardingWindow = window
        }

        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func openSettings() {
        if requiresOnboarding {
            showOnboarding()
            return
        }

        if settingsWindow == nil {
            let hostingController = NSHostingController(rootView: SettingsView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = L10n.shared.t("Cài đặt", "Settings")
            window.toolbarStyle = .unified
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.titleVisibility = .visible
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 740, height: 520)
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
