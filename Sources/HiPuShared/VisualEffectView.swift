import SwiftUI
import AppKit
import CoreImage

public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var cornerRadius: CGFloat?
    public var alpha: CGFloat

    public init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        cornerRadius: CGFloat? = nil,
        alpha: CGFloat = 1.0
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.cornerRadius = cornerRadius
        self.alpha = alpha
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.alphaValue = alpha
        
        if let cr = cornerRadius {
            view.wantsLayer = true
            view.layer?.cornerRadius = cr
            view.layer?.masksToBounds = true
            view.layer?.cornerCurve = .continuous
        }
        
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.alphaValue = alpha
        
        if let cr = cornerRadius {
            nsView.wantsLayer = true
            nsView.layer?.cornerRadius = cr
            nsView.layer?.masksToBounds = true
            nsView.layer?.cornerCurve = .continuous
        }
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSVisualEffectView, context: Context) -> CGSize? {
        return proposal.replacingUnspecifiedDimensions(by: .zero)
    }
}

/// Native macOS behind-window blur clipped via `NSVisualEffectView.maskImage`
/// on a single unrotated full-canvas view (`alphaValue = 1.0`) so WindowServer
/// reliably blurs the real desktop/apps behind any custom `Path` (including rotated cards & wedges).
public struct MaskedBehindWindowBlurView: NSViewRepresentable {
    public var path: Path
    public var size: CGSize
    public var blurRadius: Double
    public var isLight: Bool

    public init(path: Path, size: CGSize, blurRadius: Double, isLight: Bool) {
        self.path = path
        self.size = size
        self.blurRadius = blurRadius
        self.isLight = isLight
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: CGRect(origin: .zero, size: size))
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = 1.0
        update(view)
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        update(nsView)
    }

    private func update(_ view: NSVisualEffectView) {
        if isLight {
            view.material = blurRadius < 17 ? .underWindowBackground : (blurRadius < 34 ? .sheet : .sidebar)
        } else {
            view.material = blurRadius < 17 ? .underWindowBackground : (blurRadius < 34 ? .popover : .hudWindow)
        }
        view.appearance = NSAppearance(named: isLight ? .aqua : .darkAqua)
        view.blendingMode = .behindWindow
        view.state = .active
        // IMPORTANT: Keep alphaValue = 1.0 so macOS WindowServer never disables behind-window blur!
        view.alphaValue = 1.0

        if blurRadius <= 0.1 || size.width <= 0 || size.height <= 0 {
            view.maskImage = nil
            view.isHidden = true
            return
        }

        view.isHidden = false
        let normalized = min(1.0, max(0.0, blurRadius / 50.0))
        let maskAlpha = CGFloat(0.22 + 0.78 * pow(normalized, 0.7))
        view.maskImage = renderMaskImage(path: path, size: size, alpha: maskAlpha)
    }

    private func renderMaskImage(path: Path, size: CGSize, alpha: CGFloat) -> NSImage {
        let image = NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.addPath(path.cgPath)
            ctx.setFillColor(NSColor.black.withAlphaComponent(alpha).cgColor)
            ctx.fillPath()
            return true
        }
        image.isTemplate = false
        return image
    }
}

/// Figma-style variable Gaussian Background Blur (radius in points: 0...50).
/// - In-window (`behindWindow == false`): uses CoreAnimation's public `CALayer.backgroundFilters` (`CIGaussianBlur`)
///   so the preview shows exact pixel-radius blur smoothly from 0 to 50.
/// - Behind-window (`behindWindow == true`): uses `NSVisualEffectView` with `.behindWindow` blending
///   and dynamically updates the backdrop `gaussianBlur` radius (with smooth alpha fallback).
public struct FigmaBlurView: NSViewRepresentable {
    public var radius: CGFloat
    public var isLight: Bool
    public var behindWindow: Bool

    public init(radius: CGFloat, isLight: Bool, behindWindow: Bool = true) {
        self.radius = radius
        self.isLight = isLight
        self.behindWindow = behindWindow
    }

    public func makeNSView(context: Context) -> NSView {
        if behindWindow {
            let view = NSVisualEffectView()
            view.blendingMode = .behindWindow
            view.state = .active
            view.wantsLayer = true
            applyBehindWindowBlur(to: view)
            return view
        } else {
            let view = NSView()
            view.wantsLayer = true
            view.layerUsesCoreImageFilters = true
            applyInWindowBlur(to: view)
            return view
        }
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        if let vfx = nsView as? NSVisualEffectView {
            applyBehindWindowBlur(to: vfx)
        } else {
            applyInWindowBlur(to: nsView)
        }
    }

    private func applyInWindowBlur(to view: NSView) {
        view.wantsLayer = true
        view.layerUsesCoreImageFilters = true
        guard radius > 0.1 else {
            view.layer?.backgroundFilters = nil
            return
        }
        if let filter = CIFilter(name: "CIGaussianBlur") {
            filter.setValue(radius, forKey: kCIInputRadiusKey)
            view.layer?.backgroundFilters = [filter]
        }
    }

    private func applyBehindWindowBlur(to view: NSVisualEffectView) {
        if isLight {
            view.material = radius < 17 ? .underWindowBackground : (radius < 34 ? .sheet : .sidebar)
        } else {
            view.material = radius < 17 ? .underWindowBackground : (radius < 34 ? .popover : .hudWindow)
        }
        view.appearance = NSAppearance(named: isLight ? .aqua : .darkAqua)
        view.blendingMode = .behindWindow
        view.state = .active

        if radius <= 0.1 {
            view.alphaValue = 0
            return
        }

        // Smooth progressive ramp across the entire 0...50 range
        let normalized = min(1.0, max(0.0, Double(radius) / 50.0))
        view.alphaValue = CGFloat(pow(normalized, 0.75))
    }
}
