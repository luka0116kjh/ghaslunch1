import Foundation
import UserNotifications

enum VisitorCounterService {
    private static let visitCountURL = URL(string: "https://ghaslunch1-default-rtdb.asia-southeast1.firebasedatabase.app/stats/visitCount.json")!
    private static let maxIncrementAttempts = 3

    static func fetchCount() async throws -> Int {
        var request = URLRequest(url: visitCountURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return decodeCount(from: data)
    }

    static func incrementCount() async throws -> Int {
        for _ in 0..<maxIncrementAttempts {
            var readRequest = URLRequest(url: visitCountURL)
            readRequest.cachePolicy = .reloadIgnoringLocalCacheData
            readRequest.setValue("true", forHTTPHeaderField: "X-Firebase-ETag")

            let (readData, readResponse) = try await URLSession.shared.data(for: readRequest)
            let readHTTPResponse = try validate(readResponse)
            let etag = readHTTPResponse.value(forHTTPHeaderField: "ETag")
            let nextCount = decodeCount(from: readData) + 1

            var writeRequest = URLRequest(url: visitCountURL)
            writeRequest.httpMethod = "PUT"
            writeRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let etag {
                writeRequest.setValue(etag, forHTTPHeaderField: "if-match")
            }
            writeRequest.httpBody = Data(String(nextCount).utf8)

            let (writeData, writeResponse) = try await URLSession.shared.data(for: writeRequest)
            if let httpResponse = writeResponse as? HTTPURLResponse, httpResponse.statusCode == 412 {
                continue
            }

            try validate(writeResponse)
            return decodeCount(from: writeData)
        }

        throw VisitorCounterError.tooManyConflicts
    }

    @discardableResult
    private static func validate(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VisitorCounterError.invalidResponse
        }
        return httpResponse
    }

    private static func decodeCount(from data: Data) -> Int {
        (try? JSONDecoder().decode(Int.self, from: data)) ?? 0
    }
}

enum VisitorCounterError: Error {
    case invalidResponse
    case tooManyConflicts
}

struct NativeNotificationSettings {
    private enum Key {
        static let enabled = "native_notifications_enabled"
        static let mealEnabled = "native_notifications_meal_enabled"
        static let timetableEnabled = "native_notifications_timetable_enabled"
        static let schoolNoticeEnabled = "native_notifications_school_notice_enabled"
        static let mealTime = "native_notifications_meal_time"
        static let timetableTime = "native_notifications_timetable_time"
        static let schoolNoticeTime = "native_notifications_school_notice_time"
        static let legacyMigrationCompleted = "native_notifications_legacy_migration_completed_v1"
    }

    private enum LegacyKey {
        static let enabled = "nativeNotificationsEnabled"
        static let mealEnabled = "nativeNotificationsMeal"
        static let timetableEnabled = "nativeNotificationsTimetable"
        static let schoolNoticeEnabled = "nativeNotificationsSchoolNotice"
        static let mealHour = "nativeNotificationsMealHour"
        static let mealMinute = "nativeNotificationsMealMinute"
        static let timetableHour = "nativeNotificationsTimetableHour"
        static let timetableMinute = "nativeNotificationsTimetableMinute"
        static let schoolNoticeHour = "nativeNotificationsSchoolNoticeHour"
        static let schoolNoticeMinute = "nativeNotificationsSchoolNoticeMinute"
    }

    var enabled: Bool
    var mealEnabled: Bool
    var timetableEnabled: Bool
    var schoolNoticeEnabled: Bool
    var mealTime: Date
    var timetableTime: Date
    var schoolNoticeTime: Date

