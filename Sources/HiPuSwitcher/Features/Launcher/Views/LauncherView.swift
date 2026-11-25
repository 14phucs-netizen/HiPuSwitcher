import SwiftUI
import AppKit
import HiPuShared

// MARK: - Main Launcher View
struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    var hidePanel: () -> Void
    var onBackdropUpdate: ((Path, Double, Bool) -> Void)? = nil
    @FocusState private var isFocused: Bool
    @State private var keyboardMonitor: EventMonitor?
    @State private var isCloseHovered = false
    @State private var contextMenuHandler = ContextMenuActionHandler()

    let viewSize: CGFloat = 800
    let gapDeg: Double = 1.0

    var body: some View {
        ZStack {
            MouseTrackingView(
                onMove: { point in
                    let total = min(viewModel.results.count, 12)
                    updateSelection(at: point, total: total)
                },
                onClick: { point in
                    let total = min(viewModel.results.count, 12)
                    handleClick(at: point, total: total)
                },
                onRightClick: { point, sourceView in
                    let total = min(viewModel.results.count, 12)
                    handleRightClick(at: point, total: total, in: sourceView)
                }
            )
            .frame(width: viewSize, height: viewSize)
            .allowsHitTesting(true)

            TextField("", text: $viewModel.searchText)
                .focused($isFocused)
                .opacity(0)
                .frame(width: 0, height: 0)

            let displayAppsCount = 12
            let displayApps = Array(viewModel.results.prefix(displayAppsCount))
            let total = displayApps.count

            if total > 0 {
                ForEach(Array(displayApps.enumerated()), id: \.element.id) { index, app in
                    let isSelected = index == viewModel.selectedIndex
                    
                    if viewModel.cardStyle == .wedge {
                        let midAngle = viewModel.startAngle + Double(index) * (viewModel.wedgeSpacing - viewModel.fanOverlap)
                        WedgeCardView(
                            app: app,
                            isSelected: isSelected,
                            isRunning: viewModel.isRunning(app: app),
                            isAudioPlaying: viewModel.isAudioPlaying(app: app),
                            showAppName: viewModel.showAppName,
                            enableHoverZoom: viewModel.enableHoverZoom,
                            midAngle: midAngle,
                            spacing: viewModel.wedgeSpacing,
                            innerRadius: CGFloat(viewModel.wedgeInnerRadius),
                            outerRadius: CGFloat(viewModel.wedgeOuterRadius),
                            cornerRadius: CGFloat(viewModel.wedgeCornerRadius),
                            gap: gapDeg,
                            viewSize: viewSize,
                            iconWidth: CGFloat(viewModel.wedgeIconSize),
                            fanOverlap: viewModel.fanOverlap,
                            cardOpacity: viewModel.cardOpacity,
                            cardBlur: viewModel.cardBlur,
                            glassMode: viewModel.glassMode,
                            backgroundStyle: viewModel.backgroundStyle,
                            showCardBorder: viewModel.showCardBorder
                        )
                        .zIndex(Double(total - index))
                        .allowsHitTesting(false)
                    } else {
                        let midAngle = viewModel.startAngle + Double(index) * viewModel.rectSpacing
                        let r = CGFloat(viewModel.rectArcRadius)
                        let rad = midAngle * .pi / 180.0
                        AppCardView(
                            app: app,
                            isSelected: isSelected,
                            isRunning: viewModel.isRunning(app: app),
                            isAudioPlaying: viewModel.isAudioPlaying(app: app),
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
                            showCardBorder: viewModel.showCardBorder
                        )
                        .offset(x: r * CGFloat(sin(rad)), y: -r * CGFloat(cos(rad)))
                        .zIndex(Double(total - index))
                        .allowsHitTesting(false)
                    }
                }

                // Center button
                if viewModel.searchText.isEmpty {
                    closeButton
                        .zIndex(200)
                } else {
                    Text(viewModel.searchText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 120)
                        .lineLimit(1)
                        .zIndex(200)
                }
            } else {
                Text("No Apps")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(width: viewSize, height: viewSize)
        .contentShape(Rectangle())
        .background(Color.clear)
        .onAppear {
            isFocused = true
            setupKeyboardMonitor()
            viewModel.refreshLiveStatuses()
            syncBackdrop()
        }
        .onDisappear {
            keyboardMonitor?.stop()
        }
        .onChange(of: backdropFingerprint) { _, _ in
            syncBackdrop()
        }
    }

    private var backdropFingerprint: String {
        let total = min(viewModel.results.count, 12)
        return "\(total)-\(viewModel.selectedIndex)-\(viewModel.cardStyle.rawValue)-\(viewModel.glassMode.rawValue)-\(viewModel.cardBlur)-\(viewModel.backgroundStyle.isLight)-\(viewModel.startAngle)-\(viewModel.enableHoverZoom)-\(viewModel.wedgeInnerRadius)-\(viewModel.wedgeOuterRadius)-\(viewModel.wedgeSpacing)-\(viewModel.fanOverlap)-\(viewModel.wedgeCornerRadius)-\(viewModel.rectArcRadius)-\(viewModel.rectCardWidth)-\(viewModel.rectCardHeightMultiplier)-\(viewModel.rectSpacing)-\(viewModel.rectCornerRadius)"
    }

    private func syncBackdrop() {
        let total = min(viewModel.results.count, 12)
        // Only activate NSVisualEffectView backdrop in classic .blur mode;
        // .liquidGlass uses native macOS 26+ .glassEffect() directly on each card!
        let activeBlur = (viewModel.glassMode == .blur) ? 48.0 : 0.0
        let path = (total > 0 && viewModel.glassMode == .blur) ? combinedBackdropMaskPath(total: total) : Path()
        onBackdropUpdate?(path, activeBlur, viewModel.backgroundStyle.isLight)
    }

    /// Computes the exact combined SwiftUI `Path` of all visible cards in the 800x800 canvas
    /// so a single unrotated `NSVisualEffectView(blendingMode: .behindWindow)` blurs cleanly behind every card.
    private func combinedBackdropMaskPath(total: Int) -> Path {
        var combined = Path()
        let center = CGPoint(x: viewSize / 2, y: viewSize / 2)

        for index in 0..<total {
            let isSelected = index == viewModel.selectedIndex
            let useScale = isSelected && viewModel.enableHoverZoom

            if viewModel.cardStyle == .wedge {
                let midAngle = viewModel.startAngle + Double(index) * (viewModel.wedgeSpacing - viewModel.fanOverlap)
                let start = midAngle - viewModel.wedgeSpacing / 2 + gapDeg
                let end = midAngle + viewModel.wedgeSpacing / 2 - gapDeg
                let midRad = midAngle * .pi / 180
                let offsetDistance: CGFloat = useScale ? 12 : 0
                let offsetX = offsetDistance * CGFloat(cos(midRad))
                let offsetY = offsetDistance * CGFloat(sin(midRad))
                let wedgeScale: CGFloat = useScale ? 1.06 : 1.0

                let wedge = WedgeShape(
                    startAngle: .degrees(start),
                    endAngle: .degrees(end),
                    innerRadius: CGFloat(viewModel.wedgeInnerRadius),
                    outerRadius: CGFloat(viewModel.wedgeOuterRadius),
                    cornerRadius: CGFloat(viewModel.wedgeCornerRadius)
                )
                var transform = CGAffineTransform.identity
                transform = transform.translatedBy(x: center.x, y: center.y)
                transform = transform.scaledBy(x: wedgeScale, y: wedgeScale)
                transform = transform.translatedBy(x: -center.x + offsetX, y: -center.y + offsetY)
                combined.addPath(wedge.path(in: CGRect(x: 0, y: 0, width: viewSize, height: viewSize)), transform: transform)
            } else {
                let midAngle = viewModel.startAngle + Double(index) * viewModel.rectSpacing
                let cardWidth = CGFloat(viewModel.rectCardWidth)
                let cardHeight = cardWidth * CGFloat(viewModel.rectCardHeightMultiplier)
                let scale: CGFloat = useScale ? 1.08 : 1.0
                let offsetDistance: CGFloat = useScale ? 8 : 0

                let shape = RoundedRectangle(cornerRadius: CGFloat(viewModel.rectCornerRadius), style: .continuous)
                let cardRect = CGRect(x: -cardWidth / 2, y: -cardHeight / 2, width: cardWidth, height: cardHeight)

                var transform = CGAffineTransform.identity
                transform = transform.translatedBy(x: center.x, y: center.y)
                transform = transform.rotated(by: CGFloat(midAngle * .pi / 180.0))
                transform = transform.translatedBy(x: 0, y: -CGFloat(viewModel.rectArcRadius) - offsetDistance)
                transform = transform.scaledBy(x: scale, y: scale)
                combined.addPath(shape.path(in: cardRect), transform: transform)
            }
        }

        // Include center close button circle in behind-window blur mask
        let closeSize: CGFloat = isCloseHovered ? 34 * 1.1 : 34
        let closeRect = CGRect(
            x: center.x - closeSize / 2,
            y: center.y - closeSize / 2,
            width: closeSize,
            height: closeSize
        )
        combined.addPath(Circle().path(in: closeRect))

        return combined
    }

    var closeButton: some View {
        LauncherCloseButtonVisual(
            glassMode: viewModel.glassMode,
            backgroundStyle: viewModel.backgroundStyle,
            cardOpacity: viewModel.cardOpacity,
            showCardBorder: viewModel.showCardBorder,
            isHovered: isCloseHovered,
            size: 34
        )
        .scaleEffect(isCloseHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isCloseHovered)
        .onHover { isCloseHovered = $0 }
        .onTapGesture { hidePanel() }
        .zIndex(300)
        .allowsHitTesting(true)
    }

    private func handleClick(at point: CGPoint, total: Int) {
        let center = CGPoint(x: viewSize / 2, y: viewSize / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        // Close button check
        if distance < 34 {
            hidePanel()
            return
        }

        // Check if an app was clicked
        if let index = appIndex(at: point, total: total) {
            viewModel.selectedIndex = index
            viewModel.launchSelected(hidePanel: hidePanel)
        } else {
            // Clicked anywhere else in the 800x800 area
            hidePanel()
        }
    }

    private func handleRightClick(at point: CGPoint, total: Int, in sourceView: NSView) {
        guard let index = appIndex(at: point, total: total), index < viewModel.results.count else {
            return
        }

        viewModel.selectedIndex = index
        let app = viewModel.results[index]
        showContextMenu(for: app, at: point, in: sourceView)
    }

    private func showContextMenu(for app: AppItem, at point: CGPoint, in sourceView: NSView) {
        let menu = NSMenu()

        let quitItem = NSMenuItem(title: "Quit \(app.name)", action: #selector(ContextMenuActionHandler.quitApp), keyEquivalent: "")
        quitItem.target = contextMenuHandler
        quitItem.isEnabled = viewModel.canQuit(app: app)

        contextMenuHandler.onQuit = {
            _ = viewModel.quit(app: app)
            hidePanel()
        }

        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: NSPoint(x: point.x, y: point.y), in: sourceView)
    }

    /// Convert window-local mouse position to view-local position (flipped Y for SwiftUI coords)
    private func viewLocalPoint(from event: NSEvent) -> CGPoint? {
        let window = event.window ?? NSApp.windows.first(where: { $0.isFloatingPanel })
        guard let window = window,
              let contentView = window.contentView else { return nil }
              
        let windowPoint: NSPoint
        if event.window != nil {
            windowPoint = event.locationInWindow
        } else {
            windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        }
        
        // contentView is NSHostingView, which is already flipped (Y=0 at top)
        let viewPoint = contentView.convert(windowPoint, from: nil)
        return CGPoint(x: viewPoint.x, y: viewPoint.y)
    }

    private func appIndex(at location: CGPoint, total: Int) -> Int? {
        guard total > 0 else { return nil }

        let center = CGPoint(x: viewSize / 2, y: viewSize / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        // Ignore center close button
        if distance < 30 { return nil }

        // Determine valid ring radius
        let innerRadius: CGFloat
        let outerRadius: CGFloat

        if viewModel.cardStyle == .wedge {
            innerRadius = CGFloat(viewModel.wedgeInnerRadius) - 10
            outerRadius = CGFloat(viewModel.wedgeOuterRadius) + 40
        } else {
            let cardHeight = CGFloat(viewModel.rectCardWidth) *
                             CGFloat(viewModel.rectCardHeightMultiplier)
            innerRadius = CGFloat(viewModel.rectArcRadius) - cardHeight / 2 - 20
            outerRadius = CGFloat(viewModel.rectArcRadius) + cardHeight / 2 + 20
        }

        guard distance >= innerRadius && distance <= outerRadius else {
            return nil
        }

        // Standard math: atan2(dy, dx). Since Y goes down (0 at top), 
        // top is (0, -400) -> atan2(-400, 0) = -90 degrees.
        var angle = atan2(dy, dx) * 180 / .pi
        
        // Rect cards are drawn offset UP (Y: -R) before rotation, making 0° = UP.
        // Math angle has 0° = RIGHT. We add 90° so math UP (-90°) becomes 0°.
        if viewModel.cardStyle == .rectangular {
            angle += 90
        }
        
        if angle < 0 { angle += 360 }

        let step = (viewModel.cardStyle == .wedge)
            ? (viewModel.wedgeSpacing - viewModel.fanOverlap)
            : viewModel.rectSpacing

        var bestIndex: Int?
        var bestDifference = Double.greatestFiniteMagnitude

        for index in 0..<total {
            var target = viewModel.startAngle + Double(index) * step
            
            // Normalize target to [0, 360)
            while target < 0 { target += 360 }
            while target >= 360 { target -= 360 }

            // Calculate shortest angular distance
            var diff = abs(angle - target)
            if diff > 180 {
                diff = 360 - diff
            }

            if diff < bestDifference {
                bestDifference = diff
                bestIndex = index
            }
        }

        let maxDiff = (viewModel.cardStyle == .wedge)
            ? (viewModel.wedgeSpacing / 2)
            : (viewModel.rectSpacing / 2)

        guard let index = bestIndex,
              bestDifference <= maxDiff else {
            return nil
        }

        return index
    }

    private func updateSelection(at location: CGPoint, total: Int) {
        let index = appIndex(at: location, total: total)
        if viewModel.selectedIndex != (index ?? -1) {
            viewModel.selectedIndex = index ?? -1
        }
    }

    private func setupKeyboardMonitor() {
        keyboardMonitor = EventMonitor(mask: .keyDown) { event in
            switch event.keyCode {
            case 125, 124: viewModel.moveSelectionDown(); return nil
            case 126, 123: viewModel.moveSelectionUp();   return nil
            case 36: viewModel.launchSelected(hidePanel: hidePanel); return nil
            case 53: hidePanel(); return nil
            default: return event
            }
        }
        keyboardMonitor?.start()
    }
}

// MARK: - Rotated Rounded Rectangle Shape (avoids view-level .rotationEffect breaking macOS 26 .glassEffect AABB)

struct RotatedRoundedRectShape: Shape {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let angle: Angle

    func path(in rect: CGRect) -> Path {
        let base = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .path(in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: rect.midX, y: rect.midY)
        transform = transform.rotated(by: CGFloat(angle.radians))
        return base.applying(transform)
    }
}

// MARK: - Liquid Glass Helper (macOS 26+ Native, with graceful fallback)

struct LauncherCloseButtonVisual: View {
    let glassMode: CardGlassMode
    let backgroundStyle: BackgroundStyle
    let cardOpacity: Double
    let showCardBorder: Bool
    var isHovered: Bool = false
    var size: CGFloat = 34

    private var isLight: Bool {
        backgroundStyle == .glassLight || backgroundStyle == .solidLight || backgroundStyle == .glassSolidLight
    }

    private var iconColor: Color {
        switch glassMode {
        case .liquidGlass:
            return isLight
                ? Color.black.opacity(isHovered ? 0.92 : 0.68)
                : Color.white.opacity(isHovered ? 1.0 : 0.80)
        case .blur:
            return isLight
                ? Color.black.opacity(isHovered ? 0.90 : 0.65)
                : Color.white.opacity(isHovered ? 1.0 : 0.78)
        case .off:
            if cardOpacity <= 0.05 {
                return Color.white.opacity(isHovered ? 1.0 : 0.80)
            }
            return isLight
                ? Color.black.opacity(isHovered ? 0.90 : 0.65)
                : Color.white.opacity(isHovered ? 1.0 : 0.80)
        }
    }

    var body: some View {
        let shape = Circle()

        Image(systemName: "xmark")
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundColor(iconColor)
            .frame(width: size, height: size)
            .contentShape(shape)
            .background {
                switch glassMode {
                case .liquidGlass:
                    LiquidGlassShapeLayer(
                        shape: shape,
                        isLight: isLight,
                        isSelected: isHovered,
                        tintOpacity: cardOpacity
                    )
                case .blur:
                    ZStack {
                        shape
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, isLight ? .light : .dark)
                        shape
                            .fill(
                                (isLight ? Color.white : Color.black)
                                    .opacity(max(0.08, cardOpacity * (isHovered ? 0.50 : 0.35)))
                            )
                    }
                case .off:
                    if cardOpacity <= 0.05 {
                        shape
                            .fill(Color.black.opacity(isHovered ? 0.28 : 0.16))
                    } else {
                        shape
                            .fill(
                                (isLight ? Color.white : Color(white: 0.14))
                                    .opacity(min(1.0, cardOpacity * (isHovered ? 1.05 : 0.92)))
                            )
                    }
                }
            }
            .overlay {
                if showCardBorder || (glassMode == .off && cardOpacity <= 0.05) {
                    shape
                        .stroke(
                            (isLight && glassMode != .off ? Color.black : Color.white)
                                .opacity(isHovered ? 0.55 : 0.28),
                            lineWidth: 0.8
                        )
                }
            }
            .shadow(
                color: .black.opacity(glassMode == .liquidGlass ? (isHovered ? 0.20 : 0.12) : (isHovered ? 0.25 : 0.15)),
                radius: isHovered ? 8 : 4
            )
    }
}

private struct LiquidGlassShapeLayer<S: Shape>: View {
    let shape: S
    let isLight: Bool
    let isSelected: Bool
    let tintOpacity: Double

    var body: some View {
        let tintColor = isLight
            ? Color.white.opacity(tintOpacity * (isSelected ? 0.55 : 0.35))
            : Color.black.opacity(tintOpacity * (isSelected ? 0.55 : 0.35))

        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(
                    (tintOpacity < 0.25 ? Glass.clear : Glass.regular).tint(tintColor),
                    in: shape
                )
                .environment(\.colorScheme, isLight ? .light : .dark)
        } else {
            ZStack {
                shape
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, isLight ? .light : .dark)
                shape
                    .fill(tintColor)
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isLight ? 0.85 : 0.45),
                                Color.white.opacity(0.08),
                                Color.white.opacity(isLight ? 0.45 : 0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
        }
    }
}

// MARK: - App Card (Rectangular)
struct AppCardView: View {
    let app: AppItem
    let isSelected: Bool
    let isRunning: Bool
    let isAudioPlaying: Bool
    let showAppName: Bool
    let enableHoverZoom: Bool
    let angle: Double
    let cardWidth: CGFloat
    let cardHeightMultiplier: CGFloat
    let cardCornerRadius: CGFloat
    let iconSize: CGFloat
    let cardOpacity: Double
    var cardBlur: Double = 48.0
    var glassMode: CardGlassMode = .blur
    let backgroundStyle: BackgroundStyle
    var showCardBorder: Bool = true
    var isPreview: Bool = false
    var maskOnly: Bool = false

    private var liveBlurMaterial: Material {
        if cardBlur < 13 { return .ultraThinMaterial }
        if cardBlur < 26 { return .thinMaterial }
        if cardBlur < 39 { return .regularMaterial }
        return .thickMaterial
    }

    private var liveBlurOpacity: Double {
        let normalized = min(1.0, max(0.0, cardBlur / 50.0))
        return pow(normalized, 0.65)
    }

    var body: some View {
        let cardHeight = cardWidth * cardHeightMultiplier

        // Derived states
        let useScale = isSelected && enableHoverZoom
        let scale: CGFloat = useScale ? 1.08 : 1.0
        let iconScale: CGFloat = useScale ? 1.12 : 1.0
        let offsetDistance: CGFloat = useScale ? 8 : 0
        let isLight = backgroundStyle.isLight

        let rad = angle * .pi / 180.0
        let hoverDX = offsetDistance * CGFloat(sin(rad))
        let hoverDY = -offsetDistance * CGFloat(cos(rad))
        let boxSize = ceil(hypot(cardWidth, cardHeight) * 1.15)

        let shape = RotatedRoundedRectShape(
            width: cardWidth * scale,
            height: cardHeight * scale,
            cornerRadius: cardCornerRadius * scale,
            angle: .degrees(angle)
        )

        ZStack {
            if maskOnly {
                shape.fill(Color.white)
            } else {
                if glassMode == .liquidGlass {
                    LiquidGlassShapeLayer(
                        shape: shape,
                        isLight: isLight,
                        isSelected: isSelected,
                        tintOpacity: cardOpacity
                    )
                    .frame(width: boxSize, height: boxSize)
                } else {
                    // Within-window glass layer so overlapping cards also blur the cards underneath them
                    if !isPreview && glassMode == .blur && cardBlur > 0.1 {
                        shape
                            .fill(liveBlurMaterial)
                            .opacity(liveBlurOpacity)
                            .environment(\.colorScheme, isLight ? .light : .dark)
                    }

                    shape
                        .fill(isLight
                            ? Color(white: isSelected ? 0.90 : 1.0)
                            : Color(white: isSelected ? 0.24 : 0.06))
                        .opacity(cardOpacity)
                }

                if showCardBorder {
                    shape
                        .stroke(
                            backgroundStyle.strokeGradient(isSelected: isSelected),
                            lineWidth: isSelected ? 1.5 : 0.8
                        )

                    shape
                        .stroke(Color.black.opacity(isLight ? (isSelected ? 0.08 : 0.05) : (isSelected ? 0.25 : 0.15)), lineWidth: 0.5)
                }

                // Icon (already rotated nicely with card orientation)
                Image(nsImage: app.icon)
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .scaleEffect(iconScale)
                    .overlay(alignment: .topTrailing) {
                        if isAudioPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: max(10, iconSize * 0.18), weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.black.opacity(0.55)))
                                .offset(x: 8, y: -8)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if isRunning {
                            Circle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 4, height: 4)
                                .shadow(color: .white.opacity(0.4), radius: 2)
                                .offset(y: 8)
                        }
                    }
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: boxSize, height: boxSize)
        .offset(x: hoverDX, y: hoverDY)
        .overlay {
            if !maskOnly {
                tooltipOverlay(cardHeight: cardHeight)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isSelected)
    }

    @ViewBuilder
    func tooltipOverlay(cardHeight: CGFloat) -> some View {
        if isSelected && showAppName {
            let rad = angle * .pi / 180.0
            let dist = cardHeight / 2 + 28
            RotatedTooltipView(
                title: app.name,
                angle: .degrees(angle),
                backgroundStyle: backgroundStyle,
                glassMode: glassMode,
                cardOpacity: cardOpacity
            )
            .offset(x: dist * CGFloat(sin(rad)), y: -dist * CGFloat(cos(rad)))
            .transition(.opacity)
        }
    }
}

