import Testing
import Foundation
@testable import HiPuSwitcher

@Suite
struct UpdateCheckerTests {
    @Test func semVerComparisonHandlesCommonCases() {
        #expect(UpdateChecker.isNewerVersion("1.0.1", than: "1.0.0"))
        #expect(UpdateChecker.isNewerVersion("v1.2.0", than: "1.1.9"))
        #expect(UpdateChecker.isNewerVersion("1.10.0", than: "1.2.0"))
        #expect(UpdateChecker.isNewerVersion("2.0", than: "1.9.9"))
        #expect(UpdateChecker.isNewerVersion("1.0.0", than: "1.0.0") == false)
        #expect(UpdateChecker.isNewerVersion("v1.0.0", than: "1.0.0") == false)
        #expect(UpdateChecker.isNewerVersion("0.9.9", than: "1.0.0") == false)
    }

    @Test func parsesCustomJSONManifest() {
        let json = """
        {
            "version": "v1.2.0",
            "downloadURL": "https://example.com/HiPuSwitcher-1.2.0.dmg",
            "releaseNotes": "Sửa lỗi và cải thiện hiệu năng."
        }
        """.data(using: .utf8)!

        let info = UpdateChecker.parseCustomManifest(data: json)
        #expect(info?.version == "1.2.0")
        #expect(info?.downloadURL.absoluteString == "https://example.com/HiPuSwitcher-1.2.0.dmg")
        #expect(info?.releaseNotes == "Sửa lỗi và cải thiện hiệu năng.")
    }

    @Test func rejectsNonHTTPSDownloadURL() {
        let insecure = """
        {
            "version": "2.0.0",
            "downloadURL": "http://example.com/HiPuSwitcher.dmg"
        }
        """.data(using: .utf8)!
        #expect(UpdateChecker.parseCustomManifest(data: insecure) == nil)
    }

    @Test func parsesGitHubReleasePreferringDMGAsset() {
        let json = """
        {
            "tag_name": "v1.3.0",
            "html_url": "https://github.com/PhucVang/HiPuSwitcher/releases/tag/v1.3.0",
            "body": "Hỗ trợ kiểm tra cập nhật tự động.",
            "assets": [
                {
                    "name": "checksums.txt",
                    "browser_download_url": "https://github.com/PhucVang/HiPuSwitcher/releases/download/v1.3.0/checksums.txt"
                },
                {
                    "name": "HiPuSwitcher-1.3.0.dmg",
                    "browser_download_url": "https://github.com/PhucVang/HiPuSwitcher/releases/download/v1.3.0/HiPuSwitcher-1.3.0.dmg"
                }
            ]
        }
        """.data(using: .utf8)!

        let info = UpdateChecker.parseGitHubRelease(data: json)
        #expect(info?.version == "1.3.0")
        #expect(info?.downloadURL.absoluteString == "https://github.com/PhucVang/HiPuSwitcher/releases/download/v1.3.0/HiPuSwitcher-1.3.0.dmg")
        #expect(info?.releaseNotes == "Hỗ trợ kiểm tra cập nhật tự động.")
    }
}
