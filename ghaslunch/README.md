# GHAS Lunch iOS

`GHAS알리미` iOS 앱은 Firebase Hosting에 배포된 웹 앱을 SwiftUI와 `WKWebView`로 감싼 래퍼 앱입니다.

## 기본 정보

- Xcode project: `ghaslunch.xcodeproj`
- App target: `ghaslunch`
- Bundle ID: `kr.hs.ghas.lunch`
- Deployment Target: iOS 16.0
- 앱 버전: `1.0`
- 빌드 번호: `1`
- WebView URL: `https://ghaslunch1.web.app/`
- 미검증 후보 URL: `https://ghaslunch.web.app/`
- Firebase 의존성: `FirebaseCore`

## 구조

```text
ghaslunch/
├── ghaslunchApp.swift          # FirebaseCore 초기화와 SwiftUI entry point
├── ContentView.swift           # WKWebView 래퍼, 네이티브 브리지, 테마 처리
├── GoogleService-Info.plist    # Firebase iOS 설정
└── Assets.xcassets             # 앱 아이콘과 색상 asset
```

## WebView 정책

앱 내부에서 허용하는 host:

- `ghaslunch1.web.app`
- `ghaslunch1.firebaseapp.com`

그 외 `https`와 `mailto` 링크는 외부 앱으로 열고, WebView 내부 이동은 취소합니다.

## 네이티브 브리지

iOS 앱은 웹 호환성을 위해 다음 객체를 주입합니다.

- `window.GHASAndroidApp`

지원 동작:

- `setTheme(theme)`: `light` 또는 `dark` 테마를 `UserDefaults`에 저장
- `getTheme()`: 저장된 테마 반환
- `requestNotifications()`: 현재는 비활성화 처리
- `cancelNotifications()`: 현재는 비활성화 처리

현재 iOS 알림은 임시 비활성화 상태입니다. 앱은 알림 권한을 요청하지 않고, FCM/APNs 토큰도 저장하지 않습니다.

## 테마 처리

`@AppStorage("theme")` 값을 기준으로 SwiftUI 배경색과 WebView 내부 테마 클래스를 맞춥니다.

- `light`: 라이트 모드 고정
- `dark`: 다크 모드 고정
- 미설정: 시스템 설정 사용

## iPad 레이아웃

iPad에서는 WebView 로드 후 CSS를 주입해 웹 앱의 `.container`, `.header`, `.meal-card` 폭과 여백을 보정합니다.

## 빌드 방법

1. Xcode에서 `ghaslunch.xcodeproj`를 엽니다.
2. `ghaslunch` scheme을 선택합니다.
3. 시뮬레이터 또는 실제 기기를 선택합니다.
4. Build/Run을 실행합니다.

## 테스트 체크리스트

- 앱 시작 시 `https://ghaslunch1.web.app/`이 정상 로드된다.
- 후보 URL `https://ghaslunch.web.app/`는 배포와 화면 렌더링 검증 전까지 운영 URL로 사용하지 않는다.
- 다크/라이트 테마 전환 후 앱 재실행에도 설정이 유지된다.
- iOS 알림 권한 팝업이 표시되지 않는다.
- 개인정보처리방침 링크가 열린다.
- 외부 `https` 또는 `mailto` 링크가 앱 밖에서 열린다.
- iPad에서 카드 폭과 여백이 깨지지 않는다.
