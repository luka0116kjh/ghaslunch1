# GHAS알리미

경기자동차과학고등학교 급식 및 시간표 확인 앱입니다. 웹/PWA를 기본으로 운영하고, Android와 iOS 앱은 같은 운영 URL을 WebView/WKWebView로 표시합니다.

> 이 프로젝트는 학교 또는 교육청의 공식 앱이 아닌 비공식 정보 제공 앱입니다.

## 운영 정보

- 서비스 이름: `GHAS알리미`
- 운영 URL: `https://ghaslunch1.web.app/`
- Firebase projectId: `ghaslunch1`
- Hosting public directory: `public/`
- Android applicationId: `kr.hs.ghas.ghason`
- iOS Bundle ID: `kr.hs.ghas.lunch`

## 주요 기능

| 기능 | 설명 |
| --- | --- |
| 오늘/내일 급식 | 중식, 석식, 칼로리를 표시합니다. |
| 이번 주 급식 | 월~금 중식/석식을 주 단위로 표시합니다. |
| 시간표 | 학년/반 선택, 오늘/내일 전환, 주간 보기, 2026 로컬 보정 시간표 fallback을 지원합니다. |
| 일정표 | 이번달/다음달 학사 일정을 표시합니다. |
| 바코드/QR | 급식용 바코드 또는 QR 이미지를 업로드하고 crop해 로컬 저장소에 저장합니다. |
| 테마 | 라이트/다크 테마를 웹 저장소와 네이티브 브리지에 동기화합니다. |
| 공유 | 웹 공유 API, 클립보드 fallback, Android/iOS 네이티브 공유를 지원합니다. |
| 방문자 수 | Firebase Realtime Database `stats/visitCount`를 사용합니다. |
| 알림 설정 | 웹 알림 버튼은 비활성화되어 있고, Android/iOS는 네이티브 알림 설정 UI를 제공합니다. |

## 프로젝트 구조

```text
.
├── index.html                    # 웹/PWA 메인 화면
├── script.js                     # 급식, 시간표, 일정, 테마, 바코드, 방문자 로직
├── style.css                     # 웹 UI 스타일
├── manifest.json                 # PWA 매니페스트
├── privacy.html                  # 개인정보처리방침
├── notification.js               # 보존된 Web Push/알림 브리지 참고 코드
├── sw.js                         # PWA 서비스 워커
├── schedule.js                   # 학사 일정 데이터
├── afterschool.js                # 방과후 수업 표시 로직
├── src/data/classTimetable2026.js # 2026 시간표 fallback 데이터
├── public/                       # Firebase Hosting 배포 산출물
├── scripts/build-hosting.js      # 루트 파일을 public/으로 복사하는 빌드 스크립트
├── functions/                    # Firebase Functions
├── android/                      # Android WebView 앱
├── ghaslunch/                    # iOS Xcode 프로젝트
├── ios/                          # iOS 보조 소스/문서
└── docs/                         # 아키텍처 및 배포 문서
```

## Web / PWA

웹 앱은 별도 번들러 없이 정적 파일로 구성됩니다. `scripts/build-hosting.js`가 루트의 웹 파일과 `src/data/`, `.well-known/assetlinks.json`을 `public/`으로 복사합니다.

```bash
npm run build
npm run deploy:hosting
```

로컬 정적 서버:

```bash
python3 -m http.server 8000
```

## Android

- 위치: `android/`
- 런처 표시명: `GHAS알리미`
- applicationId: `kr.hs.ghas.ghason`
- 현재 설정 버전: `versionName 3.2.6`, `versionCode 15`
- WebView URL: `https://ghaslunch1.web.app/`
- 신뢰 host: `ghaslunch1.web.app`, `ghaslunch1.firebaseapp.com`

주요 네이티브 기능:

- `GHASAndroidApp`, `GHASAndroidNotifications`, `AndroidBridge` JavaScript interface
- 이미지 파일 선택기
- 바코드 모달 중 화면 밝기 최대화 및 화면 꺼짐 방지
- 급식/시간표/학교 공지 로컬 알림 설정
- Android 13+ 알림 권한 요청

빌드:

```bash
cd android
./gradlew :app:assembleDebug
./gradlew :app:installDebug
./gradlew :app:bundleRelease
```

Release 빌드는 `android/local.properties`, Gradle properties 또는 환경 변수에 아래 값이 필요합니다.

- `GHAS_RELEASE_STORE_FILE`
- `GHAS_RELEASE_STORE_PASSWORD`
- `GHAS_RELEASE_KEY_ALIAS`
- `GHAS_RELEASE_KEY_PASSWORD`

## iOS

- Xcode 프로젝트: `ghaslunch/ghaslunch.xcodeproj`
- 주요 소스: `ghaslunch/ghaslunch/`
- 보조 소스/문서: `ios/`
- 표시명: `GHAS알리미`
- Bundle ID: `kr.hs.ghas.lunch`
- 현재 설정 버전: `MARKETING_VERSION 3.2.6`, `CURRENT_PROJECT_VERSION 15`
- WebView URL: `https://ghaslunch1.web.app/`

주요 네이티브 기능:

- SwiftUI 기반 `WKWebView`
- FirebaseCore 초기화
- 테마 동기화 bridge
- 바코드 모달 중 화면 밝기 최대화 및 자동 잠금 방지
- 급식/시간표/학교 공지 로컬 알림 설정
- 네이티브 공유 시트

실행:

1. Xcode에서 `ghaslunch/ghaslunch.xcodeproj`를 엽니다.
2. `ghaslunch` scheme을 선택합니다.
3. 시뮬레이터 또는 실제 기기를 선택합니다.
4. Run 또는 Archive를 실행합니다.

## 데이터와 Firebase

| 영역 | 사용처 |
| --- | --- |
| NEIS Open API | 급식 및 시간표 조회 |
| `src/data/classTimetable2026.js` | 시간표 fallback |
| `schedule.js` | 학사 일정 |
| Firebase Hosting | 웹/PWA 배포 |
| Firebase Realtime Database | 방문자 수 집계 |
| Firebase Functions | NEIS 프록시 준비 코드 |
| Firebase Cloud Messaging | Android 레거시 알림 코드 |

## 배포 체크리스트

- [ ] `npm run build` 성공
- [ ] `public/index.html` title이 `GHAS알리미 - 경기자동차과학고등학교 급식 및 시간표 확인 앱!`인지 확인
- [ ] `public/manifest.json`의 `name`과 `short_name`이 `GHAS알리미`인지 확인
- [ ] 오늘/내일/이번 주 급식 표시 확인
- [ ] 시간표 일간/주간 보기와 학년/반 선택 확인
- [ ] 일정표 이번달/다음달 전환 확인
- [ ] 바코드/QR 등록, crop, 모달 표시 확인
- [ ] 테마 전환 후 새로고침 유지 확인
- [ ] 공유 버튼 동작 확인
- [ ] `npm run deploy:hosting`으로 Firebase Hosting 배포

## 릴리스 메모

- Android 또는 iOS 스토어에 새 앱 표시명/공유 문구를 반영하려면 다음 스토어 릴리스에서 버전 bump가 필요합니다.
- 웹 배포는 Firebase Hosting 배포만으로 반영됩니다.
- 패키지명, applicationId, Bundle ID, Firebase 설정, 서명 설정은 변경하지 않습니다.
