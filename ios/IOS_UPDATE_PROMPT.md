# iOS 버전 반영 프롬프트

이 문서는 GHAS 오늘의 급식 웹 버전의 최신 상태를 iOS 버전에 반영하기 위한 전체 작업 지시서입니다.

## 현재 알림 상태

- 알림 기능은 Android WebView/Web Push 제한과 보안 규칙 정리를 위해 임시 비활성화 상태입니다.
- 현재 빌드에서는 Web FCM, Web Push, iOS 알림 권한 요청, Realtime Database 토큰 저장을 사용하지 않습니다.
- 아래 문서의 기존 FCM/토큰 저장 내용은 향후 네이티브 FCM/APNs를 다시 연결할 때 참고용으로만 봅니다.

## 프로젝트 개요

- 앱 이름: GHAS 오늘의 급식
- 대상: 경기자동차과학고등학교 학생
- 목적: 급식 정보와 시간표 정보를 빠르게 확인하는 비공식 정보 제공 앱
- 주의: 학교 또는 교육청의 공식 앱이 아님을 앱 안에서 안내해야 함

## 현재 웹 배포 상태

- Firebase 프로젝트: `ghaslunch1`
- Hosting URL: `https://ghaslunch1.web.app`
- 최신 배포 항목: Firebase Hosting + Realtime Database rules
- 전체 배포는 Firebase Functions/Dataconnect 단계에서 Blaze 요금제 제한으로 막힘
- 현재 배포 명령은 `firebase deploy --only "hosting,database"` 방식 사용

## 웹 파일 기준

- `index.html`: 메인 UI
- `privacy.html`: 개인정보처리방침 UI, 최근 메인 디자인과 통일됨
- `script.js`: 급식, 시간표, 방문자 수, 알림, 테마 등 동작
- `sw.js`: 서비스 워커
- `firebase-messaging-sw.js`: Firebase Messaging 서비스 워커
- `manifest.json`: PWA 매니페스트
- `icon1.png`, `icon-192.png`, `logo.svg`: 앱 아이콘/로고
- `database.rules.json`: Realtime Database 보안 규칙
- `firebase.json`: Firebase Hosting/Functions/Database 설정

## iOS에 반영할 핵심 변경

개인정보처리방침 화면이 웹 메인 화면과 디자인이 달라 보였기 때문에 `privacy.html`을 `index.html`과 같은 앱형 카드 디자인으로 변경했다. iOS 버전에서도 개인정보처리방침/약관 화면을 메인 화면과 같은 디자인 시스템으로 통일해야 한다.

## 전체 디자인 방향

- 모바일 중심 UI
- 좁고 정돈된 앱형 레이아웃
- 둥근 카드와 pill 버튼 사용
- 밝은 모드와 다크 모드 모두 지원
- 과한 문서형/웹페이지형 화면이 아니라 실제 앱 화면처럼 구성
- 메인 화면, 시간표 화면, 개인정보처리방침 화면이 모두 같은 앱처럼 보여야 함

## 색상

- 메인 포인트 컬러: `#FEE500`
- 포인트 텍스트: `#191919`
- 라이트 배경: `#F6F6F6`
- 라이트 카드 배경: `#FFFFFF`
- 라이트 메인 텍스트: `#191919`
- 라이트 보조 텍스트: `#707070`
- 라이트 구분선: `#F2F2F2`
- 라이트 비활성 pill: `#EEEEEE`
- 라이트 비활성 pill 텍스트: `#8E8E8E`
- 다크 배경: `#121212`
- 다크 카드 배경: `#1E1E1E`
- 다크 메인 텍스트: `#FFFFFF`
- 다크 보조 텍스트: `#AAAAAA`
- 다크 구분선: `#2C2C2C`
- 다크 비활성 pill: `#2C2C2C`
- 다크 비활성 pill 텍스트: `#707070`

## 폰트와 타이포

