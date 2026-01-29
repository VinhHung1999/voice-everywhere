# VoiceEverywhere

Ứng dụng menubar trên macOS giúp nhập văn bản bằng giọng nói vào **bất kỳ ô input nào**. Nhấn hotkey, nói, text tự động được gõ vào nơi con trỏ đang focus. Hỗ trợ nhận dạng tiếng Việt và tiếng Anh realtime.

## Tính năng

- Nhận dạng giọng nói realtime qua Soniox API (model `stt-rt-v3`)
- Tự nhận biết tiếng Việt / tiếng Anh
- Gõ text trực tiếp vào app đang focus (không cần copy-paste)
- Hotkey toàn cục: `Ctrl + Option + Space` (⌃⌥Space)
- **LLM post-processing** qua xAI API — tự động chỉnh sửa, dịch, hoặc format text sau khi nhận dạng
- **Format Presets** — tạo và quản lý nhiều preset format instructions (ví dụ: "Formal English", "Casual Vietnamese"), chọn nhanh qua dropdown
- Cấu hình API key và context nhận dạng trong cửa sổ Settings
- Âm thanh phản hồi khi bật/tắt ghi âm
- Chạy trên menubar, không chiếm dock

## Yêu cầu

- macOS 13 trở lên
- Xcode Command Line Tools (`xcode-select --install`)
- API key từ [Soniox](https://soniox.com) (Dashboard → API keys)

## Cài đặt & Chạy

```bash
git clone git@github.com:VinhHung1999/voice-everywhere.git
cd voice-everywhere

# Build app bundle
./scripts/build_app.sh

# Mở app
open dist/VoiceEverywhere.app
```

Build debug:
```bash
./scripts/build_app.sh debug
```

## Cấu hình

Click vào icon mic trên menubar → **Settings** để mở cửa sổ cài đặt.

### Soniox (Speech-to-Text)

1. **Soniox API Key** — Nhập API key từ Soniox (bắt buộc)
2. **Context Terms** — Các từ/thuật ngữ đặc biệt cách nhau bằng dấu phẩy (ví dụ: `SwiftUI, Soniox, CoreML`) — giúp nhận dạng chính xác hơn
3. **General Context** — Mô tả ngữ cảnh chung (ví dụ: `Cuộc họp về iOS development`)

### LLM Post-Processing (xAI)

Bật **Enable LLM post-processing** để text sau khi nhận dạng được gửi qua xAI API xử lý thêm (chỉnh grammar, dịch, format...) trước khi gõ ra.

4. **xAI API Key** — API key từ xAI
5. **Model** — Model sử dụng (mặc định: `grok-3-mini-fast`)
6. **Output Language** — Ngôn ngữ đầu ra: English, Vietnamese, hoặc "As spoken (no LLM)" để tắt
7. **Format Preset** — Chọn preset chứa format instructions cho LLM. Dùng các nút:
   - **+** — Tạo preset mới (nhập tên + instructions)
   - **−** — Xóa preset đang chọn
   - **Edit** — Sửa nội dung preset đang chọn
   - Chọn **(None)** để không dùng format instructions

Nhấn **Save** để lưu. Cấu hình được giữ lại giữa các lần mở app.

## Sử dụng

1. Click icon **mic** trên menubar hoặc nhấn `Ctrl + Option + Space` để bắt đầu ghi âm
2. Nói — text được nhận dạng realtime và tự động gõ vào nơi con trỏ đang focus
3. Nhấn lại `Ctrl + Option + Space` để dừng

**Trạng thái icon menubar:**
| Icon | Trạng thái |
|------|-----------|
| 🎤 `mic` | Sẵn sàng (idle) |
| 🎤 `mic.fill` | Đang ghi âm |
| 🎤 `mic.badge.xmark` | Đang kết nối / Lỗi |

## Quyền truy cập cần cấp

App sẽ hỏi quyền khi chạy lần đầu:

1. **Microphone** — cho phép khi được hỏi. Nếu lỡ từ chối: System Settings → Privacy & Security → Microphone
2. **Accessibility** — cần để app gõ phím vào ứng dụng khác. Vào System Settings → Privacy & Security → Accessibility → bật VoiceEverywhere

## Thay đổi hotkey

Sửa `keyCode` và `modifiers` trong `Sources/HotKeyManager.swift`, rồi build lại.

## Chi tiết kỹ thuật

- **Ngôn ngữ:** Swift (SwiftPM, không cần Xcode GUI)
- **Soniox model:** `stt-rt-v3`, WebSocket streaming
- **LLM:** xAI API (`grok-3-mini-fast` mặc định), tùy chọn post-processing
- **Audio:** PCM signed 16-bit LE, 16kHz, mono
- **Language hints:** `["vi", "en"]` với auto language identification
- **Log file:** `~/Library/Logs/VoiceEverywhere.log`

## License

MIT
