# GHAS Lunch Widget

이 폴더는 iOS WidgetKit Extension(오늘 급식 위젯) 소스입니다.

`ghaslunch/ghaslunch.xcodeproj`의 `GHASLunchWidget` 타깃에 이미 연결되어 있습니다.

- `GHASLunchWidget.swift` — 위젯 타깃 Sources
- `Info.plist` — 위젯 타깃 `INFOPLIST_FILE`

| 항목 | 값 |
| --- | --- |
| 타깃 | `GHASLunchWidget` (app-extension) |
| Bundle ID | `kr.hs.ghas.lunch.widget` |
| Deployment Target | iOS 16.0 (앱과 동일, iOS 17+ 에서 `containerBackground` 적용) |
| 번들 위치 | `ghaslunch.app/PlugIns/GHASLunchWidget.appex` |

앱 타깃 `ghaslunch`가 `Embed Foundation Extensions` 단계로 위젯을 포함하므로, 앱만 빌드해도 위젯이 함께 빌드·임베드됩니다.

위젯은 NEIS 급식 API에서 오늘 중식을 직접 가져오고, 메뉴를 두 개씩 묶어 다음처럼 표시합니다.

```text
오늘 급식                    ↻
쌀밥 · 미역국 ·
제육볶음 · 배추김치 ·
요구르트
7월 26일 일요일
```

## Android 위젯과의 디자인·동작 정렬

Android `TodayMealWidgetProvider`를 기준으로 맞췄습니다.

| 항목 | 값(Android와 동일) |
| --- | --- |
| 배경색 | `#F9FAFB` 고정 |
| 제목 | 15pt bold `#1C1C1E` |
| 급식 | 16pt bold `#262626`, 줄간격 4 |
| 날짜 | 하단, 11pt `#747A82`, `M월 d일 EEEE` |
| 새로고침 | `↻` 32×32, `#EAF3FF` 배경 / `#2F8CFF` |
| 내부 여백 | 18 / 14 / 16 / 14 |
| 상태 문구 | Empty `오늘 등록된 급식이 없어요`, Error `급식을 불러오지 못했어요` |
| 갱신 주기 | 30분 |

### iOS 시스템 제약 (동일 구현 불가)

- **모서리·테두리**: WidgetKit이 위젯 바깥 모서리를 시스템 연속 곡률로 마스킹하므로 Android의 22dp + 1px 테두리를 바깥 가장자리에 강제할 수 없음 → 배경색만 채움.
- **새로고침 버튼**: 인터랙티브 버튼은 iOS 17+(`AppIntent`) 전용. iOS 16에서는 위젯 전체가 단일 탭 타깃이라 버튼을 숨김(탭 시 앱만 열림).
- **Loading 상태**: iOS는 타임라인 확정 전 시스템 redacted placeholder(샘플 메뉴)를 표시하므로 Android처럼 `급식을 불러오는 중...` 문자열을 확정 노출하는 단계가 없음.