- 웹은 Pretendard 사용
- iOS에서는 Pretendard 적용이 가능하면 적용
- 어렵다면 iOS system font 사용
- 메인 제목은 굵게
- 카드 제목은 18pt 전후의 굵은 텍스트
- 본문은 15~16pt 전후
- 보조 문구는 10~14pt 전후로 작고 흐리게
- 앱 내 문구는 줄바꿈과 여백이 답답하지 않게 조정

## 공통 레이아웃

- 전체 화면 배경은 라이트/다크 배경색 사용
- 콘텐츠는 모바일 폭 기준으로 중앙 정렬된 느낌
- 상단 헤더:
  - 로고
  - 앱 또는 화면 제목
  - 우측 또는 좌측 아이콘 버튼
- 카드:
  - 배경은 카드 색상
  - corner radius는 약 24pt 느낌
  - padding은 약 24pt 느낌
  - 가벼운 그림자 또는 iOS에 맞는 elevation 사용
- pill 버튼:
  - corner radius는 999pt처럼 완전히 둥글게
  - 활성 상태는 `#FEE500`
  - 비활성 상태는 회색 pill

## 메인 화면 구성

### 헤더

- 로고: `logo.svg` 또는 iOS용 변환 리소스 사용
- 제목: `경기자동차과학고등학교` 또는 `GHAS 오늘의 급식`
- 오늘 날짜 표시
- 공유 버튼 또는 iOS 공유 액션 버튼

### 탭/버튼 그룹

- 오늘
- 내일
- 이번 주
- 시간표
- 알림
- 테마

활성 탭은 노란색 pill로 표시하고, 비활성 탭은 회색 pill로 표시한다.

### 급식 카드

- 오늘/내일 화면에는 점심 카드와 저녁 카드 표시
- 카드 제목 앞에 노란색 세로 바 표시
- 메뉴 본문은 읽기 쉬운 줄간격 사용
- 칼로리 정보는 카드 하단 오른쪽 또는 보조 텍스트로 표시

### 이번 주 급식

- 날짜별 급식 섹션 구성
- 날짜는 강조 색상 또는 굵은 텍스트로 표시
- 날짜별 메뉴는 구분선으로 나누어 표시

### 시간표

- 학년 선택
- 반 선택
- 시간표 카드
- 교시는 작은 pill 형태
- 과목명은 메인 텍스트로 표시

### 오프라인 화면

- 네트워크 연결이 없을 때 표시
- 안내 문구와 다시 시도 버튼 제공
- 다시 시도 버튼은 노란색 pill 스타일

### 푸터

- 방문자 수 표시
- 비공식 앱 안내 문구
- 개인정보처리방침 링크
- GitHub 링크

## 방문자 수

- 웹 footer에는 `visitor-counter` 영역이 있음
- label: `방문자 수`
- count: Firebase Realtime Database 기반
- iOS에서도 같은 방문자 집계 정책을 유지
- 단, 플랫폼별 중복 카운트 정책은 앱 구현에 맞게 조정 가능

## 알림

- 웹은 Firebase Cloud Messaging 기반
- 사용자가 알림을 허용하면 FCM 토큰 저장
- 원본 토큰을 그대로 저장하지 않고 해시 처리한 식별자를 저장
- 저장 정보:
  - `lastUpdated`
  - `platform`
- 웹에서는 `platform: web`
- iOS에서는 네이티브 푸시 구조에 맞춰 `platform: ios` 등으로 분리 가능
- 알림 해제 시 토큰 식별자 삭제 시도
- 개인정보처리방침에는 알림 토큰과 삭제 정책이 설명되어야 함

## 로컬 설정

- 테마 설정 저장
- 알림 설정 저장
- 웹에서는 브라우저/WebView 로컬 저장소 사용
- iOS에서는 `UserDefaults` 등 네이티브 저장소로 대응 가능

## 개인정보처리방침 화면 최신 변경

`privacy.html`은 기존 문서형 화면에서 메인 앱과 같은 카드형 화면으로 변경됨.

반영된 디자인:

