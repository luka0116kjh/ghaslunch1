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
        static let masterGateMigrated = "native_notifications_master_gate_migrated_v1"
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

    var mealEnabled: Bool
    var timetableEnabled: Bool
    var schoolNoticeEnabled: Bool
    var mealTime: Date
    var timetableTime: Date
    var schoolNoticeTime: Date

    // Derived aggregate: notifications are "on" when at least one category is enabled.
    // There is no separate master gate anymore; categories work independently.
    var enabled: Bool {
        mealEnabled || timetableEnabled || schoolNoticeEnabled
    }

    /// Turns every category on or off at once (the "모든 알림 켜기 / 끄기" convenience action).
    mutating func setAllCategories(enabled: Bool) {
        mealEnabled = enabled
        timetableEnabled = enabled
        schoolNoticeEnabled = enabled
    }

    static func load(defaults: UserDefaults = .standard) -> NativeNotificationSettings {
        NativeNotificationSettings(
            mealEnabled: defaults.object(forKey: Key.mealEnabled) as? Bool ?? false,
            timetableEnabled: defaults.object(forKey: Key.timetableEnabled) as? Bool ?? false,
            schoolNoticeEnabled: defaults.object(forKey: Key.schoolNoticeEnabled) as? Bool ?? false,
            mealTime: savedTime(forKey: Key.mealTime, defaultHour: 11, minute: 0, defaults: defaults),
            timetableTime: savedTime(forKey: Key.timetableTime, defaultHour: 7, minute: 30, defaults: defaults),
            schoolNoticeTime: savedTime(forKey: Key.schoolNoticeTime, defaultHour: 18, minute: 0, defaults: defaults)
        )
    }

    func save(defaults: UserDefaults = .standard) {
        // `enabled` is derived; persisted only as the aggregate for backward compatibility.
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

    /// One-time migration away from the old master-gate model. Previously a single master flag
    /// gated every category; now each category is independent. To preserve each user's prior
    /// effective state we collapse `effectiveCategory = oldMaster && storedCategory` exactly once.
    /// Run this after `prepareLegacyMigrationIfNeeded()` so legacy values are already in place.
    @discardableResult
    static func migrateMasterGateIfNeeded(defaults: UserDefaults = .standard) -> Bool {
        guard !defaults.bool(forKey: Key.masterGateMigrated) else {
            return false
        }
        let oldMaster = defaults.bool(forKey: Key.enabled)
        let meal = oldMaster && (defaults.object(forKey: Key.mealEnabled) as? Bool ?? true)
        let timetable = oldMaster && (defaults.object(forKey: Key.timetableEnabled) as? Bool ?? true)
        let schoolNotice = oldMaster && (defaults.object(forKey: Key.schoolNoticeEnabled) as? Bool ?? true)
        defaults.set(meal, forKey: Key.mealEnabled)
        defaults.set(timetable, forKey: Key.timetableEnabled)
        defaults.set(schoolNotice, forKey: Key.schoolNoticeEnabled)
        defaults.set(meal || timetable || schoolNotice, forKey: Key.enabled)
        defaults.set(true, forKey: Key.masterGateMigrated)
        return true
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
    private static let schoolDayWeekdays = [2, 3, 4, 5, 6]

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

        var identifiers: [String] {
            switch self {
            case .meal:
                return [identifier] + NativeNotificationService.schoolDayWeekdays.map { "\(identifier)_\($0)" }
            case .timetable, .schoolNotice:
                return [identifier]
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

    /// Runs at launch. Ensures the (idempotent) migrations have applied, then reconciles the
    /// pending per-category schedules with the stored state without prompting for permission.
    /// Mirrors Android's launch-time `scheduleSelectedNotifications()` so both stay consistent.
    static func reconcileLegacyMigrationIfNeeded() async {
        // Order matters: legacy copy must run before the master-gate collapse reads the old master.
        NativeNotificationSettings.prepareLegacyMigrationIfNeeded()
        NativeNotificationSettings.migrateMasterGateIfNeeded()
        NativeNotificationSettings.markLegacyMigrationCompleted()

        let settings = NativeNotificationSettings.load()
        let authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let canDeliver = authorizationStatus == .authorized ||
            authorizationStatus == .provisional ||
            authorizationStatus == .ephemeral

        guard settings.enabled && canDeliver else {
            cancelAll()
            return
        }

        for category in Category.allCases {
            if category.isEnabled(in: settings) {
                schedule(category, at: category.time(in: settings))
            } else {
                cancel(category)
            }
        }
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    private static func schedule(_ category: Category, at time: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: category.identifiers)

        let content = UNMutableNotificationContent()
        content.title = category.title
        content.body = category.fallbackBody
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        switch category {
        case .meal:
            for weekday in schoolDayWeekdays {
                var weekdayComponents = components
                weekdayComponents.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: weekdayComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(category.identifier)_\(weekday)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        case .timetable, .schoolNotice:
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: category.identifier,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }

        // TODO: Use Firebase Cloud Functions + FCM/APNs scheduled push for server-driven delivery.
        // TODO: Refresh one-shot daily notifications when reliable daily content is available.
        // TODO: Replace generic fallbacks with real daily meal/timetable/notice content safely.
    }

    private static func cancel(_ category: Category) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: category.identifiers)
    }

    private static func cancelAll() {
        UNUserNotificationCenter.current()
            .removeAllPendingNotificationRequests()
    }
}
