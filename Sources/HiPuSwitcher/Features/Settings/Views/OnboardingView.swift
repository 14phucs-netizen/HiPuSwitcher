import SwiftUI
import AppKit
import Combine
import HiPuShared

struct OnboardingView: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var launchAtLogin: Bool = LaunchAtLoginHelper.isEnabled
    @State private var isLaunchAtLoginSupported: Bool = LaunchAtLoginHelper.isSupported

    let onComplete: () -> Void

    private let pollTimer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: Language switcher
            HStack {
                Spacer()
                Picker("", selection: $l10n.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // Hero Header
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)

                Text(l10n.t("Chào mừng đến với HiPu Switcher", "Welcome to HiPu Switcher"))
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(l10n.t(
                    "Cấp quyền cần thiết một lần để sử dụng đầy đủ tính năng.",
                    "Grant the required permission once to unlock all features."
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.top, 6)
            .padding(.bottom, 18)

            // Permissions Checklist Card
            VStack(spacing: 0) {
                // 1. Accessibility (Required)
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill((isAccessibilityGranted ? Color.green : Color.blue).opacity(0.14))
                            .frame(width: 38, height: 38)
                        Image(systemName: isAccessibilityGranted ? "checkmark.shield.fill" : "hand.raised.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isAccessibilityGranted ? .green : .blue)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(l10n.t("Quyền Trợ năng", "Accessibility Permission"))
                                .font(.headline)
                            Text(l10n.t("Bắt buộc", "Required"))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill((isAccessibilityGranted ? Color.green : Color.orange).opacity(0.16))
                                )
                                .foregroundStyle(isAccessibilityGranted ? .green : .orange)
                        }
                        Text(l10n.t(
                            "Cần thiết để bật phím tắt toàn cục, fn + Shift, nhấn đúp phím và chuột giữa.",
                            "Required for global shortcuts, fn + Shift, double-tap keys, and middle click."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    if isAccessibilityGranted {
                        Label(l10n.t("Đã cấp", "Granted"), systemImage: "checkmark.circle.fill")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Button(l10n.t("Cấp quyền", "Grant")) {
                            requestAccessibility()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
                .padding(14)

                Divider()
                    .padding(.leading, 66)

                // 2. Launch at Login (Optional)
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "power")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(l10n.t("Khởi động cùng macOS", "Launch at Login"))
                                .font(.headline)
                            Text(l10n.t("Tuỳ chọn", "Optional"))
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.secondary.opacity(0.14)))
                                .foregroundStyle(.secondary)
                        }
                        Text(
                            isLaunchAtLoginSupported
                                ? l10n.t("Tự động chạy ngầm trên thanh menu khi bật máy.", "Automatically start in the menu bar on login.")
                                : l10n.t("Di chuyển app vào thư mục Ứng dụng để bật tính năng này.", "Move the app to Applications to enable this.")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!isLaunchAtLoginSupported)
                        .onChange(of: launchAtLogin) { _, newValue in
                            LaunchAtLoginHelper.setEnabled(newValue)
                        }
                }
                .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer(minLength: 16)

            // Footer CTA
            VStack(spacing: 8) {
                Button {
                    UserDefaults.standard.set(true, forKey: "HasCompletedOnboarding")
                    onComplete()
                } label: {
                    Text(l10n.t("Bắt đầu sử dụng", "Get Started"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isAccessibilityGranted)

                if !isAccessibilityGranted {
                    Text(l10n.t(
                        "Hãy bật HiPuSwitcher trong Cài đặt hệ thống → Trợ năng để tiếp tục.",
                        "Enable HiPuSwitcher in System Settings → Accessibility to continue."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 480, height: 420)
        .onReceive(pollTimer) { _ in
            let granted = AXIsProcessTrusted()
            if granted != isAccessibilityGranted {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAccessibilityGranted = granted
                }
                if granted {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
