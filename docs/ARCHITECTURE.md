# 아키텍처

GHAS알리미는 하나의 웹 앱을 중심으로 PWA, Android WebView, iOS WKWebView 앱을 함께 운영하는 구조입니다.

## 구성 개요

```text
사용자
  ├─ 브라우저/PWA
  ├─ Android WebView 앱
  └─ iOS WKWebView 앱
        ↓
Firebase Hosting
        ↓
정적 웹 앱(index.html, script.js, style.css)
        ├─ NEIS Open API
        ├─ Firebase Realtime Database
        └─ Firebase Functions NEIS 프록시
```

## Web/PWA

웹 앱은 `index.html`, `style.css`, `script.js`를 중심으로 동작합니다.

- `script.js`는 급식, 시간표, 학사 일정, 테마, 학생 코드, 방문자 카운터를 처리합니다.
- `schedule.js`는 2026학년도 학사 일정 원본 문자열을 제공합니다.
- `privacy.html`은 메인 앱과 같은 디자인 톤의 개인정보처리방침 화면입니다.
- `sw.js`는 기본 앱 셸 캐싱과 오프라인 진입을 담당합니다.
- `manifest.json`은 PWA 설치 메타데이터를 제공합니다.

## 데이터 흐름

급식과 시간표는 NEIS Open API를 사용합니다.

- 교육청 코드: `J10`
- 학교 코드: `7530908`
- 급식 endpoint: `mealServiceDietInfo`
- 시간표 endpoint: `hisTimetable`

현재 웹 로직은 클라이언트에서 NEIS API URL을 조립합니다. `functions/`에는 NEIS API 키를 Firebase Secret으로 다루는 프록시가 준비되어 있으며, 운영 정책에 따라 클라이언트 직접 호출 대신 프록시 호출로 전환할 수 있습니다.

## Firebase

Firebase는 Hosting, Realtime Database, Functions 용도로 사용됩니다.

- Hosting: 정적 PWA 배포
- 현재 운영 URL: `https://ghaslunch1.web.app/`
- 미검증 후보 URL: `https://ghaslunch.web.app/`
- Firebase projectId: `ghaslunch1`
- Realtime Database: 방문자 카운터와 일부 읽기 전용 데이터 경로
- Functions: NEIS API 프록시
- Cloud Messaging: Android 네이티브 앱 알림에 사용

Realtime Database Rules의 현재 정책:

- 전체 기본 read/write 차단
- `stats/visitCount`는 읽기 허용, 숫자 1 증가 쓰기만 허용
- `meals`, `timetable`, `notices`는 읽기 허용
- `tokens`, `notificationTokens`는 쓰기 차단

## Android 앱

Android 앱은 현재 운영 URL의 웹 앱을 WebView로 표시하는 래퍼입니다.

- 패키지: `kr.hs.ghas.ghason`
- minSdk: 23
- targetSdk: 36
- compileSdk: 36
- 알림: Firebase Messaging, Android 13+ `POST_NOTIFICATIONS`
- WebView URL: `https://ghaslunch1.web.app/`

웹의 알림 버튼은 `GHASAndroidNotifications` 브리지를 호출합니다. Android 앱은 권한 허용 후 FCM topic `meal` 구독 방식으로 앱 알림을 처리합니다.

## iOS 앱

iOS 앱은 SwiftUI 앱 안에서 `WKWebView`를 표시합니다.

- Bundle ID: `kr.hs.ghas.lunch`
- Deployment Target: iOS 16.0
- WebView URL: `https://ghaslunch1.web.app/`
- 미검증 후보 URL: `https://ghaslunch.web.app/`
- 허용 host: `ghaslunch1.web.app`, `ghaslunch1.firebaseapp.com`
- 의존성: FirebaseCore

iOS 네이티브 브리지는 `window.GHASAndroidApp`, `window.GHASAndroidNotifications` 이름으로 웹 호환 객체를 주입합니다. 현재 iOS 알림 권한 요청과 토큰 저장은 비활성화되어 있으며, 테마 저장과 iPad 레이아웃 보정만 활성 상태입니다.

## 테마 동기화

웹 앱은 `localStorage`에 테마를 저장하고, iOS 래퍼는 `UserDefaults`의 `theme` 값을 사용해 SwiftUI 배경과 WebView 내부 클래스를 맞춥니다.

지원 값:

- `light`
- `dark`
- 빈 값 또는 미설정: 시스템 설정 따름

## 개인정보와 로컬 저장

브라우저 또는 WebView 로컬 저장소에는 다음 정보가 저장될 수 있습니다.

- 테마 설정
- 알림 설정 상태
- 학생 이름
- 학생 코드 문자열
- 학생 코드 이미지 데이터

학생 코드 이미지는 외부 서버에 업로드하지 않고 로컬 저장소에만 저장하는 구조입니다.
