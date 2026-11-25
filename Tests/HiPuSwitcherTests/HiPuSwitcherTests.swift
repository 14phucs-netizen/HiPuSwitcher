import Testing
import AppKit
@testable import HiPuSwitcher

@Test func testAppSearcherRunningApps() async throws {
    let runningApps = AppSearcher.getRunningApps()
    #expect(!runningApps.isEmpty)
}

@Test func testAppItemEquality() async throws {
    let app1 = AppItem(name: "Finder", path: "/System/Library/CoreServices/Finder.app", bundleIdentifier: "com.apple.finder")
    let app2 = AppItem(name: "Finder", path: "/System/Library/CoreServices/Finder.app", bundleIdentifier: "com.apple.finder")
    let app3 = AppItem(name: "Safari", path: "/Applications/Safari.app", bundleIdentifier: "com.apple.Safari")
    
    #expect(app1 == app2)
    #expect(app1 != app3)
}