- `index.html`과 동일한 브랜드 톤 사용
- 배경색, 카드색, 텍스트색, 다크모드 색상 토큰 통일
- Pretendard/system 계열 폰트 사용
- 모바일 앱처럼 좁은 폭의 레이아웃
- 상단에 로고 + `개인정보처리방침` 제목
- 뒤로가기 아이콘 버튼 추가
- 시행일 표시: `2026년 4월 30일`
- 본문은 하나의 둥근 카드 안에 배치
- 각 섹션 제목 앞에 노란색 세로 바 표시
- 섹션 사이에는 얇은 구분선
- 하단에 노란색 `앱으로 돌아가기` pill 버튼 배치
- 푸터/보조 문구는 메인 앱처럼 작고 흐린 톤으로 처리
- 다크모드에서도 메인 화면과 동일한 느낌 유지

## 개인정보처리방침 문구

아래 내용은 iOS 버전에서도 유지한다. iOS 구현 방식에 맞게 `브라우저`, `WebView`, `Firebase Cloud Messaging` 등의 표현은 필요한 경우 자연스럽게 조정하되, 정책의 의미는 유지해야 한다.

### 앱 설명

GHAS 오늘의 급식은 경기자동차과학고등학교 학생의 급식 및 시간표 확인을 돕기 위해 제작된 비공식 정보 제공 앱입니다. 본 앱은 학교 또는 교육청의 공식 앱이 아닙니다.

### 수집하는 정보

- 방문자 수 집계를 위한 익명 방문 카운트
- 사용자가 알림을 허용한 경우 Firebase Cloud Messaging 토큰을 해시 처리한 식별자, 갱신 시각, 플랫폼 정보
- 앱 설정을 유지하기 위한 로컬 저장소 정보: 테마, 알림 설정 등

### 정보 이용 목적

- 급식 및 시간표 정보 제공
- 사용자가 요청한 알림 기능 제공
- 서비스 이용량 확인 및 안정성 개선

### 제3자 서비스

이 앱은 NEIS 오픈 API와 Firebase Hosting, Firebase Realtime Database, Firebase Cloud Messaging을 사용합니다. 각 서비스 제공 과정에서 Google/Firebase의 정책이 적용될 수 있습니다.

### 데이터 출처 및 고지

본 서비스는 NEIS 교육정보 개방포털의 Open API를 활용하여 급식 및 시간표 정보를 제공합니다. 제공되는 급식 및 시간표 정보는 학교 또는 교육청 사정에 따라 실제와 다를 수 있습니다.

- 데이터 출처: `https://open.neis.go.kr`

### 보관 및 삭제

알림을 해제하면 앱은 저장된 알림 토큰 식별자 삭제를 시도합니다. 앱 데이터를 삭제하면 로컬 설정도 함께 삭제됩니다.

### 권한

앱은 알림 권한만 요청하며, 카메라, 마이크, 위치, 결제 권한을 요청하지 않습니다.

### 문의

문의와 개선 요청은 GitHub를 통해 전달할 수 있습니다.

- GitHub: `https://github.com/luka0116kjh`

## Firebase Realtime Database 구조와 규칙 방향

### `stats/visitCount`

- 방문자 수 저장
- 읽기 허용
- 쓰기는 숫자 증가만 허용

### `tokens/{token_id}`

- 알림 토큰 식별자 저장
- `token_id`는 64자리 hex 해시 형식
- 저장 필드:
  - `lastUpdated`
  - `platform`
- 웹 rules 기준으로는 `platform` 값이 `web`만 허용됨
- iOS 토큰 저장까지 확장하려면 rules에서 `ios` 플랫폼 허용 여부 검토 필요

### 기타 경로

- 기본적으로 read/write 차단

## iOS 구현 시 확인할 항목

