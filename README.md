<p align="center">
  <img src="docs/screenshots/hero-white.png" alt="HiPu Switcher" width="88%" />
</p>

<h1 align="center">HiPu Switcher</h1>

<p align="center">
  <strong>Chuyển đổi và mở nhanh ứng dụng trên macOS theo dạng cánh quạt &amp; thẻ nổi chuẩn Liquid Glass.</strong><br />
  Phát triển bởi <strong>PhucVang</strong> · Hỗ trợ macOS 14+ (tối ưu cho macOS 26/27 Liquid Glass)
</p>

<p align="center">
  <a href="https://14phucs-netizen.github.io/HiPuSwitcher/">
    <img src="https://img.shields.io/badge/Website-Trang%20chủ-0071e3?style=for-the-badge" alt="Website" />
  </a>
  <a href="https://github.com/14phucs-netizen/HiPuSwitcher/releases/latest">
    <img src="https://img.shields.io/github/v/release/14phucs-netizen/HiPuSwitcher?style=for-the-badge&color=1d1d1f&label=Tải%20về" alt="Latest Release" />
  </a>
  <img src="https://img.shields.io/badge/macOS-14%2B-86868b?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 14+" />
</p>

---

## Giao diện thực tế trên macOS

<p align="center">
  <img src="docs/screenshots/hero.jpg" alt="HiPu Switcher trên macOS" width="100%" />
</p>

---

## Đa phong cách hiển thị

Chuyển đổi tức thì giữa **Liquid Glass**, **Blur-Fan**, **Blur-Rectangle (Sáng / Tối)** và **Non-Background** — tuỳ chỉnh độ đục, viền thẻ, bán kính và lưu cấu hình riêng.

<table>
  <tr>
    <td align="center" width="33%">
      <img src="docs/screenshots/style-liquid-fan.png" alt="Liquid Glass Fan" width="100%" /><br />
      <strong>Liquid Glass Fan</strong>
    </td>
    <td align="center" width="33%">
      <img src="docs/screenshots/style-liquid-cards.png" alt="Liquid Glass Card" width="100%" /><br />
      <strong>Liquid Glass Card</strong>
    </td>
    <td align="center" width="33%">
      <img src="docs/screenshots/style-blur-fan.png" alt="Blur-Fan" width="100%" /><br />
      <strong>Blur-Fan</strong>
    </td>
  </tr>
  <tr>
    <td align="center" width="33%">
      <img src="docs/screenshots/style-rect-dark.png" alt="Blur Tối" width="100%" /><br />
      <strong>Blur Tối</strong>
    </td>
    <td align="center" width="33%">
      <img src="docs/screenshots/style-rect-light.png" alt="Blur Sáng" width="100%" /><br />
      <strong>Blur Sáng</strong>
    </td>
    <td align="center" width="33%">
      <img src="docs/screenshots/style-minimal.png" alt="Không nền" width="100%" /><br />
      <strong>Không nền</strong>
    </td>
  </tr>
</table>

---

## Tính năng chính

- **Kích hoạt mọi nơi:** `fn + ⇧`, nhấn đúp `⇧ / ⌥ / ⌘`, phím tắt tuỳ chỉnh hoặc chuột giữa.
- **Chuyển Space thông minh:** Tự động lướt sang đúng màn hình nền chứa ứng dụng; riêng **Finder** luôn mở *Tải về* ngay tại Space hiện tại.
- **Song ngữ Tiếng Việt / English:** Chuyển đổi tức thì không cần khởi động lại.
- **Siêu nhẹ & Tự cập nhật:** 100% Swift/SwiftUI gốc (`3.0 MB`), không tracking, tự kiểm tra bản mới qua GitHub Releases.

---

## Tải về & Cài đặt

Tải bản mới nhất tại [**Trang chủ**](https://14phucs-netizen.github.io/HiPuSwitcher/) hoặc [**Releases**](https://github.com/14phucs-netizen/HiPuSwitcher/releases/latest):

1. Mở file `.dmg` và kéo **HiPu Switcher** vào thư mục **Applications**.
2. Nếu macOS Gatekeeper hỏi ở lần mở đầu tiên, vào **Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Vẫn mở (Open Anyway)** đúng 1 lần.
3. Bấm **Cấp quyền** trên màn hình chào mừng và bật **HiPuSwitcher** trong mục **Trợ năng (Accessibility)**.

## Build từ mã nguồn

```bash
./build_app.sh
./build_dmg.sh
```
