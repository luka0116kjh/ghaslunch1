import AppIntents
import SwiftUI
import WidgetKit

// MARK: - State (mirrors Android MealWidgetState)

enum MealWidgetState {
    case available(String)
    case empty
    case error

    var displayText: String {
        switch self {
        case .available(let menu): return menu
        case .empty: return "오늘 등록된 급식이 없어요"   // widget_today_meal_empty
        case .error: return "급식을 불러오지 못했어요"     // widget_today_meal_error
        }
    }
}

struct TodayMealEntry: TimelineEntry {
    let date: Date
    let state: MealWidgetState
}

// MARK: - Refresh intent (interactive button, iOS 17+ only)

@available(iOS 17.0, *)
struct RefreshMealIntent: AppIntent {
    static var title: LocalizedStringResource = "급식 새로고침"

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "GHASLunchWidget")
        return .result()
    }
}

// MARK: - Timeline provider

struct TodayMealProvider: TimelineProvider {
    private static let sampleMenu = "쌀밥 · 미역국 ·\n제육볶음 · 배추김치 ·\n요구르트"

    func placeholder(in context: Context) -> TodayMealEntry {
        TodayMealEntry(date: Date(), state: .available(Self.sampleMenu))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayMealEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayMealEntry>) -> Void) {
        Task {
            let entry = TodayMealEntry(date: Date(), state: await TodayMealService.todayMealState())
            // Match Android updatePeriodMillis = 1_800_000 (30 min)
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

// MARK: - View

struct GHASLunchWidgetEntryView: View {
    var entry: TodayMealEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 10)

            Text(entry.state.displayText)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Self.menuColor)
                .lineSpacing(4)
                .minimumScaleFactor(0.78)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            Text(Self.dateFormatter.string(from: entry.date))
                .font(.system(size: 11))
                .foregroundColor(Self.dateColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // Match Android paddingStart/Top/End/Bottom = 18/14/16/14
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 16))
        // No widgetURL: a widget without one opens the containing app on tap.
        // The app registers no URL scheme / associated domain, so an https widgetURL
        // would open Safari instead. Default tap-to-open-app matches Android's root tap.
        .widgetCardBackground()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("오늘 급식")   // widget_today_meal_title
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Self.titleColor)
                .lineLimit(1)

            Spacer(minLength: 8)

            refreshButton
        }
    }

    @ViewBuilder
    private var refreshButton: some View {
        // Interactive widget buttons require iOS 17+. On iOS 16 the whole widget is a
        // single tap target, so no standalone refresh control is possible.
        if #available(iOS 17.0, *) {
            Button(intent: RefreshMealIntent()) {
                refreshGlyph
            }
            .buttonStyle(.plain)
        }
    }

    private var refreshGlyph: some View {
        Text("↻")   // widget_today_meal_refresh
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(Self.refreshTint)
            .frame(width: 32, height: 32)
            .background(
                Self.refreshPill,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }

    // Fixed light palette, matching the Android widget hex values exactly.
    private static let titleColor = Color(hex: 0x1C1C1E)
    private static let menuColor = Color(hex: 0x262626)
    private static let dateColor = Color(hex: 0x747A82)
    private static let refreshTint = Color(hex: 0x2F8CFF)
    private static let refreshPill = Color(hex: 0xEAF3FF)
    static let cardColor = Color(hex: 0xF9FAFB)

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter
    }()
}

