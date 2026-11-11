# VTuTRADE iOS (DEMO ONLY)

SwiftUI iPhone dashboard for the user's Oracle Cloud VTuTRADE management API.

## Features
- Read-only dashboard: engine status, recorded profit/win rate, EMA9/EMA21/RSI14, 20 recent settlements.
- Authenticated `GET /status` and pause-only `POST /pause`.
- **No resume operation, no order placement, no trading credentials on device.**
- HTTPS only. API bearer token stored in iOS Keychain; URL stored in UserDefaults.
- Refresh every 10 seconds while app is open; manual refresh.

## Build
1. Install Xcode and XcodeGen (`brew install xcodegen`) on macOS.
2. Run `xcodegen generate` in this folder, open `VTuTRADE.xcodeproj`.
3. Select your Apple Development Team in Signing & Capabilities; change the bundle identifier if needed.
4. Build on a device. TestFlight requires App Store Connect signing/distribution configuration.

## Connect securely
The existing API binds to `127.0.0.1:8766` on the VM. **Do not open port 8766 to the internet.**
Provision an authenticated HTTPS reverse proxy/private tunnel that reaches `http://127.0.0.1:8766` on the VM, with access limited to your device/account. Then enter its `https://...` URL and the `.api_token` value in the app settings. Never commit `.api_token` or `.env` to Git.

## Important
- The server's `/resume` is locked; this app deliberately has no resume button.
- Recorded profit reflects only settlements present in the JSONL file, not a verified full broker balance.
- API client rejects non-DEMO responses.
- Native build and network integration have **not** been verified in this environment.
