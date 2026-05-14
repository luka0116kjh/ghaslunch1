import Foundation

struct MealCardData: Identifiable {
    let id = UUID()
    let title: String
    let menu: String
    let calories: String
}

struct WeeklyMealData: Identifiable {
    let id = UUID()
    let date: String
    let meals: [MealCardData]
}

struct TimetableRowData: Identifiable {
    let id = UUID()
    let period: String
    let subject: String
}

struct ScheduleEventData: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let title: String

    static let year = 2026

    static let events: [ScheduleEventData] = parse(source)

    private static let source = """
    02 월 02.27 (금) ~ 02.27 (금) 전학년 예비소집일
    03 월 03.02 (월) ~ 03.02 (월) 기숙사 입사 및 오리엔테이션
    03.02 (월) ~ 03.02 (월) 대체 공휴일
    03.03 (화) ~ 03.03 (화) 입학식(1학년), 시업식(2,3학년)
    03.05 (목) ~ 03.05 (목) 1차 방과후학교 시작
    03.10 (화) ~ 03.10 (화) 마이크로 교육과정 시작
    03.14 (토) ~ 04.01 (수) 1회 기능사 실기 시험
    03.16 (월) ~ 03.20 (금) 2회 기능사 필기 접수
    03.20 (금) ~ 03.20 (금) 학부모총회 및 학교교육과정 설명회
    04 월 04.04 (토) ~ 04.09 (목) 2회 기능사 필기 시험
    04.06 (월) ~ 04.10 (금) 지방기능경기대회
    04.08 (수) ~ 04.10 (금) 수학여행
    04.10 (금) ~ 04.10 (금) 1회 기능사 실기 합격 발표(1차)
    04.17 (금) ~ 04.17 (금) 1회 기능사 실기 합격 발표(2차)
    04.22 (수) ~ 04.22 (수) 2회 기능사 필기 합격 발표
    04.27 (월) ~ 04.30 (목) 1-1차 정기시험
    04.27 (월) ~ 04.30 (목) 2회 기능사 실기 접수
    05 월 05.01 (금) ~ 05.01 (금) 노동절
    05.04 (월) ~ 05.04 (월) 재량휴업일1
    05.11 (월) ~ 05.14 (목) 3학년 의무검정 접수
    05.15 (금) ~ 05.15 (금) 스승의 날
    05.16 (토) ~ 05.16 (토) 중학생 초청 GHAS ON 진로페스티벌
    05.18 (월) ~ 05.19 (화) 학부모 대상 공개수업
    05.25 (월) ~ 05.25 (월) 대체 공휴일
    05.30 (토) ~ 06.14 (일) 2회 기능사 실기 시험
    06 월 06.03 (수) ~ 06.03 (수) 2026 지방선거
    06.04 (목) ~ 06.04 (목) 전국연합학력평가(1,2) 대수능모의(3)
    06.06 (토) ~ 06.06 (토) 현충일
    06.08 (월) ~ 06.11 (목) 3회 필기 접수
    06.13 (토) ~ 06.24 (수) 3학년 의무검정 시험
    06.26 (금) ~ 06.26 (금) 개교기념일 행사
    06.26 (금) ~ 06.26 (금) 2회 실기 합격 발표(1차)
    06.27 (토) ~ 06.27 (토) 49주년 개교기념일
    06.27 (토) ~ 07.02 (목) 3회 필기 시험
    06.30 (화) ~ 07.03 (금) 1-2차 정기시험
    07 월 07.03 (금) ~ 07.03 (금) 2회 기능사 실기 합격 발표(2차)
    07.07 (화) ~ 07.09 (목) 직업기초능력평가(3학년)
    07.10 (금) ~ 07.10 (금) 3학년 의무검정 합격 발표(1차)
    07.14 (화) ~ 07.15 (수) 학생자치회 리더십캠프
    07.15 (수) ~ 07.16 (목) 3학년 도제캠프
    07.15 (수) ~ 07.15 (수) 3회 기능사 필기 합격 발표
    07.16 (목) ~ 07.16 (목) 3학년 의무검정 합격 발표(2차)
    07.21 (화) ~ 07.21 (화) 방학식
    07.27 (월) ~ 07.30 (목) 3회 기능사 실기 접수
    08 월 08.17 (월) ~ 08.17 (월) 대체 공휴일
    08.19 (수) ~ 08.19 (수) 개학식
    08.21 (금) ~ 08.21 (금) 아우스빌둥 발대식
    08.22 (토) ~ 08.28 (금) 전국기능경기대회
    08.24 (월) ~ 08.27 (목) 4회 기능사 필기 접수
    08.29 (토) ~ 09.16 (수) 3회 기능사 실기 시험
    09 월 09.02 (수) ~ 09.02 (수) 전국연합학력평가(1,2학년) / 대수능모의평가(3학년)
    09.16 (수) ~ 09.21 (월) 4회 기능사 필기 시험
    09.19 (토) ~ 09.19 (토) 신입학 설명회
    09.24 (목) ~ 09.26 (토) 추석 연휴
    09.29 (화) ~ 10.02 (금) 2-1차 정기시험
    10 월 10.02 (금) ~ 10.02 (금) 3회 기능사 실기 합격 발표(1차)
    10.03 (토) ~ 10.03 (토) 개천절
    10.05 (월) ~ 10.05 (월) 대체 공휴일
    10.07 (수) ~ 10.07 (수) 4회 기능사 필기 합격 발표
    10.08 (목) ~ 10.08 (목) 3회 기능사 실기 합격 발표(2차)
    10.12 (월) ~ 10.15 (목) 4회 기능사 실기 접수
    10.17 (토) ~ 10.17 (토) 신입학 상담의 날(1차)
    10.23 (금) ~ 10.23 (금) 교내 스포츠클럽 한마당
    10.31 (토) ~ 10.31 (토) 신입학 상담의 날(2차)
    11 월 11.04 (수) ~ 11.06 (금) 신입학 특별전형 원서접수(예정)
    11.10 (화) ~ 11.10 (화) 신입학 특별전형 면접일(예정)
    11.14 (토) ~ 12.02 (수) 4회 기능사 실기 시험
    11.19 (목) ~ 11.19 (목) 2027 대학수학능력시험
    11.23 (월) ~ 11.24 (화) 신입학 일반전형 원서접수(예정)
    11.27 (금) ~ 11.27 (금) 27학년도 신입생 예비소집일(재학생은 재량휴업일)
    11.27 (금) ~ 11.27 (금) 27학년도 신입생 예비소집일
    12 월 12.08 (화) ~ 12.11 (금) 2-2차 정기시험
    12.11 (금) ~ 12.11 (금) 4회 기능사 실기 합격 발표(1차)
    12.14 (월) ~ 12.15 (화) 2학년 도제캠프
    12.18 (금) ~ 12.18 (금) 4회 기능사 실기 합격 발표(2차)
    12.21 (월) ~ 12.22 (화) 디자인&아트 전시회
    """

    private static func parse(_ source: String) -> [ScheduleEventData] {
        source
            .split(separator: "\n")
            .compactMap { parseLine(String($0)) }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                if lhs.endDate != rhs.endDate {
                    return lhs.endDate < rhs.endDate
                }
                return lhs.title < rhs.title
            }
    }

    private static func parseLine(_ line: String) -> ScheduleEventData? {
        var parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        if parts.count >= 2, parts[1] == "월" {
            parts.removeFirst(2)
        }

        guard parts.count >= 6,
              let startDate = makeDate(from: parts[0]),
              let endDate = makeDate(from: parts[3]) else {
            return nil
        }

        return ScheduleEventData(
            startDate: startDate,
            endDate: endDate,
            title: parts.dropFirst(5).joined(separator: " ")
        )
    }

    private static func makeDate(from value: String) -> Date? {
        let pieces = value.split(separator: ".").compactMap { Int($0) }
        guard pieces.count == 2 else { return nil }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: pieces[0], day: pieces[1]))
    }
}

enum HomeTab: String, CaseIterable, Identifiable {
    case today = "오늘"
    case week = "이번 주"
    case timetable = "시간표"
    case schedule = "일정표"

    var id: String { rawValue }
}

enum ThemePreference: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var next: ThemePreference {
        switch self {
        case .system:
            return .light
        case .light:
            return .dark
        case .dark:
            return .system
        }
    }
}
