# GHAS Lunch iOS WebView

이 폴더는 GHAS 오늘의 급식 웹 배포본을 iOS `WKWebView`로 표시하는 소스입니다.

## 포함된 내용

- `ContentView.swift`: `https://ghaslunch1.web.app/`를 로드하는 `WKWebView` 화면
- Android 웹뷰와 같은 이름의 JS 브리지:
  - `window.GHASAndroidApp`
  - `window.GHASAndroidNotifications`
- 네이티브 처리:
  - 알림 권한 요청
  - 알림 해제 시 iOS 알림 요청/표시 정리
  - 테마 값을 `UserDefaults`에 저장하고 웹 `localStorage`에 재주입
  - 외부 링크는 Safari 등 시스템 앱으로 열기
  - 웹 `alert()`를 iOS 기본 알림창으로 표시
- 기존 SwiftUI 디자인 파일과 asset은 보존되어 있지만, 현재 앱 화면은 웹뷰가 기준입니다.

## Firebase/푸시 참고

현재 웹뷰 브리지는 iOS 알림 권한과 원격 알림 등록까지 연결합니다. 실제 FCM topic `meal` 구독까지 사용하려면 Apple Developer Program, APNs 키, `GoogleService-Info.plist`, Firebase iOS SDK, Push Notifications/Background Modes 설정이 추가로 필요합니다.
