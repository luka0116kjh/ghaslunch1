# Firebase iOS Push Checklist

## Xcode

- Firebase Console에서 iOS 앱 `com.ghas.lunch`를 등록한다.
- 내려받은 `GoogleService-Info.plist`를 `ghaslunch/ghaslunch/` 폴더에 추가한다.
- Xcode에서 `GoogleService-Info.plist`가 `GHAS Lunch` app target membership에 포함됐는지 확인한다.
- Signing & Capabilities에서 Team을 설정한다.
- Push Notifications capability가 켜져 있는지 확인한다.
- Background Modes의 Remote notifications가 켜져 있는지 확인한다.
- 실기기 Debug 빌드로 실행한다. Simulator만으로 APNs/FCM 수신을 최종 검증하지 않는다.

## Firebase Console

- Project `ghaslunch1`에 iOS 앱 Bundle ID `com.ghas.lunch`를 추가한다.
- Cloud Messaging 설정에서 APNs Auth Key 또는 APNs 인증서를 등록한다.
- Realtime Database rules를 배포한다.
- `tokens/{sha256(fcmToken)}` 쓰기가 허용되는지 rules simulator 또는 실기기 로그로 확인한다.

## Device Test

- 앱을 새로 설치한 뒤 알림 버튼을 누른다.
- iOS 권한 팝업에서 허용을 선택한다.
- Xcode console에서 APNs 등록 실패 로그가 없는지 확인한다.
- Firebase Messaging delegate가 FCM token을 수신하는지 확인한다.
- Realtime Database에 `tokens/{64 hex hash}` 문서가 생기는지 확인한다.
- 저장 필드가 `lastUpdated` number, `platform: "ios"`인지 확인한다.
- Firebase Console 또는 Admin SDK로 topic `meal`에 테스트 메시지를 보낸다.
- 앱 foreground 상태에서 banner/sound/badge 표시를 확인한다.
- 앱 background/terminated 상태에서 알림 수신을 확인한다.
- 앱에서 알림을 끈 뒤 topic unsubscribe와 token hash 삭제 시도가 동작하는지 확인한다.
- iOS 설정에서 알림 권한을 거부한 상태로 앱을 다시 열어 UI가 거부 상태를 표시하는지 확인한다.

## Database Rule Match

Current write body:

```json
{
  "lastUpdated": 1778750000000,
  "platform": "ios"
}
```

Current path:

```text
tokens/{sha256(fcmToken)}.json
```

The current `database.rules.json` allows 64-character lowercase hex token IDs and `platform` values of either `web` or `ios`, so it matches the iOS implementation.
