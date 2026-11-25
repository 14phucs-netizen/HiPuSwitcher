import Testing
import Foundation
@testable import HiPuSwitcher

/// Dùng danh sách tuỳ chỉnh với app hệ thống cố định để kết quả không phụ thuộc máy đang mở app nào.
extension DefaultsBackedTests {
@MainActor
@Suite
struct LauncherViewModelTests {
    private static let finder = "/System/Library/CoreServices/Finder.app"
    private static let calculator = "/System/Applications/Calculator.app"
    private static let textEdit = "/System/Applications/TextEdit.app"
    private static let calculatorID = "com.apple.calculator"
    private static let textEditID = "com.apple.TextEdit"

    private static let keys = [
        "UseCustomList", "CustomAppPaths", "HideInactiveApps", "UsageCounts", "CardStyle",
        "ShowAppName", "EnableHoverZoom", "StartAngle", "CardOpacity", "GlassTheme", "BackgroundStyle",
        "WedgeSpacing", "WedgeInnerRadius", "WedgeOuterRadius", "WedgeCornerRadius", "WedgeIconSize",
        "FanOverlap", "RectSpacing", "RectArcRadius", "RectCardWidth", "RectCardHeightMultiplier",
        "RectCornerRadius", "RectIconSize",
    ]

    private func makeViewModel(customPaths: [String]? = nil, usage: [String: Int] = [:]) -> LauncherViewModel {
        let defaults = UserDefaults.standard
        for key in Self.keys { defaults.removeObject(forKey: key) }
        if let customPaths {
            defaults.set(true, forKey: "UseCustomList")
            defaults.set(try? JSONEncoder().encode(customPaths), forKey: "CustomAppPaths")
        }
        if !usage.isEmpty { defaults.set(usage, forKey: "UsageCounts") }
        return LauncherViewModel()
    }

    @Test func customListKeepsSavedOrderWithoutInjectingFinder() {
        let vm = makeViewModel(customPaths: [Self.textEdit, Self.calculator])
        #expect(vm.results.map(\.path) == [Self.textEdit, Self.calculator])
    }

    @Test func customListSortsByUsageCount() {
        let vm = makeViewModel(
            customPaths: [Self.textEdit, Self.calculator],
            usage: [Self.calculatorID: 5, Self.textEditID: 1]
        )
        #expect(vm.results.map(\.path) == [Self.calculator, Self.textEdit])
    }

    @Test func finderIsPinnedFirstEvenWithLowerUsage() {
        let vm = makeViewModel(
            customPaths: [Self.calculator, Self.finder],
            usage: [Self.calculatorID: 99]
        )
        #expect(vm.results.first?.path == Self.finder)
    }

    @Test func defaultListAlwaysStartsWithFinder() {
        let vm = makeViewModel()
        #expect(vm.results.first?.path == Self.finder)
    }

    @Test func hideInactiveAppsDropsAppsThatAreNotRunning() {
        // Một đường dẫn không tồn tại không có bundle id nên bị coi là không hoạt động.
        let vm = makeViewModel(customPaths: ["/Nonexistent/Ghost.app", Self.finder])
        #expect(vm.results.count == 2)

        UserDefaults.standard.set(true, forKey: "HideInactiveApps")
        vm.refreshApps()
        #expect(vm.results.map(\.path) == [Self.finder])
    }

    @Test func refreshReadsAppearanceSettingsFromDefaults() {
        let vm = makeViewModel()
        let defaults = UserDefaults.standard
        defaults.set("Rectangular", forKey: "CardStyle")
        defaults.set(false, forKey: "ShowAppName")
        defaults.set(42.0, forKey: "WedgeInnerRadius")
        defaults.set("Glass Light", forKey: "BackgroundStyle")
        vm.refreshApps()

        #expect(vm.cardStyle == .rectangular)
        #expect(vm.showAppName == false)
        #expect(vm.wedgeInnerRadius == 42)
        #expect(vm.backgroundStyle == .glassLight)
    }

