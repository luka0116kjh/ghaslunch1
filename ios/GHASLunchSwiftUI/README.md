# GHAS Lunch SwiftUI Starter

이 폴더는 웹 버전에서 최근 반영한 디자인과 개인정보처리방침 변경사항을 iOS SwiftUI 화면으로 옮긴 시작점입니다.

## 포함된 내용

- `GHASLunchApp.swift`: SwiftUI 앱 진입점과 테마 적용
- `AppTheme.swift`: 웹 `index.html`/`privacy.html` 기준 색상 토큰
- `Components.swift`: 헤더, 로고 마크, pill 탭, 카드, 섹션 제목, 기본 버튼
- `ContentView.swift`: 메인 급식/이번 주/시간표/알림/테마/푸터 화면
- `PrivacyPolicyView.swift`: 웹 `privacy.html`과 같은 카드형 개인정보처리방침 화면
- `Models.swift`: 화면 표시용 데이터 모델

## 다음 연동 작업

- 샘플 급식/시간표 데이터를 실제 NEIS API 응답으로 교체
- 방문자 수를 Firebase Realtime Database `stats/visitCount`와 연결
- iOS 푸시 토큰 저장 시 `platform: ios` 정책을 정하고 `database.rules.json` 확장 여부 검토
- `BrandMark`를 실제 `logo.svg` 기반 iOS asset으로 교체
- `shareApp()`을 `ShareLink` 또는 UIKit activity sheet로 연결

## 주의

현재 코드는 iOS 프로젝트에 붙여 넣기 위한 SwiftUI 소스 시작점입니다. 아직 `.xcodeproj` 또는 `.xcworkspace`는 포함하지 않았습니다.