    static func load(defaults: UserDefaults = .standard) -> NativeNotificationSettings {
        NativeNotificationSettings(
            enabled: defaults.bool(forKey: Key.enabled),
            mealEnabled: defaults.object(forKey: Key.mealEnabled) as? Bool ?? true,
            timetableEnabled: defaults.object(forKey: Key.timetableEnabled) as? Bool ?? true,
            schoolNoticeEnabled: defaults.object(forKey: Key.schoolNoticeEnabled) as? Bool ?? true,
            mealTime: savedTime(forKey: Key.mealTime, defaultHour: 11, minute: 0, defaults: defaults),
            timetableTime: savedTime(forKey: Key.timetableTime, defaultHour: 7, minute: 30, defaults: defaults),
            schoolNoticeTime: savedTime(forKey: Key.schoolNoticeTime, defaultHour: 18, minute: 0, defaults: defaults)
        )
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: Key.enabled)
        defaults.set(mealEnabled, forKey: Key.mealEnabled)
        defaults.set(timetableEnabled, forKey: Key.timetableEnabled)
        defaults.set(schoolNoticeEnabled, forKey: Key.schoolNoticeEnabled)
        defaults.set(mealTime, forKey: Key.mealTime)
        defaults.set(timetableTime, forKey: Key.timetableTime)
        defaults.set(schoolNoticeTime, forKey: Key.schoolNoticeTime)
    }

    @discardableResult
    static func prepareLegacyMigrationIfNeeded(defaults: UserDefaults = .standard) -> Bool {
        guard !defaults.bool(forKey: Key.legacyMigrationCompleted) else {
            return false
        }

        let legacyKeys = [
            LegacyKey.enabled,
            LegacyKey.mealEnabled,
            LegacyKey.timetableEnabled,
            LegacyKey.schoolNoticeEnabled,
            LegacyKey.mealHour,
            LegacyKey.mealMinute,
            LegacyKey.timetableHour,
            LegacyKey.timetableMinute,
            LegacyKey.schoolNoticeHour,
            LegacyKey.schoolNoticeMinute
        ]
        guard legacyKeys.contains(where: { defaults.object(forKey: $0) != nil }) else {
            defaults.set(true, forKey: Key.legacyMigrationCompleted)
            return false
        }

        copyLegacyBoolean(from: LegacyKey.enabled, to: Key.enabled, defaults: defaults)
        copyLegacyBoolean(from: LegacyKey.mealEnabled, to: Key.mealEnabled, defaults: defaults)
        copyLegacyBoolean(from: LegacyKey.timetableEnabled, to: Key.timetableEnabled, defaults: defaults)
        copyLegacyBoolean(from: LegacyKey.schoolNoticeEnabled, to: Key.schoolNoticeEnabled, defaults: defaults)
        copyLegacyTime(
            hourKey: LegacyKey.mealHour,
            minuteKey: LegacyKey.mealMinute,
            targetKey: Key.mealTime,
            defaultHour: 11,
            defaultMinute: 0,
            defaults: defaults
        )
        copyLegacyTime(
            hourKey: LegacyKey.timetableHour,
            minuteKey: LegacyKey.timetableMinute,
            targetKey: Key.timetableTime,
            defaultHour: 7,
            defaultMinute: 30,
            defaults: defaults
        )
        copyLegacyTime(
            hourKey: LegacyKey.schoolNoticeHour,
            minuteKey: LegacyKey.schoolNoticeMinute,
            targetKey: Key.schoolNoticeTime,
            defaultHour: 18,
            defaultMinute: 0,
            defaults: defaults
        )
        return true
    }

    static func markLegacyMigrationCompleted(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Key.legacyMigrationCompleted)
    }

    private static func savedTime(
        forKey key: String,
        defaultHour: Int,
        minute: Int,
        defaults: UserDefaults
    ) -> Date {
        if let date = defaults.object(forKey: key) as? Date {
            return date
        }
        return Calendar.current.date(
            bySettingHour: defaultHour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private static func copyLegacyBoolean(from sourceKey: String, to targetKey: String, defaults: UserDefaults) {
        guard defaults.object(forKey: targetKey) == nil,
              defaults.object(forKey: sourceKey) != nil else {
            return
        }
        defaults.set(defaults.bool(forKey: sourceKey), forKey: targetKey)
    }

    private static func copyLegacyTime(
        hourKey: String,
        minuteKey: String,
        targetKey: String,
        defaultHour: Int,
        defaultMinute: Int,
        defaults: UserDefaults
    ) {
        guard defaults.object(forKey: targetKey) == nil,
              defaults.object(forKey: hourKey) != nil || defaults.object(forKey: minuteKey) != nil else {
            return
        }

        let storedHour = defaults.object(forKey: hourKey) == nil ? defaultHour : defaults.integer(forKey: hourKey)
        let storedMinute = defaults.object(forKey: minuteKey) == nil ? defaultMinute : defaults.integer(forKey: minuteKey)
        let hour = (0...23).contains(storedHour) ? storedHour : defaultHour
        let minute = (0...59).contains(storedMinute) ? storedMinute : defaultMinute
        if let time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) {
            defaults.set(time, forKey: targetKey)
        }
    }
}

