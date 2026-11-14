# VTuTRADE iOS — EXP-007 (DEMO ONLY)

SwiftUI iPhone dashboard for the Oracle Cloud VTuTRADE management API.

## Features
- EXP-007 dashboard: recorded profit and win rate for EXP-007 settlements, USD/JPY, 5-minute / 15-second changes, and HIGH price-condition indication.
- EXP-007 selected by default in experiment history; past EXP-006 and EMA/RSI experiment results remain available.
- Authenticated `GET /status`, `GET /history`, `POST /pause` and `POST /resume` (only when server confirms `can_resume`).
- HTTPS only. API bearer token stored in iOS Keychain; URL stored in UserDefaults.
- Refresh every 10 seconds while app is open; manual refresh.

## Server-side safety (EXP-007)
- The bot (not the iPhone app) enforces +19,000 JPY daily profit target and -20,000 JPY daily loss limit, with no 3-loss streak stop.
- These numbers are **server configuration**, not client-enforced limits. Changing this app does not change server logic.
- Dashboard EXP-007 settled-trade totals are **not** the same as safety-control daily totals, which can include earlier experiments on the same day.
- Trading is DEMO only; there is no order placement or trading credential in the iPhone app.

## Build
1. Install Xcode and XcodeGen (`brew install xcodegen`) on macOS.
2. Run `xcodegen generate --spec project.yml` in this folder, open `VTuTRADE.xcodeproj`.
3. Select your Apple Development Team in Signing & Capabilities.
4. Build on a device, or use GitHub Actions **VTuTRADE iOS to TestFlight** for signing/distribution.
5. Confirm both GitHub upload logs and the build in App Store Connect/TestFlight.

## Connect securely
The management API binds to `127.0.0.1:8766` on the VM. **Do not open port 8766 to the internet.**
Use an authenticated HTTPS private reverse proxy/tunnel and enter its URL and API token in Settings. Never commit `.api_token` or `.env` to Git.

## Important
- Current app shows the same HIGH price conditions as EXP-006; the EXP-007 change is server-side daily safety limits, not a new trading signal.
- The `HIGH` condition display is informational and does **not** mean an order was placed.
- Historical trade data stays on the server and is never deleted by this app update.