- 개인정보처리방침 화면이 메인 화면과 같은 디자인 시스템을 쓰는가
- 라이트/다크 모드가 웹과 같은 톤인가
- 카드 radius, 버튼 radius, 색상, 여백이 통일되어 있는가
- 비공식 앱 안내가 보이는가
- 데이터 출처 NEIS 링크가 보이는가
- GitHub 문의 링크가 보이는가
- 알림 권한 설명이 실제 iOS 권한 동작과 맞는가
- iOS 푸시 토큰 저장 방식이 개인정보처리방침과 충돌하지 않는가
- iOS에서 `platform: ios`를 저장한다면 Database rules도 함께 수정해야 하는가

## 현재 iOS 폴더에 생성된 파일

현재 repo에는 Xcode 프로젝트 자체가 아니라 SwiftUI 소스 시작점이 들어 있다.

- `ios/GHASLunchSwiftUI/GHASLunchApp.swift`
  - SwiftUI 앱 진입점
  - `@AppStorage("themePreference")`로 시스템/라이트/다크 테마 적용
- `ios/GHASLunchSwiftUI/AppTheme.swift`
  - 웹 `index.html`, `privacy.html`과 같은 색상 토큰
  - 라이트/다크 모드별 배경, 카드, 텍스트, pill 색상 정의
- `ios/GHASLunchSwiftUI/Components.swift`
  - `AppHeader`
  - `BrandMark`는 `Assets.xcassets/AppIconSource` 사용
  - `PillTabBar`
  - `InfoCard`
  - `SectionTitle`
  - `PrimaryButton`
- `ios/GHASLunchSwiftUI/Models.swift`
  - `MealCardData`
  - `WeeklyMealData`
  - `TimetableRowData`
  - `HomeTab`
  - `ThemePreference`
- `ios/GHASLunchSwiftUI/ContentView.swift`
  - 메인 앱 화면
  - 오늘/내일/이번 주/시간표 탭
  - iOS 네이티브 알림 권한 요청 UI
  - 테마 전환 UI
  - Firebase Realtime Database REST 기반 누적 방문자 수 표시
  - 개인정보처리방침 이동
- `ios/GHASLunchSwiftUI/PrivacyPolicyView.swift`
  - 웹 `privacy.html` 변경사항을 반영한 SwiftUI 개인정보처리방침 화면
- `ios/GHASLunchSwiftUI/Services.swift`
  - 방문자 수 REST 읽기/조건부 증가
  - iOS 알림 권한 요청 및 원격 알림 등록 준비
- `ios/GHASLunchSwiftUI/Assets.xcassets`
  - 웹 `logo.svg` 기반 `BrandLogo`
  - `icon1.png`, `icon-192.png` 기반 `AppIconSource`
  - Android 알림 아이콘 기반 `LunchSymbol`
- `ios/GHASLunchSwiftUI/README.md`
  - SwiftUI 시작점 설명과 다음 연동 작업

## MacBook에서 실험하기 위한 준비물

MacBook에서 iOS 버전을 실험하려면 아래가 필요하다.

- macOS가 설치된 MacBook
- Xcode 최신 버전
- Apple ID
- iPhone 실기기 테스트를 할 경우 Apple Developer 계정 또는 무료 개발자 서명
- Git 또는 zip으로 이 repo 파일 가져오기
- Firebase iOS 앱 설정용 `GoogleService-Info.plist`
- 실제 푸시 알림까지 테스트할 경우 Apple Developer Program, APNs 인증키, Firebase Cloud Messaging 설정

Windows에 설치한 Swift CLI는 Swift 언어와 패키지 실험에는 쓸 수 있지만, `SwiftUI`/iOS 시뮬레이터 빌드는 할 수 없다. iOS 앱 실행과 시뮬레이터 테스트는 Mac + Xcode에서 해야 한다.

## MacBook에서 Xcode 프로젝트 만들기

1. Xcode 실행
2. `File > New > Project...`
3. `iOS > App` 선택
4. Product Name: `GHASLunch`
5. Interface: `SwiftUI`
6. Language: `Swift`
7. 최소 iOS 버전은 가능하면 iOS 16 이상 권장
8. 프로젝트 생성 후 기본으로 생긴 `ContentView.swift`와 `App.swift`를 현재 repo의 SwiftUI 파일로 교체

