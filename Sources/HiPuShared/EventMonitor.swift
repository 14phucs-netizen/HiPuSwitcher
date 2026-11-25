import Cocoa

public class EventMonitor {
    public var monitor: Any?
    public let mask: NSEvent.EventTypeMask
    public let isGlobal: Bool
    public let handler: (NSEvent) -> NSEvent?
    
    public init(mask: NSEvent.EventTypeMask, isGlobal: Bool = false, handler: @escaping (NSEvent) -> NSEvent?) {
        self.mask = mask
        self.isGlobal = isGlobal
        self.handler = handler
    }
    
    public func start() {
        if isGlobal {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
                _ = self.handler(event)
            }
        } else {
            monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
        }
    }
    
    public func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
