# VTuTRADE iOS プッシュ通知（第1段階）

この版は iPhone 側の APNs 登録とサーバーへのトークン送信を追加します。
**通知送信機能は未完成です。** Oracle Cloud の `/push/register` API と APNs 送信処理が必要です。

## Apple Developer / TestFlight
1. Identifiers で `com.miyukidesign.vtutrade` の Push Notifications を有効化。
2. App Store 配布用 provisioning profile を再生成し、GitHub Secret `IOS_APPSTORE_PROFILE_BASE64` を更新。
3. Apple Developer の Keys で APNs Auth Key (.p8) を発行し、Key ID / Team ID を安全に保存。秘密鍵を GitHub にコミットしない。
4. `testflight.yml` を再実行。プロファイルが Push entitlement に対応していないと署名が失敗します。

## サーバーに必要なもの
- HTTPS Bearer 認証付き `POST /push/register`
  JSON: `{"device_token":"<hex>","platform":"ios","environment":"production"}`
- 認証済み利用者に紐づけたトークン保存、ログでのトークン秘匿、トークン失効時の削除。
- APNs HTTP/2 への署名付き送信 (`apns-topic: com.miyukidesign.vtutrade`、production)。
- 注文、決済、安全停止、障害、営業日開始のイベントを通知キューへ投入し、trade_id + eventで重複防止。
- 通知エラーは注文・決済処理へ伝播させない。APNs送信失敗時の再試行と監視を実装。
- 実際のイベント名称・保存ファイル・API認証方式は Oracle Cloud の現行コードを確認してから実装。

## 注意
- iPhoneアプリを起動すると通知許可ダイアログが出ます。
- APIに `/push/register` が無い段階では登録が失敗しますが、取引機能はそのままです。
- APNs の production 環境は TestFlight でも利用します。
- 通知をタップするとアプリが開きます。特定画面への遷移は未実装です。
