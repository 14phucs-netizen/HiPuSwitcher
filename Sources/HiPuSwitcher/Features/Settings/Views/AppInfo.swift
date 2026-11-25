import Foundation

/// Thông tin thương mại của app, hiển thị trong Cài đặt → Giới thiệu.
/// Điền các giá trị `nil` trước khi phát hành; mục nào còn `nil` sẽ tự ẩn khỏi giao diện.
enum AppInfo {
    static let name = "HiPu Switcher"
    static let developer = "PhucVang"
    static let copyright = "© 2026 PhucVang. Bảo lưu mọi quyền."

    // Cấu hình nguồn kiểm tra cập nhật (hỗ trợ cả 2: ưu tiên updateManifestURL, dự phòng githubRepo):
    // 1. GitHub Releases: điền dạng "owner/repo", ví dụ: "14phucs-netizen/HiPuSwitcher"
    static let githubRepo: String? = "14phucs-netizen/HiPuSwitcher"
    // 2. File JSON riêng: URL HTTPS tới latest.json có dạng {"version":"1.1.0","downloadURL":"https://.../HiPuSwitcher-1.1.0.dmg","releaseNotes":"..."}
    static let updateManifestURL: URL? = URL(string: "https://raw.githubusercontent.com/14phucs-netizen/HiPuSwitcher/main/latest.json")

    // TODO(phát hành): điền thông tin thật.
    static let websiteURL: URL? = URL(string: "https://github.com/14phucs-netizen/HiPuSwitcher")
    static let supportEmail: String? = nil                  // ví dụ "support@hipu.app"
    static let privacyPolicyURL: URL? = nil                 // bắt buộc khi đưa lên App Store
    static let termsURL: URL? = nil
    static let reviewURL: URL? = nil                        // liên kết trang App Store để đánh giá

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var build: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    static var versionDisplay: String {
        build.map { "\(version) (\($0))" } ?? version
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "—"
    }

    static var systemSummary: String {
        #if arch(arm64)
        let arch = "Apple Silicon"
        #else
        let arch = "Intel"
        #endif
        return "macOS \(ProcessInfo.processInfo.operatingSystemVersionString) · \(arch)"
    }

    /// Nội dung người dùng có thể gửi kèm khi liên hệ hỗ trợ.
    static var supportReport: String {
        """
        \(name) \(versionDisplay)
        Bundle: \(bundleIdentifier)
        \(systemSummary)
        """
    }

    static var supportMailURL: URL? {
        guard let email = supportEmail else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "[\(name) \(version)] Hỗ trợ"),
            URLQueryItem(name: "body", value: "\n\n---\n\(supportReport)"),
        ]
        return components.url
    }

    struct OpenSourceNotice: Identifiable {
        let id: String
        let name: String
        let author: String
        let license: String
        let url: URL
    }

    static let openSourceNotices: [OpenSourceNotice] = [
        .init(id: "KeyboardShortcuts", name: "KeyboardShortcuts", author: "Sindre Sorhus",
              license: "MIT", url: URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!),
        .init(id: "Fuse", name: "Fuse (fuse-swift)", author: "Kirollos Risk",
              license: "MIT", url: URL(string: "https://github.com/krisk/fuse-swift")!),
    ]
}
