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
├── afterschool.js                # 방과후 수업 UI 및 표시 로직
├── afterschoolScheduleData.js    # 방과후 데이터 (Google Sheets에서 자동 생성 — 직접 수정 금지)
├── src/data/classTimetable2026.js # 2026 시간표 fallback 데이터
├── public/                       # Firebase Hosting 배포 산출물
├── scripts/build-hosting.js      # 루트 파일을 public/으로 복사하는 빌드 스크립트
├── scripts/build-afterschool-data.js # Google Sheets → afterschoolScheduleData.js 생성
├── .env                          # GOOGLE_API_KEY (gitignore, 커밋 금지)
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

## 방과후 수업 (Google Sheets 연동)

방과후 수업 데이터는 Google Sheets를 단일 원본으로 관리합니다. `scripts/build-afterschool-data.js`가 Google Sheets API로 시트를 읽어 `afterschoolScheduleData.js`를 자동 생성하고, `afterschool.js`가 이 데이터로 화면을 그립니다.

- `afterschoolScheduleData.js`는 **자동 생성 파일이므로 직접 수정하지 않습니다.** (파일 상단에 생성 주석이 있습니다.)
- 데이터 수정은 **Google Sheets에서만** 하고, 생성 스크립트를 실행해 반영합니다.

### 운영 규칙

`공학리더반` 행을 전체 방과후 운영 캘린더의 기준으로 사용합니다.

- 공학리더반이 `방과후 있음`인 날짜만 전체 운영일입니다.
- 공학리더반이 `없음`/`휴강`/`X`/`x`(또는 빈칸)인 날짜는 전체 미운영일이며, 다른 강좌 셀과 무관하게 표시하지 않습니다.
- 전체 운영일에 한해 각 강좌 셀을 확인합니다.
  - 빈칸 → 기본 운영(표시)
  - `방과후 있음` → 운영(표시)
  - `없음`/`휴강`/`X`/`x` → 해당 강좌만 제외
- 운영기간(시트에 날짜 컬럼이 있는 날) 밖 날짜는 표시하지 않습니다.
- 표시는 실제 오늘 날짜 기준입니다.

### Google Sheets API 인증

- Google Sheets API로 시트 데이터를 읽습니다.
- 인증은 `.env`의 `GOOGLE_API_KEY`를 사용합니다(`dotenv`로 로드).
- API Key는 코드에 하드코딩하지 않고 `.env`에서만 관리하며, `.env`는 `.gitignore`에 포함되어 GitHub에 올리지 않습니다.

### 생성 및 배포 순서

```bash
# 1) Google Sheets에서 데이터 수정
node scripts/build-afterschool-data.js   # 2) 시트 → afterschoolScheduleData.js 재생성
npm run build                            # 3) 루트 파일을 public/으로 복사
npm run deploy                           # 4) 배포 (hosting만: npm run deploy:hosting)
```

### 캐시 주의 (PWA)

이 앱은 PWA(Service Worker)라 데이터를 변경·배포해도 이전 캐시가 남아 옛 데이터가 보일 수 있습니다. 데이터 변경 후에는:

- `sw.js`의 캐시 버전(`CACHE_NAME`)을 올리고,
- `index.html`의 `afterschoolScheduleData.js?v=` 캐시버스터를 함께 갱신합니다.
- 배포 후 브라우저를 새로고침하거나 설치형 PWA를 재실행하면 최신 데이터가 반영됩니다.

## Android

- 위치: `android/`
- 런처 표시명: `GHAS알리미`
- applicationId: `kr.hs.ghas.ghason`
- 현재 설정 버전: `versionName 3.2.6`, `versionCode 15`
- WebView URL: `https://ghaslunch1.web.app/`
- 신뢰 host: `ghaslunch1.web.app`, `ghaslunch1.firebaseapp.com`

주요 네이티브 기능:

- `GHASAndroidApp` JavaScript interface
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
| Google Sheets API | 방과후 수업 데이터 원본 (`build-afterschool-data.js`가 빌드 시 읽음) |
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
- [ ] 방과후 데이터 변경 시 `node scripts/build-afterschool-data.js` 재실행 및 `sw.js` 캐시 버전/캐시버스터 갱신
- [ ] 방과후 표시(오늘 기준 운영/휴강, 공학리더반 기준 미운영일) 확인
- [ ] `npm run deploy:hosting`으로 Firebase Hosting 배포

## 릴리스 메모

- Android 또는 iOS 스토어에 새 앱 표시명/공유 문구를 반영하려면 다음 스토어 릴리스에서 버전 bump가 필요합니다.
- 웹 배포는 Firebase Hosting 배포만으로 반영됩니다.
- 패키지명, applicationId, Bundle ID, Firebase 설정, 서명 설정은 변경하지 않습니다.
