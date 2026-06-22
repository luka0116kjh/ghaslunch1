# GHAS Lunch Widget

이 폴더는 iOS WidgetKit Extension에 넣을 오늘 급식 위젯 소스입니다.

Xcode에서 `Widget Extension` 타깃을 만든 뒤 아래 파일을 해당 타깃에 포함하세요.

- `GHASLunchWidget.swift`
- `Info.plist`

위젯은 NEIS 급식 API에서 오늘 중식을 직접 가져오고, 메뉴를 두 개씩 묶어 다음처럼 표시합니다.

```text
오늘 급식
쌀밥 · 미역국 ·
제육볶음 · 배추김치 ·
요구르트
```