private extension View {
    @ViewBuilder
    func widgetCardBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                GHASLunchWidgetEntryView.cardColor
            }
        } else {
            background(GHASLunchWidgetEntryView.cardColor)
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Widget

struct GHASLunchWidget: Widget {
    let kind = "GHASLunchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayMealProvider()) { entry in
            GHASLunchWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("오늘 급식")
        .description("경기자동차과학고 오늘 중식을 바로 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - NEIS meal service (parsing identical to Android TodayMealWidgetProvider)

enum TodayMealService {
    private static let mealURL = URL(string: "https://open.neis.go.kr/hub/mealServiceDietInfo")!
    private static let officeCode = "J10"
    private static let schoolCode = "7530908"

    static func todayMealState() async -> MealWidgetState {
        guard let items = await fetchTodayMenuItems() else { return .error }
        guard !items.isEmpty else { return .empty }
        return .available(formatMenuLines(items))
    }

    /// Returns nil on network/HTTP failure (→ error), [] when no menu rows (→ empty).
    private static func fetchTodayMenuItems() async -> [String]? {
        let ymd = Self.ymdFormatter.string(from: Date())
        var components = URLComponents(url: mealURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "Type", value: "json"),
            URLQueryItem(name: "ATPT_OFCDC_SC_CODE", value: officeCode),
            URLQueryItem(name: "SD_SCHUL_CODE", value: schoolCode),
            URLQueryItem(name: "MLSV_YMD", value: ymd),
            URLQueryItem(name: "pSize", value: "100"),
        ]
        guard let url = components?.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return parseMealItems(data)
        } catch {
            return nil
        }
    }

    private static func parseMealItems(_ data: Data) -> [String] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sections = root["mealServiceDietInfo"] as? [[String: Any]]
        else {
            return []
        }

        let rows = sections.compactMap { $0["row"] as? [[String: Any]] }.first ?? []
        var lunch: [String]?
        var firstAny: [String]?
        for row in rows {
            let items = cleanMenuItems(row["DDISH_NM"] as? String)
            guard !items.isEmpty else { continue }
            if firstAny == nil { firstAny = items }
            if row["MMEAL_SC_CODE"] as? String == "2" {
                lunch = items
                break
            }
        }
        return lunch ?? firstAny ?? []
    }

    private static func cleanMenuItems(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }
        var text = raw.replacingOccurrences(
            of: "\\([^)]*\\)", with: "", options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive]
        )
        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func formatMenuLines(_ items: [String]) -> String {
        stride(from: 0, to: items.count, by: 2).map { index in
            let line = items[index..<min(index + 2, items.count)].joined(separator: " · ")
            return index + 2 < items.count ? "\(line) ·" : line
        }
        .joined(separator: "\n")
    }

    private static let ymdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

// MARK: - Timetable state (mirrors Android TimetableWidgetState)

struct TimetablePeriod: Identifiable {
    let period: Int
    let subject: String
    var id: Int { period }
}

enum TimetableWidgetState {
    case loading
    case available(periods: [TimetablePeriod], grade: String, classNum: String)
    case empty(grade: String, classNum: String)
    case classNotConfigured
    case error(grade: String, classNum: String)
}

struct TodayTimetableEntry: TimelineEntry {
    let date: Date
    let state: TimetableWidgetState
}

// MARK: - Timetable refresh intent (interactive button, iOS 17+ only)

@available(iOS 17.0, *)
struct RefreshTimetableIntent: AppIntent {
    static var title: LocalizedStringResource = "시간표 새로고침"

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "GHASTimetableWidget")
        return .result()
    }
}

// MARK: - Timetable timeline provider

struct TodayTimetableProvider: TimelineProvider {
    private static let sample: [TimetablePeriod] = [
        .init(period: 1, subject: "프로그래밍"),
        .init(period: 2, subject: "자동차 전기"),
        .init(period: 3, subject: "영어"),
        .init(period: 4, subject: "자료구조"),
        .init(period: 5, subject: "체육"),
        .init(period: 6, subject: "진로"),
        .init(period: 7, subject: "동아리"),
    ]

