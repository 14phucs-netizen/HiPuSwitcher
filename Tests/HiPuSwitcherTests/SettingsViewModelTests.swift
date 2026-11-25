import Testing
import Foundation
@testable import HiPuSwitcher

/// Các test dùng chung `UserDefaults.standard` nên phải chạy tuần tự và dọn key trước mỗi test.
extension DefaultsBackedTests {
@Suite
struct SettingsViewModelTests {
    private static let keys = [
        "CustomAppPaths", "UseCustomList", "CardStyle", "ShowAppName", "EnableHoverZoom",
        "StartAngle", "CardOpacity", "GlassTheme", "BackgroundStyle", "SavedPresets",
        "WedgeSpacing", "WedgeInnerRadius", "WedgeOuterRadius", "WedgeCornerRadius",
        "WedgeIconSize", "FanOverlap", "RectSpacing", "RectArcRadius", "RectCardWidth",
        "RectCardHeightMultiplier", "RectCornerRadius", "RectIconSize",
        "HideInactiveApps", "EnableMiddleClickTrigger", "DoubleTapMode",
    ]
    private static let builtInPresetIDs = [
        "default_non_background",
        "default_blur_fan",
        "default_blur_rectangle",
        "default_liquid_glass",
    ]

    private func makeViewModel() -> SettingsViewModel {
        for key in Self.keys { UserDefaults.standard.removeObject(forKey: key) }
        return SettingsViewModel()
    }

    @Test func freshStateUsesDefaults() {
        let vm = makeViewModel()
        #expect(vm.cardStyle == .wedge)
        #expect(vm.showAppName)
        #expect(vm.enableHoverZoom)
        #expect(vm.useCustomList == false)
        #expect(vm.hideInactiveApps == false)
        #expect(vm.doubleTapMode == .none)
        #expect(vm.wedgeInnerRadius == 100)
        #expect(vm.wedgeOuterRadius == 210)
        #expect(vm.rectCardWidth == 88)
        #expect(vm.backgroundStyle == .glassDark)
        #expect(vm.customAppPaths.isEmpty)
    }

    @Test func changedValuesPersistAcrossInstances() {
        let vm = makeViewModel()
        vm.wedgeInnerRadius = 55
        vm.showAppName = false
        vm.cardStyle = .rectangular
        vm.doubleTapMode = .doubleShift

        let reloaded = SettingsViewModel()
        #expect(reloaded.wedgeInnerRadius == 55)
        #expect(reloaded.showAppName == false)
        #expect(reloaded.cardStyle == .rectangular)
        #expect(reloaded.doubleTapMode == .doubleShift)
    }

    @Test func backgroundStyleKeepsGlassThemeInSync() {
        let vm = makeViewModel()
        vm.backgroundStyle = .glassLight
        #expect(vm.glassTheme == .light)
        vm.backgroundStyle = .solidDark
        #expect(vm.glassTheme == .dark)
    }

    @Test func defaultPresetsAreSeeded() {
        let vm = makeViewModel()
        #expect(Set(vm.presets.map(\.id)) == Set(Self.builtInPresetIDs))
    }

    @Test func savingPresetCapturesCurrentValuesAndClearsName() {
        let vm = makeViewModel()
        vm.wedgeOuterRadius = 250
        vm.startAngle = -45
        vm.saveCurrentAsPreset(name: "Của tôi")

        let saved = vm.presets.last
        #expect(saved?.name == "Của tôi")
        #expect(saved?.wedgeOuterRadius == 250)
        #expect(saved?.startAngle == -45)
        #expect(vm.newPresetName.isEmpty)
        #expect(vm.presets.count == Self.builtInPresetIDs.count + 1)
    }

    @Test func savingPresetWithBlankNameIsIgnored() {
        let vm = makeViewModel()
        vm.saveCurrentAsPreset(name: "   ")
        #expect(vm.presets.count == Self.builtInPresetIDs.count)
    }

    @Test func applyingPresetUpdatesSettings() throws {
        let vm = makeViewModel()
        let blurRect = try #require(vm.presets.first { $0.id == "default_blur_rectangle" })
        vm.applyPreset(blurRect)

        #expect(vm.cardStyle == .rectangular)
        #expect(vm.rectCardWidth == 90)
        #expect(vm.glassMode == .blur)
        #expect(vm.showCardBorder == true)
    }

    @Test func builtInPresetsCannotBeDeleted() throws {
        let vm = makeViewModel()
        for id in Self.builtInPresetIDs {
            let preset = try #require(vm.presets.first { $0.id == id })
            vm.deletePreset(preset)
        }
        #expect(vm.presets.count == Self.builtInPresetIDs.count)
    }

    @Test func customPresetCanBeDeleted() throws {
        let vm = makeViewModel()
        vm.saveCurrentAsPreset(name: "Tạm")
        let custom = try #require(vm.presets.last)
        vm.deletePreset(custom)
        #expect(vm.presets.contains { $0.id == custom.id } == false)
    }

    @Test func movingAppsReordersAndPersists() {
        let vm = makeViewModel()
        vm.customAppPaths = ["/A.app", "/B.app", "/C.app"]
        vm.moveApps(from: IndexSet(integer: 0), to: 3)
        #expect(vm.customAppPaths == ["/B.app", "/C.app", "/A.app"])

        #expect(SettingsViewModel().customAppPaths == ["/B.app", "/C.app", "/A.app"])
    }

    @Test func resetRestoresDefaultsInMemory() {
        let vm = makeViewModel()
        vm.cardStyle = .rectangular
        vm.wedgeInnerRadius = 20
        vm.hideInactiveApps = true
        vm.doubleTapMode = .doubleCmd
        vm.customAppPaths = ["/A.app"]

        vm.resetToDefaults()

        #expect(vm.cardStyle == .wedge)
        #expect(vm.wedgeInnerRadius == 100)
        #expect(vm.hideInactiveApps == false)
        #expect(vm.doubleTapMode == .none)
        #expect(vm.customAppPaths.isEmpty)
    }

    @Test func addAppsSkipsDuplicatesAndNonAppFiles() {
        let vm = makeViewModel()
        vm.customAppPaths = ["/System/Applications/Calculator.app"]
        vm.addApps(at: [
            URL(fileURLWithPath: "/System/Applications/Calculator.app"),
            URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
            URL(fileURLWithPath: "/tmp/notes.txt"),
        ])
        #expect(vm.customAppPaths == [
            "/System/Applications/Calculator.app",
            "/System/Applications/TextEdit.app",
        ])
    }

    @Test func addAppsWorksEvenWhenCustomListIsDisabled() {
        let vm = makeViewModel()
        #expect(vm.useCustomList == false)
        vm.addApps(at: [URL(fileURLWithPath: "/System/Applications/Calculator.app")])
        #expect(vm.customAppPaths.count == 1)
    }
}
}
