## VoiceEverywhere (macOS menubar)

Nhập văn bản bằng giọng nói vào bất kỳ ô input nào trên macOS. Ứng dụng menubar, hotkey toàn cục, dùng Soniox realtime streaming.

### Yêu cầu
- macOS 13+ với Xcode CLT đã cài (chỉ cần CLI, không mở Xcode GUI).
- Biến môi trường `SONIOX_API_KEY` (Soniox dashboard → API keys).
- Quyền Microphone và Accessibility cho ứng dụng.

### Cách build & chạy (không mở Xcode)
```bash
cd /Users/phuhung/Documents/Studies/voice-everywhere
export SONIOX_API_KEY="...your api key..."   # nếu chạy từ terminal
./scripts/build_app.sh            # hoặc ./scripts/build_app.sh debug
open dist/VoiceEverywhere.app
```
Hoặc lưu key vào file `~/.voiceeverywhere_api_key` (một dòng chứa key) để khi mở app từ Finder vẫn nhận được.

### Sử dụng
- Biểu tượng mic sẽ xuất hiện trên menubar.
- Hotkey mặc định: `Ctrl + Option + Space` (⌃⌥Space) để bật/tắt ghi âm.
- Khi ghi âm, text sẽ được Soniox nhận dạng real-time và **tự gõ** vào ô đang focus.
- Không lưu lịch sử transcript (có thể bổ sung sau).

### Quyền truy cập cần cấp
- **Microphone**: lần đầu sẽ hiện prompt; nếu lỡ từ chối, vào System Settings → Privacy & Security → Microphone.
- **Accessibility** (để gõ phím): mở menu → “Request Accessibility Access…” hoặc System Settings → Privacy & Security → Accessibility, bật cho VoiceEverywhere.

### Thay đổi hotkey
- Sửa giá trị mặc định trong `Sources/HotKeyManager.swift` (`keyCode`/`modifiers`), sau đó build lại.

### Mặc định nhận dạng
- Model: `stt-rt-v3`, audio `pcm_s16le`, 16kHz, mono.
- `language_hints`: `["vi", "en"]` và bật `enable_language_identification`.

### Thư mục tạo thêm
- `.build/` (SwiftPM), `dist/VoiceEverywhere.app` (bundle thành phẩm).
