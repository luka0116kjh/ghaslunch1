# GHAS 오늘의 급식 (PWA)

경기자동차과학고등학교 학생들을 위해 제작된 가장 빠르고 편리한 급식 및 시간표 확인 웹 앱(Progressive Web App)입니다.

## 주요 기능
- **오늘, 내일, 이번 주 급식**: 나이스(NEIS) 오픈 API를 통해 식단표를 완벽한 줄바꿈과 정렬로 제공합니다.
- **학생 친화적 시간표**: 복잡한 과목명(예: "정보 처리와 관리")을 학생들이 알아보기 쉽게("정보 처리") 변환해 주는 맞춤형 DECODE 로직이 적용되어 있습니다.
- **PWA (프로그레시브 웹 앱)**: 웹사이트지만 스마트폰에 앱(APK)처럼 홈 화면에 추가하여 설치할 수 있습니다.
- **실시간 날씨**: 사용자의 접속일에 맞춰 정오 기준의 기온, 날씨 상태, 강수 확률 정보를 제공합니다. (OpenWeather 및 Open-Meteo 교차 지원)
- **다크/라이트 모드**: 사용자의 기기 설정에 맞춘 자동 테마 전환 및 수동 토글 버튼(🌓)을 지원하여 모바일 가독성을 극대화했습니다.
- **아침 알람 기능**: 앱이 켜져 있을 경우, 매일 오전 7시 30분에 오늘의 핵심 메뉴를 브라우저 로컬 푸시 알림으로 전송합니다.
- **실시간 방문자 카운터**: Firebase Realtime Database를 활용하여 보안이 적용된 실시간 누적 방문자 수를 화면 하단에 표시합니다.

## 시작하기 (설치 및 배포)
1. `config.js` 파일에 **NEIS API 키**, **OpenWeather API 키**(선택), **Firebase 설정 정보**를 입력합니다.
2. `npm run deploy:hosting` (또는 `firebase deploy --only hosting`) 명령어를 입력하여 Firebase Hosting 환경에 배포합니다.

## 사용 기술 (Tech Stack)
- **Frontend**: Vanilla JavaScript (ES6+), HTML5, CSS3 (CSS Variables)
- **APIs**: NEIS Open API (급식, 시간표), OpenWeather API, Open-Meteo API
- **Backend/DB**: Firebase Hosting, Firebase Realtime Database (방문자 통계)
- **PWA**: Service Worker (`sw.js`), `manifest.json`

## 개발 및 트러블슈팅 노트
1. **PWA 캐싱 및 배포 전략**: 
   - 앱 로직이 변경될 때마다 `sw.js`의 캐시 버전을 관리하고, `index.html` 내부의 `<script src="script.js?v=24">`처럼 쿼리 파라미터를 수정하여 사용자 스마트폰에서 최신 코드가 강제로 새로고침되도록(Cache Busting) 설계했습니다.
2. **시간표 데이터 정제(DECODE)**: 
   - 나이스 시간표 API 특성상 생소하거나 긴 과목명이 반환되는 문제를 해결하기 위해, JavaScript 객체(Dictionary)를 활용하여 SQL의 DECODE 함수처럼 직관적인 과목명으로 매핑해 주는 `decodeSubject` 함수를 도입했습니다.
3. **급식 텍스트 가독성 최적화**: 
   - `<br>` 태그와 괄호, 불필요한 엔터가 섞여 나오는 원본 텍스트를 정규식(`normalizeMenuText`)으로 필터링하여 깔끔한 한 줄 텍스트로 렌더링되도록 개선했습니다.
4. **보안 및 오프라인 모드 최적화**: 
   - XSS(크로스 사이트 스크립팅) 공격을 방지하기 위해 `escapeHTML` 함수로 모든 출력값을 검증합니다.
   - PWA 구조상 UI 프레임(App Shell)은 오프라인에서도 작동하게 만들고, 데이터는 최신성을 위해 실시간으로 가져오는 하이브리드 최적화를 진행했습니다.
