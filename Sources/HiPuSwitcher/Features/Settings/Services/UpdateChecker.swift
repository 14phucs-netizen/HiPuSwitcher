import Foundation
import AppKit

struct UpdateReleaseInfo: Equatable {
    let version: String
    let downloadURL: URL
    let releaseNotes: String?
}

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case upToDate(currentVersion: String)
    case updateAvailable(UpdateReleaseInfo)
    case notConfigured
    case failed(String)
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published private(set) var state: UpdateCheckState = .idle
    @Published var autoCheckEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoCheckEnabled, forKey: Self.autoCheckKey)
        }
    }

    private static let autoCheckKey = "AutoCheckForUpdates"
    private static let lastCheckKey = "LastUpdateCheckDate"
    private static let autoCheckInterval: TimeInterval = 24 * 60 * 60

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 12
            config.timeoutIntervalForResource = 20
            self.session = URLSession(configuration: config)
        }

        if UserDefaults.standard.object(forKey: Self.autoCheckKey) == nil {
            self.autoCheckEnabled = true
        } else {
            self.autoCheckEnabled = UserDefaults.standard.bool(forKey: Self.autoCheckKey)
        }
    }

    var isConfigured: Bool {
        AppInfo.updateManifestURL != nil || (AppInfo.githubRepo?.isEmpty == false)
    }

    /// Silent background check on launch (at most once every 24h).
    func checkSilentlyIfNeeded() {
        guard autoCheckEnabled, isConfigured else { return }
        if let lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date,
           Date().timeIntervalSince(lastCheck) < Self.autoCheckInterval {
            return
        }
        Task {
            await performCheck(manual: false)
        }
    }

    /// Manual check triggered by the user from Settings or Menu Bar.
    func checkForUpdates() {
        Task {
            await performCheck(manual: true)
        }
    }

    func openDownload(_ release: UpdateReleaseInfo) {
        guard release.downloadURL.scheme?.lowercased() == "https" else { return }
        NSWorkspace.shared.open(release.downloadURL)
    }

    private func performCheck(manual: Bool) async {
        guard isConfigured else {
            if manual {
                state = .notConfigured
            }
            return
        }

        state = .checking
        let currentVersion = AppInfo.version

        // 1. Prefer custom JSON manifest if configured; fall back to GitHub Releases if available.
        var lastError: Error?
        var fetchedRelease: UpdateReleaseInfo?

        if let manifestURL = AppInfo.updateManifestURL,
           manifestURL.scheme?.lowercased() == "https" {
            do {
                fetchedRelease = try await fetchFromCustomManifest(url: manifestURL)
            } catch {
                lastError = error
            }
        }

        if fetchedRelease == nil,
           let repo = AppInfo.githubRepo?.trimmingCharacters(in: .whitespacesAndNewlines),
           !repo.isEmpty {
            do {
                fetchedRelease = try await fetchFromGitHubReleases(repo: repo)
            } catch {
                lastError = error
            }
        }

        if let release = fetchedRelease {
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
            if Self.isNewerVersion(release.version, than: currentVersion) {
                state = .updateAvailable(release)
            } else {
                state = .upToDate(currentVersion: currentVersion)
            }
        } else if manual {
            let msg = lastError?.localizedDescription ?? ""
            state = .failed(msg)
        } else {
            state = .idle
        }
    }

    // MARK: - Fetchers

    private func fetchFromCustomManifest(url: URL) async throws -> UpdateReleaseInfo {
        var request = URLRequest(url: url)
        request.setValue("HiPuSwitcher/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let parsed = Self.parseCustomManifest(data: data) else {
            throw URLError(.cannotParseResponse)
        }
        return parsed
    }

    private func fetchFromGitHubReleases(repo: String) async throws -> UpdateReleaseInfo {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("HiPuSwitcher/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let parsed = Self.parseGitHubRelease(data: data) else {
            throw URLError(.cannotParseResponse)
        }
        return parsed
    }

    // MARK: - Parsers (nonisolated for easy unit testing)

    private struct CustomManifestDTO: Decodable {
        let version: String
        let downloadURL: String
        let releaseNotes: String?
    }

    private struct GitHubReleaseDTO: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
        let tag_name: String
        let html_url: String
        let body: String?
        let assets: [Asset]?
    }

    nonisolated static func parseCustomManifest(data: Data) -> UpdateReleaseInfo? {
        guard let dto = try? JSONDecoder().decode(CustomManifestDTO.self, from: data),
              let url = URL(string: dto.downloadURL),
              url.scheme?.lowercased() == "https" else {
            return nil
        }
        let cleanVersion = normalizeVersion(dto.version)
        guard !cleanVersion.isEmpty else { return nil }
        return UpdateReleaseInfo(
            version: cleanVersion,
            downloadURL: url,
            releaseNotes: dto.releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    nonisolated static func parseGitHubRelease(data: Data) -> UpdateReleaseInfo? {
        guard let dto = try? JSONDecoder().decode(GitHubReleaseDTO.self, from: data) else {
            return nil
        }
        let cleanVersion = normalizeVersion(dto.tag_name)
        guard !cleanVersion.isEmpty else { return nil }

        // Prefer a .dmg asset if uploaded, otherwise fall back to the release page URL
        let dmgURL = dto.assets?
            .first { $0.name.lowercased().hasSuffix(".dmg") }
            .flatMap { URL(string: $0.browser_download_url) }
            .flatMap { $0.scheme?.lowercased() == "https" ? $0 : nil }

        let fallbackURL = URL(string: dto.html_url)
            .flatMap { $0.scheme?.lowercased() == "https" ? $0 : nil }

        guard let targetURL = dmgURL ?? fallbackURL else { return nil }

        return UpdateReleaseInfo(
            version: cleanVersion,
            downloadURL: targetURL,
            releaseNotes: dto.body?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - SemVer Comparison

    nonisolated static func normalizeVersion(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") {
            s.removeFirst()
        }
        return s
    }

    nonisolated static func isNewerVersion(_ remote: String, than local: String) -> Bool {
        let rParts = normalizeVersion(remote)
            .split(separator: ".")
            .map { Int($0.prefix { $0.isNumber }) ?? 0 }
        let lParts = normalizeVersion(local)
            .split(separator: ".")
            .map { Int($0.prefix { $0.isNumber }) ?? 0 }

        let count = max(rParts.count, lParts.count)
        for i in 0..<count {
            let r = i < rParts.count ? rParts[i] : 0
            let l = i < lParts.count ? lParts[i] : 0
            if r != l {
                return r > l
            }
        }
        return false
    }
}
