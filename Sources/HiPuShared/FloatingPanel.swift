import AppKit

public class FloatingPanel: NSPanel {
    public init(contentRect: NSRect, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: backingStoreType, defer: flag)
        
        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.backgroundColor = .clear
        self.isOpaque = false
        // Remove the outer edge glow/line around the launcher surface.
        self.hasShadow = false
        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = false
        self.isMovable = true
        self.isMovableByWindowBackground = false
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    // Become key on click so NSView.mouseDown fires reliably
    public override func mouseDown(with event: NSEvent) {
        if !isKeyWindow {
            makeKeyAndOrderFront(nil)
        }
        super.mouseDown(with: event)
    }
    
    public override func resignKey() {
        super.resignKey()
    }
    
    public override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            let cornerSize: CGFloat = 28.0 // Drag corner area size (28x28 px)
            let loc = event.locationInWindow
            let bounds = self.contentView?.bounds ?? self.frame
            
            let isTopLeft = loc.x <= cornerSize && loc.y >= bounds.height - cornerSize
            let isTopRight = loc.x >= bounds.width - cornerSize && loc.y >= bounds.height - cornerSize
            let isBottomLeft = loc.x <= cornerSize && loc.y <= cornerSize
            let isBottomRight = loc.x >= bounds.width - cornerSize && loc.y <= cornerSize
            
            if isTopLeft || isTopRight || isBottomLeft || isBottomRight {
                self.performDrag(with: event)
                return
            }
        }
        super.sendEvent(event)
    }
}