    func placeholder(in context: Context) -> TodayTimetableEntry {
        TodayTimetableEntry(
            date: Date(),
            state: .available(periods: Self.sample, grade: "3", classNum: "2")
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayTimetableEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayTimetableEntry>) -> Void) {
        Task {
            let entry = TodayTimetableEntry(date: Date(), state: await TodayTimetableService.resolveState())
            // Match Android updatePeriodMillis = 1_800_000 (30 min).
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

// MARK: - Timetable view

struct GHASTimetableWidgetEntryView: View {
    var entry: TodayTimetableEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 8)

            content

            Spacer(minLength: 8)

            Text(Self.dateFormatter.string(from: entry.date))
                .font(.system(size: 11))
                .foregroundColor(Self.dateColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // Same card metrics as the meal widget so the two read as one set.
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 16))
        .widgetCardBackground()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("오늘 시간표")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Self.titleColor)
                    .lineLimit(1)
                if let classLabel {
                    Text(classLabel)
                        .font(.system(size: 12))
                        .foregroundColor(Self.dateColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            refreshButton
        }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .available(let periods, _, _):
            periodList(periods)
        case .loading:
            message("시간표를 불러오는 중...")
        case .empty:
            message("오늘 등록된 시간표가 없어요")
        case .classNotConfigured:
            message("앱에서 학년과 반을 먼저 설정해 주세요")
        case .error:
            message("시간표를 불러오지 못했어요")
        }
    }

    // 세로형: 1~7교시를 한 열로 쌓는다(Android 4x6 위젯과 동일한 인상).
    private func periodList(_ periods: [TimetablePeriod]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(periods.prefix(7)) { item in
                HStack(spacing: 10) {
                    Text("\(item.period)교시")
                        .font(.system(size: 14))
                        .foregroundColor(Self.periodColor)
                        .frame(width: 52, alignment: .leading)
                    Text(item.subject)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Self.subjectColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(Self.periodColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var classLabel: String? {
        switch entry.state {
        case .available(_, let grade, let classNum),
             .empty(let grade, let classNum),
             .error(let grade, let classNum):
            guard !grade.isEmpty, !classNum.isEmpty else { return nil }
            return "\(grade)학년 \(classNum)반"
        case .loading, .classNotConfigured:
            return nil
        }
    }

    @ViewBuilder
    private var refreshButton: some View {
        if #available(iOS 17.0, *) {
            Button(intent: RefreshTimetableIntent()) {
                refreshGlyph
            }
            .buttonStyle(.plain)
        }
    }

    private var refreshGlyph: some View {
        Text("↻")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(Self.refreshTint)
            .frame(width: 32, height: 32)
            .background(
                Self.refreshPill,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }

    // Fixed light palette, identical hex values to the meal widget.
    private static let titleColor = Color(hex: 0x1C1C1E)
    private static let subjectColor = Color(hex: 0x262626)
    private static let periodColor = Color(hex: 0x6B7280)
    private static let dateColor = Color(hex: 0x747A82)
    private static let refreshTint = Color(hex: 0x2F8CFF)
    private static let refreshPill = Color(hex: 0xEAF3FF)

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter
    }()
}

// MARK: - Timetable widget

struct GHASTimetableWidget: Widget {
    let kind = "GHASTimetableWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTimetableProvider()) { entry in
            GHASTimetableWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("오늘 시간표")
        .description("설정한 학년·반의 오늘 시간표를 바로 확인합니다.")
        // 세로형 큰 위젯: 1~7교시를 한 열로 표시(급식 위젯과 세트 느낌 유지).
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Widget bundle (급식 + 시간표를 한 확장에 등록)

@main
struct GHASWidgetBundle: WidgetBundle {
    var body: some Widget {
        GHASLunchWidget()
        GHASTimetableWidget()
    }
}

// MARK: - NEIS timetable service (앱이 push한 App Group 캐시 + NEIS hisTimetable 하이브리드)

enum TodayTimetableService {
    // ContentView.swift의 Coordinator가 쓰는 값과 반드시 일치해야 한다.
    private static let appGroupId = "group.kr.hs.ghas.lunch"
    private static let keyGrade = "widget_timetable_grade"
    private static let keyClass = "widget_timetable_class"
    private static let keyCacheJson = "widget_timetable_cache_json"

    private static let timetableURL = URL(string: "https://open.neis.go.kr/hub/hisTimetable")!
    private static let officeCode = "J10"
    private static let schoolCode = "7530908"

    static func resolveState() async -> TimetableWidgetState {
        let defaults = UserDefaults(suiteName: appGroupId)
        let grade = defaults?.string(forKey: keyGrade)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let classNum = defaults?.string(forKey: keyClass)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !grade.isEmpty, !classNum.isEmpty else { return .classNotConfigured }

        // 1) 앱이 push한 오늘자 캐시(NEIS+보정+휴일/방학 병합 결과)가 있으면 최우선(권위 있음).
        if let cached = cachedToday(defaults) {
            if cached.state == "available", !cached.periods.isEmpty {
                return .available(periods: cached.periods, grade: grade, classNum: classNum)
            }
            if cached.state == "empty" {
                return .empty(grade: grade, classNum: classNum)
            }
        }

        // 2) 캐시가 없을 때만 로컬 주말/방학 판정을 적용한다.
        if isWeekend() || isSchoolBreak() { return .empty(grade: grade, classNum: classNum) }

        // 3) NEIS + 번들 보정 시간표를 교시별로 병합해 자체 계산.
        //    앱 화면과 동일하게 NEIS 우선, 빈 교시는 보정 시간표로 채운다.
        let neis = await fetchTimetable(grade: grade, classNum: classNum)
        var neisByPeriod: [Int: String] = [:]
        (neis ?? []).forEach { neisByPeriod[$0.period] = $0.subject }
        let fallback = TimetableFallback.periods(grade: grade, classNum: classNum)

        var merged: [TimetablePeriod] = []
        for period in 1...7 {
            let subject = neisByPeriod[period] ?? fallback[period] ?? ""
            let trimmed = subject.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, trimmed != "공강" {
                merged.append(TimetablePeriod(period: period, subject: trimmed))
            }
        }
        if !merged.isEmpty {
            return .available(periods: merged, grade: grade, classNum: classNum)
        }

        // 3) 병합 결과가 없고 NEIS도 실패했으면 오류, 그 외엔 없음.
        return (neis == nil && fallback.isEmpty)
            ? .error(grade: grade, classNum: classNum)
            : .empty(grade: grade, classNum: classNum)
    }

    private static func isWeekend() -> Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 || weekday == 7 // 1 = Sunday, 7 = Saturday
    }

    // 웹 SCHEDULE_SOURCE의 방학식~개학식 구간을 번들 상수로 미러링(배포 전에도 방학이면 "없음").
    private static let breakRanges: [(String, String)] = [
        ("20260721", "20260819"), // 여름방학(방학식~개학식)
        ("20270106", "20270228"), // 겨울방학(겨울방학식~, 개학 미정 근사)
    ]

    private static func isSchoolBreak() -> Bool {
        let today = ymd(Date())
        return breakRanges.contains { today >= $0.0 && today <= $0.1 }
    }

    private struct CachedTimetable {
        let state: String
        let periods: [TimetablePeriod]
    }

    private static func cachedToday(_ defaults: UserDefaults?) -> CachedTimetable? {
        guard
            let json = defaults?.string(forKey: keyCacheJson),
            let data = json.data(using: .utf8),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let date = root["date"] as? String, date == ymd(Date()),
            let state = root["state"] as? String
        else {
            return nil
        }
        let rawPeriods = (root["periods"] as? [[String: Any]]) ?? []
        let periods = rawPeriods.compactMap { item -> TimetablePeriod? in
            guard let subject = item["subject"] as? String, !subject.isEmpty else { return nil }
            let period = (item["period"] as? Int)
                ?? (item["period"] as? String).flatMap { Int($0) }
            guard let period else { return nil }
            return TimetablePeriod(period: period, subject: subject)
        }
        return CachedTimetable(state: state, periods: periods)
    }

    /// NEIS hisTimetable 직접 조회. 네트워크/HTTP 실패 시 nil, 행이 없으면 빈 배열.
    private static func fetchTimetable(grade: String, classNum: String) async -> [TimetablePeriod]? {
        var components = URLComponents(url: timetableURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "Type", value: "json"),
            URLQueryItem(name: "ATPT_OFCDC_SC_CODE", value: officeCode),
            URLQueryItem(name: "SD_SCHUL_CODE", value: schoolCode),
            URLQueryItem(name: "ALL_TI_YMD", value: ymd(Date())),
            URLQueryItem(name: "GRADE", value: grade),
            URLQueryItem(name: "CLASS_NM", value: classNum),
            URLQueryItem(name: "pSize", value: "100"),
        ]
        guard let url = components?.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return parseTimetable(data)
        } catch {
            return nil
        }
    }

    private static func parseTimetable(_ data: Data) -> [TimetablePeriod] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sections = root["hisTimetable"] as? [[String: Any]]
        else {
            return []
        }
        let rows = sections.compactMap { $0["row"] as? [[String: Any]] }.first ?? []
        var byPeriod: [Int: String] = [:]
        for row in rows {
            let period = (row["PERIO"] as? String).flatMap { Int($0) }
                ?? (row["PERIO"] as? Int)
            guard let period, (1...7).contains(period) else { continue }
            let subject = clean(row["ITRT_CNTNT"] as? String)
            guard !subject.isEmpty, byPeriod[period] == nil else { continue }
            byPeriod[period] = subject
        }
        return byPeriod.keys.sorted().map { TimetablePeriod(period: $0, subject: byPeriod[$0] ?? "") }
    }

    /// 웹 cleanTimetableSubject와 동일하게 별표를 제거하고 다듬는다.
    private static func clean(_ raw: String?) -> String {
        (raw ?? "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func ymd(_ date: Date) -> String {
        ymdFormatter.string(from: date)
    }

    private static let ymdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

// MARK: - 번들 보정 시간표 (src/data/classTimetable2026.js에서 생성, 웹과 동일 데이터)

enum TimetableFallback {
    // "학년-반" -> 요일(월~금) -> [최대 7 과목]
    private static let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]

    private static let table: [String: [String: [String]]] = {
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: [String: [String]]]
        else { return [:] }
        return parsed
    }()

    static func periods(grade: String, classNum: String) -> [Int: String] {
        let weekday = Calendar.current.component(.weekday, from: Date()) // 1=일 ... 7=토
        let dayName = weekdayNames[weekday - 1]
        guard let subjects = table["\(grade)-\(classNum)"]?[dayName] else { return [:] }
        var result: [Int: String] = [:]
        for (index, subject) in subjects.prefix(7).enumerated() {
            let trimmed = subject.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { result[index + 1] = trimmed }
        }
        return result
    }

    private static let json = #"{"1-1":{"월":["국사","영어","과학","과학","수학","체육","사회"],"화":["국사","수학","국어","사회","과1","국2",""],"수":["국사","영어","수학","진로","사회","미술","미술"],"목":["정보","정보","정보","수학","영어","기관","기관"],"금":["미술","체육","국어","자율","자율","창체","창체"]},"1-2":{"월":["국사","국어","기관","기관","체육","수학","영어"],"화":["사회","과학","과1","국2","국사","수학",""],"수":["수학","사회","미술","미술","과학","국어","영어"],"목":["수학","진로","체육","사회","미술","영어","국사"],"금":["정보","정보","정보","자율","자율","창체","창체"]},"1-3":{"월":["정보","정보","정보","영어","진로","미술","미술"],"화":["과학","국사","체육","국어","수학","사회",""],"수":["영어","과1","국2","사회","수학","체육","과학"],"목":["수학","국어","국사","미술","기관","기관","사회"],"금":["영어","수학","국사","자율","자율","창체","창체"]},"1-4":{"월":["기관","기관","사회","국2","수학","국사","과학"],"화":["국어","영어","수학","진로","미술","미술",""],"수":["과1","국사","체육","영어","사회","과학","수학"],"목":["미술","영어","국사","국어","수학","체육","사회"],"금":["정보","정보","정보","자율","자율","창체","창체"]},"1-5":{"월":["영어","국사","미술","미술","국2","사회","수학"],"화":["정보","정보","정보","수학","진로","과1",""],"수":["수학","국어","기관","기관","체육","영어","사회"],"목":["체육","과학","영어","국사","수학","사회","미술"],"금":["국어","국사","과학","자율","자율","창체","창체"]},"1-6":{"월":["수학","체육","국사","국어","영어","과학","사회"],"화":["국사","미술","미술","과1","수학","영어",""],"수":["국2","수학","진로","체육","국어","사회","국사"],"목":["정보","정보","정보","영어","과학","사회","수학"],"금":["기관","기관","미술","자율","자율","창체","창체"]},"1-7":{"월":["과학","사회","체육","수학","국어","영어","국사"],"화":["영어","정보","정보","정보","사회","수학",""],"수":["국어","수학","영어","과1","국사","프로","프로"],"목":["수학","체육","과학","국사","프로","프로","프로"],"금":["사회","국1","진로","자율","자율","창체","창체"]},"1-8":{"월":["정보","정보","정보","수학","사회","진로","국어"],"화":["디일","디일","디일","국사","국1","수학",""],"수":["국사","체육","과1","수학","영어","디일","디일"],"목":["영어","사회","수학","과학","체육","국사","국어"],"금":["과학","영어","사회","자율","자율","창체","창체"]},"2-1":{"월":["대수","섀정","문학","운동","진로","영어","도장"],"화":["엔정","전정","음악","문학","회로","회로",""],"수":["영어","운동","전차","대수","차정","음악","문1"],"목":["도장","전정","전차","전차","차정","섀정","엔정"],"금":["음악","영어","대수","자율","자율","창체","창체"]},"2-2":{"월":["문1","영어","대수","음악","섀정","진로","차정"],"화":["영어","엔정","문학","음악","회로","회로",""],"수":["음악","문학","운동","대수","전정","영어","도장"],"목":["전차","전차","전정","차정","도장","엔정","섀정"],"금":["전차","운동","대수","자율","자율","창체","창체"]},"2-3":{"월":["영어","문학","도장","도장","대수","전정","전정"],"화":["섀정","섀정","엔정","엔정","섀시","섀시",""],"수":["문학","영어","차정","차정","전차","전차","전기"],"목":["문1","운동","대수","진로","영어","음악","음악"],"금":["운동","대수","음악","자율","자율","창체","창체"]},"2-4":{"월":["대수","음악","전정","전정","영어","운동","문1"],"화":["전차","전차","전기","운동","섀시","섀시",""],"수":["차정","차정","대수","영어","음악","엔정","엔정"],"목":["진로","음악","대수","영어","문학","도장","도장"],"금":["섀정","섀정","문학","자율","자율","창체","창체"]},"2-5":{"월":["영어","전차","전차","전기","문학","음악","대수"],"화":["차정","차정","전정","전정","섀시","섀시",""],"수":["섀정","섀정","음악","영어","도장","도장","대수"],"목":["운동","문학","음악","문1","대수","진로","영어"],"금":["엔정","엔정","운동","자율","자율","창체","창체"]},"2-6":{"월":["응1","응1","대수","중국","커1","커1","운동"],"화":["데프","데프","운동","대수","영어","문학",""],"수":["커넥","커넥","중국","문학","응개","응개","응개"],"목":["응1","응1","영어","진로","대수","중국","문1"],"금":["영어","데프","데프","자율","자율","창체","창체"]},"2-7":{"월":["운동","영어","데프","데프","중국","문학","대수"],"화":["응1","응1","응1","응1","커넥","커넥",""],"수":["대수","중국","데프","데프","운동","문1","영어"],"목":["문학","영어","응개","응개","응개","커넥","커넥"],"금":["진로","중국","대수","자율","자율","창체","창체"]},"2-8":{"월":["중국","운동","튜1","튜1","영어","대수","진로"],"화":["자실","자실","컴그","컴그","중국","영어",""],"수":["대수","영어","튜닝","튜닝","문학","운동","중국"],"목":["컴그","컴그","튜닝","튜닝","문1","실무","실무"],"금":["문학","대수","컴그","자율","자율","창체","창체"]},"3-1":{"월":["전정","전정","섀정","섀정","도장","도장","실영"],"화":["도장","도장","전차","전차","엔진","엔진",""],"수":["전정","전정","섀정","섀정","주행","차정","차정"],"목":["진로","실영","성공","성공","운동","차정","차정"],"금":["주행","전차","엔진","엔진","자율","창체","창체"]},"3-2":{"월":["차정","차정","성공","성공","엔진","엔진","전차"],"화":["섀정","섀정","차정","차정","전정","전정",""],"수":["전차","전차","도장","도장","엔진","엔진","주행"],"목":["도장","도장","진로","운동","실영","실영","주행"],"금":["전정","전정","섀정","섀정","자율","창체","창체"]},"3-3":{"월":["도실","도실","엔진","엔진","차정","차정","진로"],"화":["실영","운동","섀정","섀정","주행","주행",""],"수":["엔정","엔정","전장","전장","전기","섀시","섀시"],"목":["차체","차체","도장","도장","전차","전차","실영"],"금":["성공","성공","전정","전정","자율","창체","창체"]},"3-4":{"월":["엔정","엔정","차정","차정","실영","섀정","섀정"],"화":["전장","전장","전정","전정","도장","도장",""],"수":["도실","도실","엔진","엔진","진로","성공","성공"],"목":["전차","전차","차체","차체","섀시","섀시","운동"],"금":["전기","실영","주행","주행","자율","창체","창체"]},"3-5":{"월":["응개","응개","성공","성공","주행","주행","실영"],"화":["커넥","커넥","커넥","커넥","운동","진로",""],"수":["전기","전기","응개","응개","주행","응1","응1"],"목":["엔진","엔진","엔정","엔정","실영","전차","전차"],"금":["도실","도실","도장","도장","자율","창체","창체"]},"3-6":{"월":["커1","커1","전차","전차","주행","응1","응1"],"화":["응개","응개","진로","운동","주행","주행",""],"수":["성공","성공","커넥","커넥","실영","전기","전기"],"목":["섀시","섀시","섀정","섀정","응개","응개","실영"],"금":["차정","차정","차체","차체","자율","창체","창체"]},"3-7":{"월":["주행","주행","응개","응개","응화","응화","응화"],"화":["성공","성공","진로","실영","자인","자인",""],"수":["응1","응1","응1","자인","자인","화1","화1"],"목":["커넥","커넥","화1","화1","응1","응1","응1"],"금":["커넥","커넥","실영","운동","자율","창체","창체"]},"3-8":{"월":["제디","제디","제디","시디","시디","성공","성공"],"화":["튜닝","튜닝","실영","진로","시디","시디",""],"수":["시디","시디","시디","제디","제디","튜1","튜1"],"목":["튜닝","튜닝","제디","제디","제디","튜2","튜2"],"금":["튜2","튜1","운동","실영","자율","창체","창체"]}}"#
}
