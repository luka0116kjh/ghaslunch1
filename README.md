# GHAS 알리미

경기자동차과학고등학교 학생을 위한 비공식 급식·시간표·학사 일정·학생 코드 통합 서비스입니다. 기본 서비스는 Firebase Hosting에 배포되는 웹/PWA이며, Android와 iOS는 같은 웹 앱을 WebView/WKWebView로 감싸 모바일 앱 형태로 제공합니다.

> 이 프로젝트는 학교 또는 교육청의 공식 앱이 아닙니다.

## 주요 기능

| 기능 | 현재 상태 |
| --- | --- |
| 오늘의 급식 | 구현됨. 중식/석식과 칼로리를 표시합니다. |
| 내일의 급식 | 구현됨. 오늘 화면 상단의 전환 버튼으로 접근합니다. |
| 이번 주 급식 | 구현됨. 평일 중식/석식을 주 단위로 표시합니다. |
| 시간표 | 구현됨. 학년/반 선택, 오늘/내일 전환, 2026 보정 시간표 fallback을 포함합니다. |
| 일정표 | 구현됨. 이번달/다음달 학사 일정 전환을 제공합니다. |
| 급식 칼로리 | 구현됨. 각 메뉴 목록의 마지막 줄 뒤에 함께 표시됩니다. |
| 다크/라이트 테마 | 구현됨. `localStorage`/쿠키와 네이티브 저장소에 동기화합니다. |
| 링크 공유 | 구현됨. Web은 Web Share API 또는 클립보드 fallback, Android는 네이티브 공유 시트를 사용합니다. |
| 학생증/급식용 바코드 또는 QR | 구현됨. 이미지를 업로드해 바코드 영역만 잘라 로컬 저장소에 저장합니다. |
| 바코드 밝기 향상 | 구현됨. Android/iOS 네이티브 브리지가 바코드 모달 사용 중 화면 밝기와 화면 꺼짐을 제어합니다. |
| 방문자 수 | 구현됨. Firebase Realtime Database `stats/visitCount`를 페이지 로드마다 +1 트랜잭션으로 증가시킵니다. |
| 알림 설정 | Web 버튼은 숨김/비활성화. Android/iOS는 네이티브 알림 설정 UI가 있습니다. |

## 플랫폼 지원 현황

| 기능명 | Web/PWA | Android WebView | iOS WKWebView | 비고 |
| --- | --- | --- | --- | --- |
| 급식 조회 | 지원 | 지원 | 지원 | NEIS Open API 직접 호출 |
| 이번 주 급식 | 지원 | 지원 | 지원 | 월~금 중식/석식 |
| 시간표 | 지원 | 지원 | 지원 | NEIS `hisTimetable` + 로컬 fallback |
| 일정표 | 지원 | 지원 | 지원 | `schedule.js` 기반 |
| 테마 전환 | 지원 | 지원 | 지원 | Web 저장값을 네이티브 저장소와 동기화 |
| 공유 | 지원 | 지원 | 제한적 | Android는 네이티브 공유. iOS는 WebView의 Web Share 지원 여부에 의존 |
| 바코드 표시 | 지원 | 지원 | 지원 | 업로드 이미지를 crop 후 `localStorage`에 저장 |
| 바코드 밝기 처리 | 미지원 | 지원 | 지원 | Web 단독은 화면 밝기 API 없음 |
| 알림 설정 | 비활성 | 지원 | 지원 | Web Push/FCM 버튼은 숨김. 모바일은 로컬/네이티브 설정 |
| 방문자 수 | 지원 | 지원 | 지원 | 같은 웹 화면 로드 기준으로 집계 |

## 화면 구성 및 UI

