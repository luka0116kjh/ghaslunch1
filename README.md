#  경기자동차과학고 오늘의 급식

나이스(NEIS) 오픈 API를 활용하여 학교의 중식과 석식 정보를 실시간으로 보여주는 웹 페이지입니다.

##  주요 기능
- **지능형 날짜 자동 전환**: 밤 8시(20:00) 이후 접속 시 자동으로 '내일 급식'을 표시하여 사용자 편의성을 극대화했습니다.
- **실시간 날씨 및 시간**: 현재 시간과 위치 기반 날씨 정보를 실시간으로 확인합니다.
- **프리미엄 UI/UX**: 스켈레톤 로딩(Skeleton Loading)과 부드러운 애니메이션을 적용하여 전문적인 앱 수준의 환경을 제공합니다.
- **실시간 급식 확인**: 나이스(NEIS) 오픈 API를 통해 매일의 중식/석식 메뉴와 칼로리를 실시간으로 연동합니다.
- **음식 투표 및 랭킹**: 학생들이 좋아하는 메뉴를 실시간으로 투표하고 이달의 인기 메뉴 랭킹을 확인합니다.

##  시작하기
1. `config.js` 파일을 열어 본인의 **나이스 API 키**와 **Firebase 설정 정보**를 입력합니다.
2. 로컬에서 확인하거나 `firebase deploy --only "hosting,database"`를 통해 배포합니다.

##  사용자 경험(UX) 최적화
- **자동 시점 인식**: 사용자가 가장 메뉴를 많이 확인하는 시간대를 분석하여 밤 8시 이후에는 내일의 정보를 우선적으로 노출합니다.
- **Skeleton UI**: 데이터 로딩 중에도 사용자에게 페이지 구조를 미리 보여주어 인지적 대기 시간을 줄였습니다.
- **모바일 최적화**: 다크 모드 기반의 반응형 디자인으로 모바일 기기에서 최적의 가독성을 제공합니다.

##  실시간 투표 시스템 (Firebase)
전교생이 실시간으로 공유하는 투표 기능이 포함되어 있습니다.
- **실시간 정렬**: 투표수가 많은 음식이 자동으로 상단에 배치됩니다.
- **월간 초기화**: 매달 1일 00시에 모든 투표 데이터가 자동으로 초기화되어 새달의 랭킹이 시작됩니다.
- **사용 기술**: Firebase Realtime Database

##  보안 안내
- API 키가 포함된 `config.js` 파일은 `.gitignore`에 등록되어 있어, 깃허브에 업로드할 때 자동으로 제외됩니다. 개인 보안을 안전하게 유지할 수 있습니다.

##  사용 기술
- **Frontend**: JavaScript (Vanilla), CSS3 (Animations), Semantic HTML5
- **API**: NEIS Open API (급식), OpenWeather API (날씨)
- **Backend/Hosting**: Firebase Hosting, Firebase Realtime Database
- **Tooling**: Node.js, Firebase CLI

##  개발 및 트러블슈팅 노트
배포 과정에서 발생했던 주요 이슈와 해결 방법입니다:

1. **데이터베이스 URL 오류**: 
   - 실시간 데이터베이스 위치를 싱가포르(`asia-southeast1`)로 설정할 경우, 기본 주소(`.firebaseio.com`)가 아닌 지역 전용 주소(`.firebasedatabase.app`)를 사용해야 합니다.
2. **Data Connect 배포 에러**: 
   - `firebase init` 시 실수로 포함된 'Data Connect' 기능은 유료 결제가 필요합니다. 무료 배포를 위해 `firebase deploy --only hosting,database` 명령어를 사용했습니다.
3. **PowerShell 쉼표 인식**: 
   - 파워쉘에서 `--only` 옵션 뒤에 여러 타겟을 쓸 때는 `"hosting,database"`와 같이 따옴표를 써야 인자가 정확히 전달됩니다.
4. **Firebase SDK 버전**: 
   - 프로젝트 호환성을 위해 Firebase SDK 8버전(Compat)을 사용하였습니다.
