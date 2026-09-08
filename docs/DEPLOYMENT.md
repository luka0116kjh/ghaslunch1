# 배포와 운영

이 문서는 GHAS알리미의 웹, Firebase, Android, iOS 배포 절차를 정리합니다.

## 사전 준비

필요 도구:

- Node.js와 npm
- Firebase CLI
- Android Studio
- Xcode

Firebase 프로젝트:

- Project ID: `ghaslunch1`
- 현재 운영 URL: `https://ghaslunch1.web.app/`
- 미검증 후보 URL: `https://ghaslunch.web.app/`
- Realtime Database: `ghaslunch1-default-rtdb.asia-southeast1.firebasedatabase.app`

## 웹 빌드

루트에서 배포 산출물을 생성합니다.

```sh
npm run build
```

`build:hosting`은 루트 정적 파일을 `public/`으로 복사하고 `.well-known/assetlinks.json`도 함께 배치합니다.

## 웹 검증

```sh
node --check script.js
node --check schedule.js
node --check notification.js
node --check sw.js
node --check firebase-messaging-sw.js
npm run build
```

## Firebase Hosting 배포

```sh
npm run deploy:hosting
```

Hosting과 Realtime Database Rules를 함께 배포할 때:

```sh
firebase deploy --only "hosting,database"
```

전체 배포:

```sh
npm run deploy
```

## Firebase Functions

Functions는 Node.js 20 런타임을 사용합니다.

```sh
cd functions
npm install
npm run deploy
```

NEIS 프록시를 사용할 경우 `NEIS_API_KEY` secret을 설정해야 합니다.

```sh
firebase functions:secrets:set NEIS_API_KEY
```

Functions endpoint:

- `meals`: 급식 프록시
- `timetable`: 시간표 프록시

두 endpoint는 허용 origin만 CORS로 통과시키고, 날짜/학년/반 파라미터를 검증합니다.

## Android 배포

1. Firebase Console에서 Android 앱 패키지 `kr.hs.ghas.ghason`이 등록되어 있는지 확인합니다.
2. `android/app/google-services.json`을 최신 파일로 교체합니다.
3. `android/local.properties` 또는 Gradle property에 release signing 값을 설정합니다.
4. Android Studio에서 `android/` 폴더를 열고 Gradle Sync를 실행합니다.
5. release build 또는 App Bundle을 생성합니다.

Android 앱은 현재 운영 URL `https://ghaslunch1.web.app/`의 웹 앱을 WebView로 표시하고, 네이티브 FCM으로 `meal` topic 알림을 처리합니다.

## iOS 배포

1. Firebase Console에서 iOS 앱 Bundle ID `kr.hs.ghas.lunch` 설정을 확인합니다.
2. `ghaslunch/ghaslunch/GoogleService-Info.plist`가 최신 파일인지 확인합니다.
3. Xcode에서 `ghaslunch/ghaslunch.xcodeproj`를 엽니다.
4. `ghaslunch` scheme을 선택하고 빌드합니다.
5. 실제 기기에서 WebView 로딩, 테마 저장, 개인정보처리방침 링크, 외부 링크 처리를 확인합니다.

현재 iOS 알림 권한 요청은 비활성화되어 있습니다. Push Notifications capability와 APNs/FCM 연결은 네이티브 FCM 구현이 준비될 때만 다시 켭니다.

## 배포 전 체크리스트

- `npm run build` 성공
- `public/`에 최신 정적 파일 반영
- `database.rules.json`에서 토큰 쓰기 차단 유지 여부 확인
- 개인정보처리방침 시행일과 실제 수집 항목 일치
- 현재 운영 URL `https://ghaslunch1.web.app/`이 정상 동작하는지 확인
- 후보 URL `https://ghaslunch.web.app/`는 실제 배포와 화면 렌더링이 검증되기 전까지 운영 URL로 안내하지 않음
- Android/iOS 코드의 WebView URL이 현재 운영 URL과 일치하는지 확인
- Android 알림 권한과 FCM topic 구독 동작 확인
- iOS에서 알림 권한 팝업이 뜨지 않는지 확인
- Play Console/App Store 설명에 비공식 앱 문구 포함