- 상단 헤더: 학교 로고, `경기자동차과학고` 제목, 공유 버튼, 오늘 날짜 영역이 있습니다.
- Web 공유 버튼: 헤더 오른쪽에 표시됩니다. Android 앱에서는 네이티브 공유 아이콘을 별도로 띄우고 웹 공유 버튼은 숨깁니다.
- 알림 설정 버튼: Web DOM에는 있지만 `hidden disabled` 상태입니다. Android는 WebView 위쪽 오른쪽에 네이티브 알림/공유 아이콘을 오버레이합니다. iOS는 하단 네이티브 툴바의 종 버튼으로 알림 설정을 엽니다.
- 메뉴: 상단 탭 형태로 `오늘`, `이번 주`, `시간표`, `일정표`, 테마 버튼이 있습니다.
- 오늘 화면: `내일의 급식` 전환 버튼, 중식/석식 카드, `내 바코드 / QR` 카드가 표시됩니다.
- 바코드 접근: 오늘 화면의 `내 바코드 / QR` 카드에서 등록/변경하거나 저장된 이미지를 눌러 모달로 확인합니다.
- 칼로리 표시: 급식 카드의 별도 칼로리 영역은 비우고, 현재는 메뉴 목록 마지막 줄에 `· 칼로리` 형태로 붙여 표시합니다.

## Android WebView 앱

- 위치: `android/`
- 앱 이름: `GHAS 알리미`
- applicationId: `kr.hs.ghas.ghason`
- 버전: `versionName 3.2.3`, `versionCode 13`
- WebView URL: `https://ghaslunch1.web.app/`
- 신뢰 host: `ghaslunch1.web.app`, `ghaslunch1.firebaseapp.com`
- WebView 설정: JavaScript, DOM Storage, wide viewport, overview mode가 켜져 있고 확대 컨트롤은 꺼져 있습니다.
- 파일 업로드: `WebChromeClient.onShowFileChooser`로 이미지 선택을 Android 문서 선택기에 연결합니다.
- 뒤로가기: 바코드 밝기 모드를 먼저 해제하고, WebView history가 있으면 `goBack()`, 없으면 앱을 종료합니다.
- 네이티브 기능: `GHASAndroidApp`, `GHASAndroidNotifications`, `AndroidBridge` JavaScript interface를 신뢰 host에서만 주입합니다.
- 바코드 밝기: `WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_FULL`과 `FLAG_KEEP_SCREEN_ON`을 사용하고 닫을 때 복구합니다.
- 알림: 카테고리별 급식/시간표/학교 공지 알림, 오전/오후 시간 입력, Android 13+ 알림 권한 요청, 부팅/앱 업데이트/시간 변경 후 재예약을 지원합니다. 레거시 급식 FCM topic `meal` 구독 코드도 남아 있습니다.

실행/빌드:

```bash
cd android
./gradlew :app:assembleDebug
./gradlew :app:installDebug
./gradlew :app:bundleRelease
```

Windows:

```powershell
cd android
.\gradlew.bat :app:assembleDebug
.\gradlew.bat :app:installDebug
.\gradlew.bat :app:bundleRelease
```

Release 빌드는 `android/local.properties`, Gradle properties 또는 환경 변수에 `GHAS_RELEASE_STORE_FILE`, `GHAS_RELEASE_STORE_PASSWORD`, `GHAS_RELEASE_KEY_ALIAS`, `GHAS_RELEASE_KEY_PASSWORD`가 필요합니다.

## iOS WebView 앱

- 실제 Xcode 프로젝트 위치: `ghaslunch/ghaslunch.xcodeproj`
- 주요 소스: `ghaslunch/ghaslunch/`
- 보조/이전 SwiftUI 소스와 체크리스트: `ios/`
- Bundle ID: `kr.hs.ghas.lunch`
- Deployment Target: iOS 16.0
- 버전: `MARKETING_VERSION 3.2.3`, `CURRENT_PROJECT_VERSION 13`
- WebView URL: `https://ghaslunch1.web.app/?v=20260522-holiday-timetable-fix`
- 구조: SwiftUI 앱에서 `WKWebView`를 표시하고 FirebaseCore를 초기화합니다.
- 테마: 웹 bridge의 `setTheme/getTheme`을 `UserDefaults`와 SwiftUI `@AppStorage`에 동기화합니다.
- 바코드 밝기: 바코드 모드 진입 시 `UIScreen.main.brightness = 1.0`, `isIdleTimerDisabled = true`로 설정하고, 화면 이탈/백그라운드 전환 시 복구합니다.
- 알림: iOS 네이티브 하단 툴바에서 급식/시간표/학교 공지 로컬 알림 설정을 저장하고 반복 알림을 예약합니다. 웹 알림 bridge의 직접 권한 요청은 비활성화되어 있습니다.
- 제한: 원격 APNs/FCM 토큰 등록과 서버 기반 푸시는 아직 구현되지 않았습니다.