// MARK: - Wedge Card View
struct WedgeCardView: View {
    let app: AppItem
    let isSelected: Bool
    let isRunning: Bool
    let isAudioPlaying: Bool
    let showAppName: Bool
    let enableHoverZoom: Bool
    let midAngle: Double
    let spacing: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let cornerRadius: CGFloat
    let gap: Double
    let viewSize: CGFloat
    let iconWidth: CGFloat
    let fanOverlap: Double
    let cardOpacity: Double
    var cardBlur: Double = 48.0
    var glassMode: CardGlassMode = .blur
    let backgroundStyle: BackgroundStyle
    var showCardBorder: Bool = true
    var isPreview: Bool = false
    var maskOnly: Bool = false

    private var liveBlurMaterial: Material {
        if cardBlur < 13 { return .ultraThinMaterial }
        if cardBlur < 26 { return .thinMaterial }
        if cardBlur < 39 { return .regularMaterial }
        return .thickMaterial
    }

    private var liveBlurOpacity: Double {
        let normalized = min(1.0, max(0.0, cardBlur / 50.0))
        return pow(normalized, 0.65)
    }

    var body: some View {
        let start = midAngle - spacing / 2 + gap
        let end   = midAngle + spacing / 2 - gap
        let midRad = midAngle * .pi / 180
        let midR = (innerRadius + outerRadius) / 2

        let iconX = viewSize / 2 + midR * CGFloat(cos(midRad))
        let iconY = viewSize / 2 + midR * CGFloat(sin(midRad))

        let labelR = outerRadius + 20
        let labelX = viewSize / 2 + labelR * CGFloat(cos(midRad))
        let labelY = viewSize / 2 + labelR * CGFloat(sin(midRad))

        let wedge = WedgeShape(
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            innerRadius: innerRadius,
            outerRadius: outerRadius,
            cornerRadius: cornerRadius
        )

        // Style-driven values
        let useScale = isSelected && enableHoverZoom

        let iconScale: CGFloat    = useScale ? 1.15 : 1.0
        // Scale the entire wedge only for .scale style
        let wedgeScale: CGFloat   = useScale ? 1.06 : 1.0
        // Offset outward only for .scale style
        let offsetDistance: CGFloat = useScale ? 12 : 0
        let offsetX = offsetDistance * CGFloat(cos(midRad))
        let offsetY = offsetDistance * CGFloat(sin(midRad))
        let isLight = backgroundStyle.isLight

        ZStack {
            if maskOnly {
                wedge.fill(Color.white)
            } else {
                if glassMode == .liquidGlass {
                    LiquidGlassShapeLayer(
                        shape: wedge,
                        isLight: isLight,
                        isSelected: isSelected,
                        tintOpacity: cardOpacity
                    )
                    .frame(width: viewSize, height: viewSize)
                } else {
                    // Within-window glass layer so overlapping wedges also blur the wedges underneath them
                    if !isPreview && glassMode == .blur && cardBlur > 0.1 {
                        wedge
                            .fill(liveBlurMaterial)
                            .opacity(liveBlurOpacity)
                            .environment(\.colorScheme, isLight ? .light : .dark)
                    }

                    wedge
                        .fill(isLight
                            ? Color(white: isSelected ? 0.90 : 1.0)
                            : Color(white: isSelected ? 0.24 : 0.06))
                        .opacity(cardOpacity)
                }

                if showCardBorder {
                    wedge
                        .stroke(
                            backgroundStyle.strokeGradient(isSelected: isSelected),
                            lineWidth: isSelected ? 1.5 : 0.8
                        )
                }
            }
        }
        .frame(width: viewSize, height: viewSize)
        .offset(x: offsetX, y: offsetY)
        .overlay {
            if !maskOnly {
                Image(nsImage: app.icon)
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: iconWidth, height: iconWidth)
                    .scaleEffect(iconScale)
                    .overlay(alignment: .topTrailing) {
                        if isAudioPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: max(10, iconWidth * 0.2), weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.black.opacity(0.55)))
                                .offset(x: 8, y: -8)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if isRunning {
                            Circle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 4, height: 4)
                                .shadow(color: .white.opacity(0.4), radius: 2)
                                .offset(y: 8)
                        }
                    }
                    .rotationEffect(.degrees(midAngle + 90))
                    .position(x: iconX + offsetX, y: iconY + offsetY)
                    .allowsHitTesting(false)
            }
        }
        .overlay(
            Group {
                if !maskOnly && isSelected && showAppName {
                    RotatedTooltipView(
                        title: app.name,
                        angle: .degrees(midAngle + 90),
                        backgroundStyle: backgroundStyle,
                        glassMode: glassMode,
                        cardOpacity: cardOpacity
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                    .position(x: labelX + offsetX, y: labelY + offsetY)
                    .allowsHitTesting(false)
                }
            }
        )
        .scaleEffect(wedgeScale)
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isSelected)
    }
}

