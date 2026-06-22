import SwiftUI
import WidgetKit

struct TodayMealEntry: TimelineEntry {
    let date: Date
    let menuText: String
    let isPlaceholder: Bool
}

struct TodayMealProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayMealEntry {
        TodayMealEntry(
            date: Date(),
            menuText: "쌀밥 · 미역국 ·\n제육볶음 · 배추김치 ·\n요구르트",
            isPlaceholder: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayMealEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayMealEntry>) -> Void) {
        Task {
            let entry = TodayMealEntry(
                date: Date(),
                menuText: await TodayMealService.todayMenuText(),
                isPlaceholder: false
            )
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

struct GHASLunchWidgetEntryView: View {
    var entry: TodayMealEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("오늘 급식")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(Self.dateFormatter.string(from: entry.date))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(entry.menuText)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .minimumScaleFactor(0.78)
                .lineLimit(4)

            Spacer(minLength: 0)
        }
        .widgetCardBackground()
        .padding(16)
    }

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
                Color(.systemBackground)
            }
        } else {
            background(Color(.systemBackground))
        }
    }
}

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

enum TodayMealService {
    private static let mealURL = URL(string: "https://open.neis.go.kr/hub/mealServiceDietInfo")!
    private static let officeCode = "J10"
    private static let schoolCode = "7530908"

    static func todayMenuText() async -> String {
        guard let items = await fetchTodayMenuItems(), !items.isEmpty else {
            return "오늘 등록된 급식이 없어요"
        }
        return formatMenuLines(items)
    }

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