추가할 파일:

- `GHASLunchApp.swift`
- `AppTheme.swift`
- `Components.swift`
- `Models.swift`
- `ContentView.swift`
- `PrivacyPolicyView.swift`
- `Services.swift`
- `Assets.xcassets`

주의:

- Xcode 프로젝트에 파일을 끌어넣을 때 `Copy items if needed`를 선택
- Target Membership에서 앱 target이 체크되어 있어야 함
- 기본 생성된 `@main` App 파일이 남아 있으면 `@main`이 중복되어 빌드 오류가 난다. 기존 기본 App 파일은 삭제하거나 `GHASLunchApp.swift` 하나만 `@main`으로 둔다.

## MacBook에서 첫 빌드 확인

1. Xcode 좌상단 scheme을 `GHASLunch`로 선택
2. 실행 대상은 먼저 iPhone Simulator 선택
3. `Cmd + B`로 빌드
4. `Cmd + R`로 실행
5. 확인할 화면:
   - 메인 화면이 뜨는가
   - 오늘/내일/이번 주/시간표 탭 전환이 되는가
   - 테마 버튼을 눌렀을 때 라이트/다크/시스템이 전환되는가
   - 개인정보처리방침 화면으로 이동되는가
   - 뒤로가기 버튼이 동작하는가
   - 다크모드에서 카드/텍스트 대비가 괜찮은가

## 현재 SwiftUI 코드의 한계

현재 SwiftUI 코드는 실제 API 연결 전 단계다.

- 급식 데이터는 샘플 하드코딩
- 시간표 데이터는 샘플 하드코딩
- 방문자 수는 Firebase Realtime Database REST API에 연결됨
- Firebase Messaging SDK와 `GoogleService-Info.plist`는 아직 미연결
- 알림 버튼은 iOS 네이티브 알림 권한 요청과 원격 알림 등록 준비까지만 수행
- NEIS API 미연결
- 앱 아이콘/로고 asset 미적용
- 공유 기능은 함수 placeholder

즉, 현재 상태는 디자인과 화면 구조에 더해 방문자 수 REST 집계와 iOS 알림 권한 요청 준비까지 포함한 SwiftUI 시작점이다.

## iOS에서 API 연결 시 필요한 작업

### NEIS 급식 API

웹에서는 NEIS 교육정보 개방포털 Open API를 사용한다.

- 출처: `https://open.neis.go.kr`
- 급식 정보 API 연결 필요
- 날짜 기준 오늘/내일/이번 주 조회 필요
- 점심/저녁 분리 표시 필요
- 칼로리 표시 필요
- 학교/교육청 정보는 웹 `script.js`의 기존 값을 기준으로 맞춘다

iOS에서 만들 서비스 예시:

- `NEISService.swift`
- `MealResponse.swift`
- `MealViewModel.swift`

필요 기능:

- 오늘 급식 조회
- 내일 급식 조회
- 이번 주 급식 조회
- 네트워크 실패 시 오프라인/오류 상태 표시
- API 응답의 HTML 태그나 줄바꿈 정리

### NEIS 시간표 API

- 학년 선택
- 반 선택
- 날짜 기준 시간표 조회
- 내일/오늘 시간표 구분이 필요하면 웹 동작과 맞춤

iOS에서 만들 서비스 예시:

- `TimetableService.swift`
- `TimetableResponse.swift`
- `TimetableViewModel.swift`

필요 기능:

- 선택한 학년/반 저장
- 시간표 조회
- 빈 시간표일 때 안내 문구 표시
- 주말/공휴일/데이터 없음 처리

## Firebase iOS 연동 준비

Firebase를 iOS에 연결하려면 MacBook에서 다음 절차가 필요하다.

