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

@main
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