    @Test func selectionMovesWithinBounds() {
        let vm = makeViewModel(customPaths: [Self.textEdit, Self.calculator])
        #expect(vm.selectedIndex == 0)

        vm.moveSelectionUp()
        #expect(vm.selectedIndex == 0)

        vm.moveSelectionDown()
        #expect(vm.selectedIndex == 1)

        vm.moveSelectionDown()
        #expect(vm.selectedIndex == 1)
    }

    @Test func selectionIsClampedWhenResultsShrink() {
        let vm = makeViewModel(customPaths: [Self.textEdit, Self.calculator])
        vm.selectedIndex = 1

        UserDefaults.standard.set(try? JSONEncoder().encode([Self.textEdit]), forKey: "CustomAppPaths")
        vm.refreshApps()

        #expect(vm.results.count == 1)
        #expect(vm.selectedIndex == 0)
    }

    @Test func resetSearchClearsQuery() {
        let vm = makeViewModel()
        vm.searchText = "calc"
        vm.resetSearch()
        #expect(vm.searchText.isEmpty)
    }

    @Test func finderCanNeverBeQuit() {
        let vm = makeViewModel()
        let finder = AppItem(name: "Finder", path: Self.finder, bundleIdentifier: "com.apple.finder")
        #expect(vm.canQuit(app: finder) == false)
        #expect(vm.quit(app: finder) == false)
    }

    @Test func statusLookupsUseBundleIdentifier() {
        let vm = makeViewModel()
        let calc = AppItem(name: "Calculator", path: Self.calculator, bundleIdentifier: Self.calculatorID)
        let noBundle = AppItem(name: "X", path: "/X.app", bundleIdentifier: nil)

        vm.runningBundleIds = [Self.calculatorID]
        vm.audioPlayingBundleIds = [Self.calculatorID]

        #expect(vm.isRunning(app: calc))
        #expect(vm.isAudioPlaying(app: calc))
        #expect(vm.isRunning(app: noBundle) == false)
        #expect(vm.isAudioPlaying(app: noBundle) == false)
    }

    // MARK: - Tìm kiếm

    @Test func searchFindsInstalledAppByName() {
        let vm = makeViewModel()
        vm.searchText = "Calculator"
        vm.refreshApps()
        #expect(vm.results.contains { $0.name == "Calculator" })
    }

    @Test func searchIsCaseInsensitive() {
        let vm = makeViewModel()
        vm.searchText = "calculator"
        vm.refreshApps()
        #expect(vm.results.contains { $0.name == "Calculator" })
    }

    @Test func searchWithNoMatchReturnsNothing() {
        let vm = makeViewModel()
        vm.searchText = "zzqqxxjjvvkkww"
        vm.refreshApps()
        #expect(vm.results.isEmpty)
        #expect(vm.selectedIndex == 0)
    }

    @Test func searchPrefersMoreUsedAppAmongEqualMatches() {
        let vm = makeViewModel(usage: [Self.textEditID: 50])
        vm.searchText = "e"
        vm.refreshApps()
        let paths = vm.results.map(\.path)
        let textEditIndex = paths.firstIndex(of: Self.textEdit)
        let calculatorIndex = paths.firstIndex(of: Self.calculator)
        if let textEditIndex, let calculatorIndex {
            #expect(textEditIndex < calculatorIndex)
        }
    }

    // MARK: - Làm mới khi cài đặt đổi

    @Test func settingsChangeIsPickedUpAfterDebounce() async throws {
        let vm = makeViewModel()
        UserDefaults.standard.set("Rectangular", forKey: "CardStyle")
        try await Task.sleep(for: .milliseconds(500))
        #expect(vm.cardStyle == .rectangular)
    }

    @Test func burstOfSettingsChangesEndsWithLatestValue() async throws {
        let vm = makeViewModel()
        for value in stride(from: 40.0, through: 80.0, by: 10.0) {
            UserDefaults.standard.set(value, forKey: "WedgeInnerRadius")
        }
        try await Task.sleep(for: .milliseconds(500))
        #expect(vm.wedgeInnerRadius == 80)
    }
}
}
