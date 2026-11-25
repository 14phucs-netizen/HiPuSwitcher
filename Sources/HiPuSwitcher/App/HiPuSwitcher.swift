import SwiftUI
import AppKit
import HiPuShared

@main
struct HiPuSwitcher: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        Bundle.startSwizzling()
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}