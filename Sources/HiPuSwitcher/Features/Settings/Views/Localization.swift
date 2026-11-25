import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case vi = "vi"
    case en = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vi: return "Tiếng Việt"
        case .en: return "English"
        }
    }
}

final class L10n: ObservableObject {
    static let shared = L10n()

    private let key = "AppLanguage"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: key)
            NotificationCenter.default.post(name: Notification.Name("AppLanguageChanged"), object: nil)
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: key) ?? AppLanguage.vi.rawValue
        self.language = AppLanguage(rawValue: raw) ?? .vi
    }

    func t(_ vi: String, _ en: String) -> String {
        language == .vi ? vi : en
    }
}
