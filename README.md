# GHAS 오늘의 급식 (PWA)

경기자동차과학고등학교 학생을 위해 제작된 비공식 급식 및 시간표 확인 웹 앱입니다. Firebase Hosting 기반 PWA로 동작하며, WebView 래퍼를 통해 모바일 앱으로 배포할 수 있습니다.

> 이 프로젝트는 학교 공식 앱이 아닌 학생 제작 정보 제공 앱입니다.

## 주요 기능

- **오늘, 내일, 이번 주 급식**: NEIS 오픈 API의 급식 정보를 보기 좋게 정리합니다.
- **시간표 확인**: NEIS 시간표 데이터를 학생이 읽기 쉬운 과목명으로 표시합니다.
- **PWA 설치**: `manifest.json`과 `sw.js`를 통해 홈 화면 설치와 기본 오프라인 앱 셸을 지원합니다.
- **다크/라이트 모드**: 시스템 설정과 수동 토글을 지원합니다.
- **알림 기능**: 사용자가 알림 권한을 허용한 경우 브라우저 로컬 알림 및 Firebase Cloud Messaging 기반 알림을 사용할 수 있습니다.
- **방문자 카운터**: Firebase Realtime Database에 익명 누적 방문 수를 기록합니다.

## 배포 구조

- 정적 파일: `index.html`, `script.js`, `sw.js`, `firebase-messaging-sw.js`, `manifest.json`, `icon1.png`
- NEIS 오픈 API: 급식 및 시간표 데이터 조회
- Firebase Realtime Database: 방문자 카운터와 알림 토큰 식별자 저장
- 개인정보처리방침: `/privacy.html`

## 보안 메모

- `config.js`는 로컬 개발용 파일이며 Git과 Firebase Hosting 배포 대상에서 제외됩니다.
- Firebase client config와 FCM VAPID public key는 클라이언트에서 사용되는 공개 식별자입니다. 보안은 키 은닉이 아니라 Firebase Rules, Functions secret, 도메인 제한, Play Console 데이터 고지로 관리해야 합니다.
- 현재 정적 배포 환경에서는 NEIS API를 공개 조회 방식으로 호출합니다. API 키가 필요한 운영 구조로 전환할 경우 Firebase Functions 또는 별도 서버 프록시에서 secret으로 관리해야 합니다.
- Realtime Database Rules는 전체 공개 쓰기를 허용하지 않으며, 방문자 카운트는 증가 트랜잭션만 허용합니다.

## 배포 전 확인

```powershell
node --check script.js
node --check sw.js
node --check firebase-messaging-sw.js
npm run build
firebase deploy --only "hosting,database"
```

## Google Play 업로드 전 확인

- Play Console 앱 콘텐츠에 개인정보처리방침 URL을 등록합니다.
- 데이터 보안 섹션에 알림 토큰 식별자, 방문자 카운트, 앱 설정 저장 여부를 실제 동작 기준으로 입력합니다.
- WebView 래퍼에서 카메라, 마이크, 위치 등 불필요한 권한을 선언하지 않습니다.
- 외부 링크는 기본 브라우저 또는 Custom Tabs로 열고, WebView 뒤로가기와 네트워크 오류 화면을 구현합니다.
- 앱 설명에 학교 공식 앱이 아닌 비공식 정보 제공 앱이라는 문구를 포함합니다.