1. Firebase Console 접속
2. 프로젝트 `ghaslunch1` 선택
3. iOS 앱 추가
4. Bundle ID 입력
   - 예: `com.ghas.lunch`
   - 실제 Xcode Bundle Identifier와 반드시 일치해야 함
5. `GoogleService-Info.plist` 다운로드
6. Xcode 프로젝트에 `GoogleService-Info.plist` 추가
7. Swift Package Manager로 Firebase SDK 추가

Firebase SDK URL:

- `https://github.com/firebase/firebase-ios-sdk`

추가할 가능성이 높은 Firebase 제품:

- `FirebaseCore`
- `FirebaseDatabase`
- `FirebaseMessaging`

App 초기화 예시 방향:

```swift
import FirebaseCore

@main
struct GHASLunchApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

현재 `GHASLunchApp.swift`에는 Firebase 초기화가 들어 있지 않으므로, Firebase SDK를 추가한 뒤 위 방향으로 반영해야 한다.

## 방문자 수 iOS 연결 방향

웹 기준:

- 경로: `stats/visitCount`
- 읽기 허용
- 쓰기는 숫자 증가만 허용

iOS에서 필요한 동작:

- 앱 첫 실행 또는 일정 기준으로 방문자 수 증가
- 현재 방문자 수 읽기
- footer에 `방문자 수 123` 형태로 표시

주의:

- 앱 실행마다 증가시키면 과도하게 증가할 수 있음
- 웹과 같은 정책인지, 하루 1회인지, 설치 1회인지 결정 필요
- 로컬 저장소 `UserDefaults`로 마지막 증가 날짜를 저장하는 방식 권장

예시 정책:

- `lastVisitCountDate`를 `UserDefaults`에 저장
- 오늘 날짜와 다를 때만 `visitCount + 1`
- 그 후 최신 값 표시

## iOS 푸시 알림 연결 방향

iOS 푸시는 웹 푸시보다 설정이 더 필요하다.

필요한 것:

- Apple Developer Program
- APNs 인증키 또는 인증서
- Firebase Console에 APNs 키 등록
- Xcode Signing & Capabilities에서 Push Notifications 추가
- Background Modes에서 Remote notifications 필요 여부 확인
- 앱에서 알림 권한 요청
- Firebase Messaging 토큰 수신

현재 개인정보처리방침은 알림 토큰 해시 식별자, 갱신 시각, 플랫폼 정보를 설명한다. iOS에서도 원본 토큰을 DB에 그대로 저장하지 말고 해시 처리한 식별자를 저장하는 방향을 유지한다.

iOS 저장 필드 제안:

- 경로: `tokens/{sha256(token)}`
- `lastUpdated`: 서버 시각 또는 Unix timestamp
- `platform`: `ios`

현재 `database.rules.json`은 `platform`이 `web`일 때만 허용한다. iOS 토큰을 저장하려면 rules 수정 필요.

현재:

```json
"platform": {
  ".validate": "newData.val() === 'web'"
}
```

iOS 허용 예시:

```json
"platform": {
  ".validate": "newData.val() === 'web' || newData.val() === 'ios'"
}
```

rules를 바꾼 뒤에는 Firebase Database rules 배포 필요:

```bash
firebase deploy --only database
```

또는 Hosting도 같이 배포할 때:

```bash
firebase deploy --only "hosting,database"
```

## iOS 권한 문구

iOS 권한 요청 시 앱의 개인정보 문구와 일치해야 한다.

- 요청하는 권한: 알림 권한
- 요청하지 않는 권한: 카메라, 마이크, 위치, 결제
- 권한 요청 전 사용자에게 왜 필요한지 간단히 설명하는 화면 또는 문구 권장

예시:

- `급식 알림을 받기 위해 알림 권한이 필요합니다.`
- `언제든지 설정에서 알림을 끌 수 있습니다.`

## 앱 아이콘과 로고

웹 자산:

- `logo.svg`
- `icon1.png`
- `icon-192.png`

iOS에서 필요한 작업:

- `Assets.xcassets`에 출시용 `AppIcon.appiconset` 구성 필요
- `BrandLogo`는 웹 `logo.svg`를 vector asset으로 반영함
- `AppIconSource`는 `icon1.png`, `icon-192.png`를 iOS imageset으로 반영함
- 현재 `BrandMark`는 `Image("AppIconSource")`를 사용함

교체 방향:

```swift
Image("AppIconSource")
    .resizable()
    .scaledToFill()
    .frame(width: 32, height: 32)
