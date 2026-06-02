# Gõ tiếng Việt qua ADBKeyBoard (D5)

`adb/rish input text` **không gõ được Unicode/tiếng Việt**. Giải pháp chuẩn: cài **ADBKeyBoard** — một bàn phím (IME) nhận text qua broadcast. `device_tools.input_text()` gửi `am broadcast -a ADB_INPUT_B64 --es msg <base64>` → ADBKeyBoard gõ ra (xử lý cả ASCII lẫn tiếng Việt, tránh lỗi quoting qua `rish`).

## Cài

1. Tải APK: https://github.com/senzhk/ADBKeyBoard (Releases → `ADBKeyboard.apk`), cài (như Shizuku: cho phép cài từ nguồn này).
2. Đặt làm IME (qua `rish`, không cần root):
   ```bash
   rish -c 'ime enable com.android.adbkeyboard/.AdbIME'
   rish -c 'ime set com.android.adbkeyboard/.AdbIME'
   rish -c 'ime list -s'          # xác nhận AdbIME đang active
   ```
3. Test:
   ```bash
   # mở 1 ô nhập (vd thanh tìm kiếm), rồi:
   rish -c "am broadcast -a ADB_INPUT_B64 --es msg $(printf 'Xin chào Việt Nam' | base64)"
   ```
   Chữ "Xin chào Việt Nam" hiện ra ô đang focus → OK.

## Lưu ý
- Khi ADBKeyBoard là IME, **bàn phím cảm ứng không hiện phím** (nó là bàn phím "ảo cho automation"). Muốn gõ tay lại: đổi IME về bàn phím thường — `rish -c 'ime set <ime_thường>'` (lấy id bằng `rish -c 'ime list -s'`), hoặc chọn trong Settings → Languages & input.
- `am broadcast` luôn báo `result=0` kể cả khi ADBKeyBoard chưa active → nếu `input_text` "thành công" mà chữ không hiện thì IME chưa đúng.
- Agent gọi `input_text` chỉ chạy khi `write_enabled: true` trong `~/.hermes/device-policy.yaml`.

## Nguồn
- ADBKeyBoard: https://github.com/senzhk/ADBKeyBoard