실행/빌드:

1. Xcode에서 `ghaslunch/ghaslunch.xcodeproj`를 엽니다.
2. `ghaslunch` scheme을 선택합니다.
3. 시뮬레이터 또는 실제 기기를 선택합니다.
4. Run 또는 Archive를 실행합니다.

## 웹 배포

- 운영 URL: `https://ghaslunch1.web.app/`
- 보조 URL: `https://ghaslunch1.firebaseapp.com/`
- Firebase projectId: `ghaslunch1`
- Hosting public directory: `public/`
- 빌드 스크립트: `scripts/build-hosting.js`가 루트 정적 파일과 `src/data/`, `.well-known/assetlinks.json`을 `public/`으로 복사합니다.

로컬 정적 실행:

```bash
python3 -m http.server 8000
```

웹 빌드:

```bash
npm run build
```

Firebase Hosting 배포:

```bash
npm run deploy:hosting
# 또는
firebase deploy --only hosting
```

Functions 배포:

```bash
npm run deploy:functions
```

배포 전에는 `npm run build` 후 `public/`에 최신 `index.html`, `script.js`, `style.css`, `src/data/classTimetable2026.js`가 반영됐는지 확인합니다.

## 현재 반영 완료 사항

- 바코드/QR 인라인 카드와 모달 UI
- 사진 업로드 후 바코드 영역 crop 저장
- 바코드 모달 사용 중 Android/iOS 밝기 최대화 및 화면 꺼짐 방지
- 칼로리를 메뉴 줄 끝에 표시하는 렌더링
- 오늘/내일 급식 전환, 이번 주 급식, 시간표 오늘/내일 전환, 일정표 이번달/다음달 전환
- 테마별 색상 대응 및 WebView 네이티브 저장소 동기화
- Web 공유 버튼과 Android 네이티브 공유 아이콘
- Android 네이티브 알림 설정 다이얼로그, 카테고리별 토글, 오전/오후 시간 입력
- iOS 네이티브 알림 설정 화면과 로컬 반복 알림 예약
- Firebase Hosting 빌드 구조와 Android App Links용 `.well-known/assetlinks.json` 복사
- Android release bundle 빌드 설정과 서명값 검증
- iOS 프로젝트 버전 3.2.3 / 빌드 13 반영

## 제한 사항 및 추후 개선 항목

- Web Push/FCM: `notification.js`, `firebase-messaging-sw.js`는 보존되어 있지만 현재 메인 `index.html`에서 로드하지 않고 웹 알림 버튼도 숨김/비활성입니다.
- 방문자 수: 코드상 Realtime Database 트랜잭션으로 구현되어 있습니다. 실제 동작은 배포된 `database.rules.json`과 `stats/visitCount` 기존 숫자 값 존재 여부에 의존합니다.
- Firestore: 현재 방문자 수와 규칙은 Firestore가 아니라 Firebase Realtime Database를 사용합니다.
- Realtime Database 권한: `stats/visitCount`는 읽기와 기존 숫자에서 정확히 +1 쓰기만 허용합니다. `tokens`, `notificationTokens` 쓰기는 차단되어 있습니다.
- Android 알림: 네이티브 로컬 알림과 레거시 FCM topic 처리 코드가 있습니다. `GhasFirebaseMessagingService.onNewToken()`에는 백엔드 토큰 동기화 TODO가 남아 있습니다.
- iOS 알림: 로컬 반복 알림은 있으나 APNs/FCM 원격 푸시와 서버 기반 일일 콘텐츠 전달은 TODO 상태입니다.
- 스토어 배포: Android release signing 구조는 있으나 keystore/Play Console 준비는 로컬 설정에 의존합니다. App Store/Play Store 등록 자료와 심사 상태는 코드에서 확인되지 않습니다.
- 사진/바코드 저장: 업로드 이미지는 서버에 보내지 않고 브라우저/WebView 로컬 저장소에 data URL로 저장합니다.