```

## Info.plist와 네트워크

NEIS API와 Firebase는 HTTPS를 사용하므로 일반적으로 별도 ATS 예외가 필요하지 않다.

확인할 항목:

- Bundle Identifier
- Display Name: `GHAS 오늘의 급식`
- Firebase `GoogleService-Info.plist` 포함 여부
- Push Notification capability
- Background Modes 필요 여부

## MacBook 실험 체크리스트

첫 번째 목표는 API 연결 전 UI 확인이다.

- Xcode 프로젝트 생성
- SwiftUI 파일 추가
- 기본 App 파일 중복 제거
- 빌드 성공
- 시뮬레이터 실행 성공
- 메인 화면 확인
- 탭 전환 확인
- 개인정보처리방침 화면 확인
- 라이트/다크 모드 확인
- 작은 iPhone 화면에서 텍스트 겹침 없는지 확인
- 큰 iPhone 화면에서 카드 폭이 과하게 넓어지지 않는지 확인

두 번째 목표는 데이터 연결이다.

- NEIS 급식 API 연결
- NEIS 시간표 API 연결
- 로딩/오류/데이터 없음 상태 추가
- Firebase 방문자 수 연결
- Firebase 푸시 토큰 저장 연결
- `database.rules.json`에서 `platform: ios` 허용 여부 반영

세 번째 목표는 실기기 테스트다.

- 실제 iPhone 연결
- Signing 설정
- 앱 설치
- 네트워크 호출 확인
- 알림 권한 요청 확인
- FCM 토큰 수신 확인
- Realtime Database 저장 확인
- 개인정보처리방침 문구와 실제 동작 일치 확인

## MacBook에서 Codex/ChatGPT에게 넘길 프롬프트

MacBook에서 Xcode 프로젝트를 연 뒤 아래 프롬프트를 그대로 사용할 수 있다.

```text
이 repo의 ios/GHASLunchSwiftUI 폴더에 있는 SwiftUI 시작 코드를 실제 Xcode iOS 앱 프로젝트에 통합해줘.

목표:
- 웹 index.html/privacy.html과 같은 디자인 시스템 유지
- ContentView.swift를 메인 화면으로 사용
- PrivacyPolicyView.swift를 개인정보처리방침 화면으로 사용
- AppTheme.swift 색상 토큰 유지
- Components.swift 공통 컴포넌트 유지
- 샘플 데이터 화면이 먼저 빌드되게 만들기

우선순위:
1. Xcode 빌드 오류 해결
2. 시뮬레이터에서 화면 확인
3. 개인정보처리방침 화면 디자인 확인
4. NEIS API 연결
5. Firebase Realtime Database 방문자 수 연결
6. iOS 푸시/FCM 토큰 저장 연결

주의:
- 기본 Xcode App 파일과 GHASLunchApp.swift의 @main이 중복되지 않게 정리
- iOS에서 platform 값을 저장한다면 database.rules.json에 ios 허용 필요
- 원본 FCM 토큰은 그대로 DB에 저장하지 말고 sha256 해시 식별자로 저장
- 앱은 알림 권한만 요청하고 카메라/마이크/위치/결제 권한은 요청하지 않음
```

## 요약

iOS 버전의 핵심 작업은 개인정보처리방침 화면을 웹 메인 앱과 같은 카드형 모바일 UI로 통일하고, 급식/시간표/방문자/알림/테마/비공식 안내/개인정보 문구의 정책을 현재 웹 기준과 맞추는 것이다.
