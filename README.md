# HiPu Switcher

Ứng dụng chuyển đổi và mở nhanh ứng dụng trên macOS theo dạng vòng tròn quạt / thẻ chữ nhật, thiết kế chuẩn **macOS Liquid Glass**.

> Phát triển bởi **PhucVang**

## Tải về

Tải bản cài đặt mới nhất (`.dmg`) tại trang [**Releases**](https://github.com/14phucs-netizen/HiPuSwitcher/releases/latest):

1. Mở file `HiPuSwitcher-1.0.0.dmg`.
2. Kéo **HiPu Switcher** vào thư mục **Applications**.
3. Mở ứng dụng từ Applications và cấp quyền **Trợ năng (Accessibility)** ở màn hình thiết lập lần đầu.

> **Lưu ý khi mở lần đầu:** Nếu macOS hiển thị cảnh báo Gatekeeper, vào **Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Vẫn mở (Open Anyway)** đúng 1 lần duy nhất.

## Tính năng nổi bật

- **Giao diện Liquid Glass & Blur chuẩn macOS:** 4 cấu hình có sẵn (*Non-Background*, *Blur-Fan*, *Blur-Rectangle*, *Liquid glass*) và hỗ trợ lưu cấu hình riêng.
- **Kích hoạt linh hoạt:** Phím tắt tuỳ chỉnh, `fn + Shift`, nhấn đúp `⇧` / `⌥` / `⌘`, hoặc chuột giữa.
- **Chuyển Space thông minh:** Tự động chuyển sang đúng màn hình nền (Space) chứa ứng dụng; riêng **Finder** mở thẳng thư mục *Tải về* ngay tại Space hiện tại.
- **Song ngữ Tiếng Việt / English:** Chuyển đổi ngôn ngữ tức thì không cần khởi động lại.
- **Kiểm tra cập nhật:** Tự động kiểm tra bản mới qua GitHub Releases / `latest.json`.

## Build từ mã nguồn

Yêu cầu: macOS 14+ (khuyến nghị macOS 26/27 cho hiệu ứng Liquid Glass đầy đủ) và Xcode / Swift 5.9+.

```bash
./build_app.sh
./build_dmg.sh
```