## 기술 스택

| 영역 | 사용 기술 |
| --- | --- |
| Web/PWA | HTML, CSS, JavaScript, Service Worker, Web App Manifest |
| 데이터 | NEIS Open API, 로컬 2026 시간표 fallback, `schedule.js` 학사 일정 |
| Firebase | Firebase Hosting, Realtime Database, Functions v2, Firebase Cloud Messaging(Android) |
| Functions | Node.js 20, Firebase Functions Secret `NEIS_API_KEY` |
| Android | Kotlin, Android WebView, Gradle, Firebase Messaging, AlarmManager, NotificationManager |
| iOS | SwiftUI, WKWebView, FirebaseCore, UserNotifications |

## 폴더 구조

```text
ghaslunch/
├── index.html                         # 웹/PWA 메인 화면
├── script.js                          # 급식, 시간표, 일정, 테마, 바코드, 방문자 로직
├── style.css                          # 웹 UI 스타일
├── schedule.js                        # 학사 일정 데이터
├── afterschool.js                     # 방과후/공지 보조 스크립트
├── notification.js                    # 보존된 Web Push/Android bridge 참고 코드
├── sw.js                              # PWA 서비스 워커
├── firebase-messaging-sw.js           # 보존된 FCM 서비스 워커
├── manifest.json                      # PWA 메타데이터
├── logo.svg, icon-192.png, icon1.png  # 로고/아이콘 리소스
├── src/data/classTimetable2026.js     # 시간표 fallback 데이터
├── public/                            # Firebase Hosting 배포 산출물
├── scripts/build-hosting.js           # Hosting 산출물 생성 스크립트
├── functions/                         # NEIS 프록시용 Firebase Functions
├── android/                           # Android Kotlin WebView 앱
├── ghaslunch/                         # iOS Xcode 프로젝트
├── ios/                               # iOS 보조 소스/체크리스트
├── docs/                              # 아키텍처와 배포 문서
├── database.rules.json                # Realtime Database Rules
├── firebase.json                      # Firebase Hosting/Functions/Database 설정
└── README.md
```

## 실행 및 배포 체크리스트

- [ ] 웹 화면이 `https://ghaslunch1.web.app/` 기준으로 정상 표시되는지 확인
- [ ] 오늘/내일/이번 주 급식 데이터와 칼로리 표시 확인
- [ ] 시간표 학년/반 선택, 오늘/내일 전환, fallback 표시 확인
- [ ] 일정표 이번달/다음달 전환 확인
- [ ] 바코드 이미지 업로드, crop, 모달 표시 확인
- [ ] Android/iOS에서 바코드 모달 밝기 복구 확인
- [ ] 테마 전환 후 새로고침/WebView 재실행 유지 확인
- [ ] 공유 버튼 동작 확인(Web, Android)
- [ ] 방문자 수가 `확인 불가`가 아닌 숫자로 표시되는지 확인
- [ ] Android WebView, 파일 선택기, 뒤로가기, 알림 설정 다이얼로그 확인
- [ ] iOS WKWebView, 테마 동기화, 알림 설정 sheet, 바코드 밝기 확인
- [ ] `npm run build` 후 `public/` 산출물 확인
- [ ] `cd android && ./gradlew :app:bundleRelease` 또는 Windows `.\gradlew.bat :app:bundleRelease` 확인
- [ ] Firebase Hosting 배포 후 운영 URL 재확인