enum NativeNotificationService {
    private enum Category: CaseIterable {
        case meal
        case timetable
        case schoolNotice

        var identifier: String {
            switch self {
            case .meal: return "meal_daily_notification"
            case .timetable: return "timetable_daily_notification"
            case .schoolNotice: return "school_notice_daily_notification"
            }
        }

        var title: String {
            switch self {
            case .meal: return "급식 알림"
            case .timetable: return "시간표 알림"
            case .schoolNotice: return "학교 공지 알림"
            }
        }

        var fallbackBody: String {
            switch self {
            case .meal: return "오늘 급식을 확인해보세요."
            case .timetable: return "오늘 시간표를 확인해보세요."
            case .schoolNotice: return "오늘 학교 공지를 확인해보세요."
            }
        }

        func isEnabled(in settings: NativeNotificationSettings) -> Bool {
            switch self {
            case .meal: return settings.mealEnabled
            case .timetable: return settings.timetableEnabled
            case .schoolNotice: return settings.schoolNoticeEnabled
            }
        }

        func time(in settings: NativeNotificationSettings) -> Date {
            switch self {
            case .meal: return settings.mealTime
            case .timetable: return settings.timetableTime
            case .schoolNotice: return settings.schoolNoticeTime
            }
        }
    }

    static func applySavedSettings() async -> Bool {
        guard NativeNotificationSettings.load().enabled else {
            cancelAll()
            return true
        }

        guard await requestAuthorization() else {
            cancelAll()
            return false
        }

        // Permission requests can outlive UI changes; always schedule from the latest stored state.
        let settings = NativeNotificationSettings.load()
        guard settings.enabled else {
            cancelAll()
            return true
        }

        for category in Category.allCases {
            if category.isEnabled(in: settings) {
                schedule(category, at: category.time(in: settings))
            } else {
                cancel(category)
            }
        }
        return true
    }

    static func reconcileLegacyMigrationIfNeeded() async {
        guard NativeNotificationSettings.prepareLegacyMigrationIfNeeded() else {
            return
        }

        let settings = NativeNotificationSettings.load()
        guard settings.enabled else {
            cancelAll()
            NativeNotificationSettings.markLegacyMigrationCompleted()
            return
        }

        let authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard authorizationStatus == .authorized ||
                authorizationStatus == .provisional ||
                authorizationStatus == .ephemeral else {
            cancelAll()
            NativeNotificationSettings.markLegacyMigrationCompleted()
            return
        }

        for category in Category.allCases {
            if category.isEnabled(in: settings) {
                schedule(category, at: category.time(in: settings))
            } else {
                cancel(category)
            }
        }
        NativeNotificationSettings.markLegacyMigrationCompleted()
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func disableNotifications() async {
        var settings = NativeNotificationSettings.load()
        settings.enabled = false
        settings.save()
        cancelAll()
    }

    private static func schedule(_ category: Category, at time: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [category.identifier])

        let content = UNMutableNotificationContent()
        content.title = category.title
        content.body = category.fallbackBody
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: category.identifier,
            content: content,
            trigger: trigger
        )
        center.add(request)

        // TODO: Use Firebase Cloud Functions + FCM/APNs scheduled push for server-driven delivery.
        // TODO: Refresh one-shot daily notifications when reliable daily content is available.
        // TODO: Replace generic fallbacks with real daily meal/timetable/notice content safely.
    }

    private static func cancel(_ category: Category) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [category.identifier])
    }

    private static func cancelAll() {
        UNUserNotificationCenter.current()
            .removeAllPendingNotificationRequests()
    }
}