// MARK: - Mouse Tracking View (NSViewRepresentable)
struct MouseTrackingView: NSViewRepresentable {
    var onMove: (CGPoint) -> Void
    var onClick: (CGPoint) -> Void
    var onRightClick: (CGPoint, NSView) -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onMove = onMove
        view.onClick = onClick
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onMove = onMove
        nsView.onClick = onClick
        nsView.onRightClick = onRightClick
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: TrackingNSView, context: Context) -> CGSize? {
        return proposal.replacingUnspecifiedDimensions(by: CGSize(width: 800, height: 800))
    }

    class TrackingNSView: NSView {
        var onMove: ((CGPoint) -> Void)?
        var onClick: ((CGPoint) -> Void)?
        var onRightClick: ((CGPoint, NSView) -> Void)?

        override var isFlipped: Bool { return true }
        override var acceptsFirstResponder: Bool { return true }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return true
        }

        // KEY FIX: NSView is transparent, so by default it ignores clicks.
        // We must override hitTest to force it to receive mouseDown events.
        override func hitTest(_ point: NSPoint) -> NSView? {
            return self
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas { removeTrackingArea(area) }
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
                owner: self,
                userInfo: nil
            ))
        }

        override func mouseEntered(with event: NSEvent) {
            window?.makeKey()
        }

        override func mouseExited(with event: NSEvent) {
            onMove?(CGPoint(x: -9999, y: -9999))
        }

        override func mouseMoved(with event: NSEvent) {
            onMove?(flippedPoint(from: event))
        }

        override func mouseDragged(with event: NSEvent) {
            onMove?(flippedPoint(from: event))
        }

        override func mouseDown(with event: NSEvent) {
            onClick?(flippedPoint(from: event))
        }

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?(flippedPoint(from: event), self)
        }

        override func otherMouseDown(with event: NSEvent) {
            if event.buttonNumber == 1 {
                onRightClick?(flippedPoint(from: event), self)
            } else {
                super.otherMouseDown(with: event)
            }
        }

        private func flippedPoint(from event: NSEvent) -> CGPoint {
            // Since isFlipped is true, this already returns Y=0 at the top
            return convert(event.locationInWindow, from: nil)
        }
    }
}

