# GHAS Lunch SwiftUI Starter

이 폴더는 웹 버전에서 최근 반영한 디자인과 개인정보처리방침 변경사항을 iOS SwiftUI 화면으로 옮긴 시작점입니다.

## 포함된 내용

- `GHASLunchApp.swift`: SwiftUI 앱 진입점과 테마 적용
- `AppTheme.swift`: 웹 `index.html`/`privacy.html` 기준 색상 토큰
- `Components.swift`: 헤더, 로고 마크, pill 탭, 카드, 섹션 제목, 기본 버튼
- `ContentView.swift`: 메인 급식/이번 주/시간표/알림/테마/푸터 화면
- `PrivacyPolicyView.swift`: 웹 `privacy.html`과 같은 카드형 개인정보처리방침 화면
- `Models.swift`: 화면 표시용 데이터 모델
- `Services.swift`: 방문자 수 REST 집계와 iOS 네이티브 알림 권한 요청 준비
- `Assets.xcassets`: 웹 `logo.svg` 기반 `BrandLogo`, 앱 아이콘 원본 `AppIconSource`, Android 알림 아이콘 기반 `LunchSymbol` asset

## 다음 연동 작업

- 샘플 급식/시간표 데이터를 실제 NEIS API 응답으로 교체
- 방문자 수는 Firebase Realtime Database REST API의 `stats/visitCount`와 연결되어 있으며, 웹과 같은 조건부 증가 흐름을 사용합니다.
- iOS 원격 푸시는 Apple Developer Program, APNs 키, `GoogleService-Info.plist`, Firebase iOS SDK 추가 뒤 `Services.swift`의 연결 지점에 FCM topic `meal` 구독을 붙입니다.
- 앱 출시용 `AppIcon.appiconset`은 Xcode에서 `AppIconSource` 또는 별도 1024px 원본으로 생성
- `shareApp()`을 `ShareLink` 또는 UIKit activity sheet로 연결

## 주의

현재 코드는 iOS 프로젝트에 붙여 넣기 위한 SwiftUI 소스 시작점입니다. 아직 `.xcodeproj` 또는 `.xcworkspace`는 포함하지 않았습니다.
Firebase iOS SDK와 `GoogleService-Info.plist`가 없으면 원격 푸시 수신은 동작하지 않지만, 알림 권한 요청과 원격 알림 등록 준비 코드는 포함되어 있습니다.
