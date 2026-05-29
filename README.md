# GHAS 오늘의 급식

경기자동차과학고등학교 학생을 위한 비공식 급식, 시간표, 학사 일정 안내 앱입니다. 기본 서비스는 Firebase Hosting에 배포되는 PWA이며, Android와 iOS는 같은 웹 앱을 WebView로 감싸 모바일 앱 형태로 제공합니다.

> 이 프로젝트는 학교 또는 교육청의 공식 앱이 아닙니다.

## 주요 기능

- 오늘, 내일, 이번 주 급식 조회
- 학년/반 기반 시간표 조회
- 2026학년도 주요 학사 일정 표시
- 학생 코드 이미지 로컬 저장
- 다크/라이트 테마 저장 및 동기화
- PWA 설치와 기본 오프라인 앱 셸
- Firebase Realtime Database 기반 익명 방문자 카운터
- Android 네이티브 FCM 알림 브리지
- iOS WebView 래퍼와 테마 브리지

## 프로젝트 구조

```text
.
├── index.html                  # 메인 PWA 화면
├── script.js                   # 급식, 시간표, 일정, 테마, 방문자 카운터 로직
├── schedule.js                 # 2026학년도 학사 일정 원본
├── style.css                   # 앱 UI 스타일
├── notification.js             # 웹/Android 알림 브리지 로직
├── sw.js                       # PWA 서비스 워커
├── firebase-messaging-sw.js    # Firebase Messaging 서비스 워커
├── privacy.html                # 개인정보처리방침
├── public/                     # Firebase Hosting 배포 산출물
├── functions/                  # NEIS 프록시용 Firebase Functions
├── android/                    # Android WebView 앱
├── ghaslunch/                  # iOS SwiftUI/WKWebView 앱
├── ios/                        # iOS 운영 체크리스트와 이전 지시 문서
└── docs/                       # 아키텍처, 배포, 운영 문서
```

## 기술 스택

| 영역 | 사용 기술 |
| --- | --- |
| Web/PWA | HTML, CSS, JavaScript, Service Worker |
| 데이터 | NEIS Open API, Firebase Realtime Database |
| 배포 | Firebase Hosting |
| 서버리스 | Firebase Functions v2, Node.js 20 |
| Android | Gradle, Kotlin, Android WebView, Firebase Messaging |
| iOS | SwiftUI, WKWebView, FirebaseCore |

## 로컬 개발

필요 도구:

- Node.js
- npm
- Firebase CLI 또는 `npx firebase-tools`
- Android Studio
- Xcode 16 이상 권장

웹 배포 파일 생성:

```sh
npm run build
```

Firebase 배포:

```sh
npm run deploy:hosting
npm run deploy:functions
```

Hosting, Database Rules를 함께 배포할 때:

```sh
firebase deploy --only "hosting,database"
```

## 검증 명령

```sh
node --check script.js
node --check schedule.js
node --check notification.js
node --check sw.js
node --check firebase-messaging-sw.js
npm run build
```

Android는 `android/` 폴더를 Android Studio로 열어 Gradle Sync 후 빌드합니다.

iOS는 `ghaslunch/ghaslunch.xcodeproj`를 Xcode로 열고 `ghaslunch` scheme을 빌드합니다.

## 환경과 설정

- Firebase 프로젝트 ID: `ghaslunch1`
- 현재 운영 URL: `https://ghaslunch1.web.app/`
- 미검증 후보 URL: `https://ghaslunch.web.app/`
- Firebase 보조 URL: `https://ghaslunch1.firebaseapp.com/`
- NEIS 교육청 코드: `J10`
- NEIS 학교 코드: `7530908`
- Android applicationId: `kr.hs.ghas.ghason`
- iOS bundle identifier: `kr.hs.ghas.lunch`

Firebase client config와 FCM VAPID public key는 브라우저에서 쓰는 공개 식별자입니다. 비밀값은 Firebase Rules, Functions secret, 콘솔 설정, 도메인 제한으로 보호합니다.

## 문서

- [아키텍처](docs/ARCHITECTURE.md)
- [배포와 운영](docs/DEPLOYMENT.md)
- [Android 앱](android/README.md)
- [iOS 앱](ghaslunch/README.md)
- [iOS Firebase 체크리스트](ios/FIREBASE_IOS_TEST_CHECKLIST.md)

## 보안 메모

- `config.js`, keystore, signing property, `local.properties`는 커밋하지 않습니다.
- Realtime Database는 전체 공개 쓰기를 막고, 방문자 수는 증가 트랜잭션만 허용합니다.
- `tokens`와 `notificationTokens` 쓰기는 현재 차단되어 있습니다.
- Hosting은 CSP, HSTS, Referrer-Policy, Permissions-Policy를 설정합니다.
- iOS 알림 권한 요청은 현재 비활성화 상태입니다.