private final class ContextMenuActionHandler: NSObject {
    var onQuit: (() -> Void)?

    @objc func quitApp(_ sender: NSMenuItem) {
        onQuit?()
    }
}

/// Tooltip pill rotated inside its `Shape` path (not view-level `.rotationEffect` on `.glassEffect`),
/// so Liquid Glass aligns to the card's exact angle with zero bounding-box distortion.
struct RotatedTooltipView: View {
    let title: String
    let angle: Angle
    let backgroundStyle: BackgroundStyle
    var glassMode: CardGlassMode = .blur
    var cardOpacity: Double = 0.65

    var body: some View {
        if glassMode == .liquidGlass {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .fixedSize()
                .hidden()
                .overlay {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let box = ceil(hypot(w, h)) + 4
                        let pillShape = RotatedRoundedRectShape(
                            width: w,
                            height: h,
                            cornerRadius: h / 2,
                            angle: angle
                        )
                        ZStack {
                            LiquidGlassShapeLayer(
                                shape: pillShape,
                                isLight: backgroundStyle.isLight,
                                isSelected: true,
                                tintOpacity: cardOpacity
                            )
                            .frame(width: box, height: box)

                            Text(title)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(backgroundStyle.tooltipTextColor)
                                .fixedSize()
                                .rotationEffect(angle)
                        }
                        .frame(width: box, height: box)
                        .position(x: w / 2, y: h / 2)
                    }
                }
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        } else {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(backgroundStyle.tooltipTextColor)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(TooltipBackground(backgroundStyle: backgroundStyle, glassMode: glassMode, cardOpacity: cardOpacity))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .fixedSize()
                .rotationEffect(angle)
        }
    }
}

struct TooltipBackground: View {
    let backgroundStyle: BackgroundStyle
    var glassMode: CardGlassMode = .blur
    var cardOpacity: Double = 0.65
    
    var body: some View {
        let isLight = backgroundStyle.isLight
        let hasBlur = backgroundStyle.hasBlur
        
        if glassMode == .liquidGlass {
            LiquidGlassShapeLayer(
                shape: Capsule(),
                isLight: isLight,
                isSelected: true,
                tintOpacity: cardOpacity
            )
        } else {
            ZStack {
                if hasBlur {
                    VisualEffectView(material: isLight ? .sidebar : .hudWindow, blendingMode: .withinWindow)
                        .clipShape(Capsule())
                        .opacity(isLight ? 0.6 : 0.8)
                }
                Capsule()
                    .fill(backgroundStyle.tooltipFill())
                Capsule()
                    .strokeBorder(backgroundStyle.tooltipStrokeColor, lineWidth: 0.8)
            }
        }
    }
}
