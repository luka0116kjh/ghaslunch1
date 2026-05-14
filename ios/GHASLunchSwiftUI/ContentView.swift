import SwiftUI

struct ContentView: View {
    @AppStorage("themePreference") private var themePreference = ThemePreference.system.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("ghasStudentName") private var studentName = ""
    @AppStorage("ghasStudentId") private var studentId = ""
    @State private var selectedTab: HomeTab = .today
    @State private var selectedGrade = 1
    @State private var selectedClass = 1
    @State private var mealViewMode: MealViewMode = .today
    @State private var scheduleViewMode: ScheduleViewMode = .current
    @State private var isShowingStudentCode = false
    @State private var isShowingPrivacy = false
    @State private var visitorCountText = "..."
    @State private var notificationStatusMessage: String?

    @Environment(\.colorScheme) private var scheme

    private let todayMeals = [
        MealCardData(title: "중식", menu: "쌀밥\n미역국\n닭갈비\n배추김치\n요구르트", calories: "812.4 kcal"),
        MealCardData(title: "석식", menu: "김치볶음밥\n계란국\n치킨너겟\n깍두기", calories: "745.1 kcal")
    ]

    private let tomorrowMeals = [
        MealCardData(title: "중식", menu: "잡곡밥\n된장찌개\n제육볶음\n상추겉절이\n배추김치", calories: "801.7 kcal"),
        MealCardData(title: "석식", menu: "카레라이스\n유부장국\n왕새우튀김\n깍두기", calories: "779.5 kcal")
    ]

    private let weekMeals = [
        WeeklyMealData(date: "월요일", meals: [
            MealCardData(title: "중식", menu: "쌀밥\n미역국\n닭갈비\n배추김치", calories: "812.4 kcal"),
            MealCardData(title: "석식", menu: "김치볶음밥\n계란국\n치킨너겟\n깍두기", calories: "745.1 kcal")
        ]),
        WeeklyMealData(date: "화요일", meals: [
            MealCardData(title: "중식", menu: "잡곡밥\n된장찌개\n제육볶음\n깍두기", calories: "801.7 kcal"),
            MealCardData(title: "석식", menu: "카레라이스\n유부장국\n왕새우튀김", calories: "779.5 kcal")
        ])
    ]

    private let timetable = [
        TimetableRowData(period: "1교시", subject: "국어"),
        TimetableRowData(period: "2교시", subject: "수학"),
        TimetableRowData(period: "3교시", subject: "자동차 일반"),
        TimetableRowData(period: "4교시", subject: "영어"),
        TimetableRowData(period: "5교시", subject: "체육"),
        TimetableRowData(period: "6교시", subject: "진로")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    AppHeader(
                        title: "경기자동차과학고등학교",
                        subtitle: formattedToday,
                        secondaryTitle: "QR",
                        secondaryActionLabel: "학생 코드 보기",
                        secondaryAction: {
                            isShowingStudentCode = true
                        },
                        actionIcon: "square.and.arrow.up",
                        actionLabel: "공유하기",
                        action: shareApp
                    )

                    PillTabBar(selection: $selectedTab)
                        .padding(.bottom, 20)

                    actionBar
                        .padding(.bottom, notificationStatusMessage == nil ? 16 : 8)

                    if let notificationStatusMessage {
                        Text(notificationStatusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.subText(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 16)
                    }

                    currentContent

                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.background(scheme).ignoresSafeArea())
            .navigationDestination(isPresented: $isShowingPrivacy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $isShowingStudentCode) {
                StudentCodeSheet(studentName: $studentName, studentId: $studentId)
            }
            .task {
                await refreshVisitorCount()
            }
        }
    }

    @ViewBuilder
    private var currentContent: some View {
        switch selectedTab {
        case .today:
            mealList
        case .week:
            weeklyMealList
        case .timetable:
            timetableView
        case .schedule:
            scheduleView
        }
    }

    private var visibleMeals: [MealCardData] {
        mealViewMode == .today ? todayMeals : tomorrowMeals
    }

    private var mealList: some View {
        VStack(spacing: 16) {
            InfoCard {
                HStack(spacing: 12) {
                    SectionTitle(title: mealViewMode.title)

                    Spacer()

                    SwitchPillButton(title: mealViewMode.switchTitle) {
                        mealViewMode = mealViewMode == .today ? .tomorrow : .today
                    }
                }
            }

            ForEach(visibleMeals) { meal in
                InfoCard {
                    SectionTitle(title: meal.title)
                        .padding(.bottom, 18)

                    Text(meal.menu)
                        .font(.system(size: 16, weight: .regular))
                        .lineSpacing(6)
                        .foregroundStyle(AppTheme.text(scheme).opacity(0.9))

                    Text(meal.calories)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.subText(scheme))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 20)
                }
            }
        }
    }

    private var scheduleView: some View {
        InfoCard {
            HStack(spacing: 12) {
                SectionTitle(title: scheduleViewMode.title)

                Spacer()

                SwitchPillButton(title: scheduleViewMode.switchTitle) {
                    scheduleViewMode = scheduleViewMode == .current ? .next : .current
                }
            }
            .padding(.bottom, 18)

            if visibleScheduleEvents.isEmpty {
                Text("등록된 행사 일정이 없습니다.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.subText(scheme))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedScheduleEvents, id: \.month) { group in
                        Text("\(group.month)월")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.primary)
                            .clipShape(Capsule())
                            .padding(.top, group.month == groupedScheduleEvents.first?.month ? 0 : 22)
                            .padding(.bottom, 10)

                        ForEach(Array(group.events.enumerated()), id: \.element.id) { index, event in
                            scheduleRow(event)

                            if index != group.events.count - 1 {
                                Divider()
                                    .background(AppTheme.border(scheme))
                            }
                        }
                    }
                }
            }
        }
    }

    private func scheduleRow(_ event: ScheduleEventData) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 6) {
                Text("\(Calendar.current.component(.day, from: event.startDate))")
                    .font(.system(size: 21, weight: .heavy))

                Text(weekday(event.startDate))
                    .font(.system(size: 12, weight: .bold))
                    .opacity(0.72)
            }
            .foregroundStyle(status(for: event).isActive ? AppTheme.primaryText : AppTheme.text(scheme))
            .frame(width: 54, height: 60)
            .background(status(for: event).isActive ? AppTheme.primary : AppTheme.pill(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 10) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    Text(status(for: event).label)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(status(for: event).isActive ? AppTheme.primaryText : AppTheme.subText(scheme))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(status(for: event).isActive ? AppTheme.primary : AppTheme.pill(scheme))
                        .clipShape(Capsule())
                }

                Text("\(eventRange(event)) · \(category(for: event))")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.subText(scheme))
            }
        }
        .padding(.vertical, 16)
    }

    private var weeklyMealList: some View {
        InfoCard {
            SectionTitle(title: "이번 주 급식")
                .padding(.bottom, 18)

            VStack(spacing: 0) {
                ForEach(Array(weekMeals.enumerated()), id: \.element.id) { index, meal in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(meal.date)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(AppTheme.primary)

                        ForEach(Array(meal.meals.enumerated()), id: \.element.id) { mealIndex, dayMeal in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dayMeal.title)
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(AppTheme.text(scheme))

                                Text(dayMeal.menu)
                                    .font(.system(size: 14, weight: .regular))
                                    .lineSpacing(2)
                                    .foregroundStyle(AppTheme.text(scheme))
                                    .fixedSize(horizontal: false, vertical: true)

                                if !dayMeal.calories.isEmpty {
                                    Text(dayMeal.calories)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.subText(scheme))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.top, mealIndex == 0 ? 0 : 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, index == weekMeals.count - 1 ? 0 : 12)

                    if index != weekMeals.count - 1 {
                        Divider()
                            .background(AppTheme.border(scheme))
                            .padding(.bottom, 20)
                    }
                }
            }
        }
    }

    private var timetableView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Picker("학년", selection: $selectedGrade) {
                    ForEach(1...3, id: \.self) { grade in
                        Text("\(grade)학년").tag(grade)
                    }
                }

                Picker("반", selection: $selectedClass) {
                    ForEach(1...8, id: \.self) { schoolClass in
                        Text("\(schoolClass)반").tag(schoolClass)
                    }
                }
            }
            .pickerStyle(.menu)
            .padding(6)
            .background(AppTheme.pill(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            InfoCard {
                SectionTitle(title: "시간표")
                    .padding(.bottom, 10)

                Text("\(selectedGrade)학년 \(selectedClass)반")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.subText(scheme))
                    .padding(.bottom, 8)

                ForEach(Array(timetable.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 16) {
                        Text(row.period)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.subText(scheme))
                            .frame(width: 56)
                            .padding(.vertical, 5)
                            .background(AppTheme.pill(scheme))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(row.subject)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))

                        Spacer()
                    }
                    .padding(.vertical, 14)

                    if index != timetable.count - 1 {
                        Divider()
                            .background(AppTheme.border(scheme))
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                toggleNotifications()
            } label: {
                Image(systemName: notificationsEnabled ? "bell.fill" : "bell")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(notificationsEnabled ? AppTheme.primaryText : AppTheme.pillText(scheme))
                    .frame(width: 42, height: 38)
                    .background(notificationsEnabled ? AppTheme.primary : AppTheme.pill(scheme))
                    .clipShape(Capsule())
            }
            .accessibilityLabel("알림 설정")

            Button {
                cycleTheme()
            } label: {
                Image(systemName: currentTheme.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.pillText(scheme))
                    .frame(width: 42, height: 38)
                    .background(AppTheme.pill(scheme))
                    .clipShape(Capsule())
            }
            .accessibilityLabel("테마 변경")

            Spacer()
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("누적 방문자: \(visitorCountText)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.subText(scheme).opacity(0.8))

            Text("이 앱은 학교 공식 앱이 아닌 학생 제작 정보 제공 앱입니다.")
                .font(.system(size: 10, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.subText(scheme).opacity(0.75))
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Button("개인정보처리방침") {
                    isShowingPrivacy = true
                }

                Link("GITHUB: luka", destination: URL(string: "https://github.com/luka0116kjh")!)
            }
            .font(.system(size: 12, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.subText(scheme).opacity(0.5))
        }
        .padding(.top, 40)
        .padding(.bottom, 30)
    }

    private var visibleScheduleEvents: [ScheduleEventData] {
        let calendar = Calendar.current
        let start = scheduleBaseMonth
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start

        return ScheduleEventData.events.filter { event in
            calendar.startOfDay(for: event.startDate) <= calendar.startOfDay(for: end)
                && calendar.startOfDay(for: event.endDate) >= calendar.startOfDay(for: start)
        }
    }

    private var groupedScheduleEvents: [ScheduleMonthGroup] {
        let grouped = Dictionary(grouping: visibleScheduleEvents) {
            Calendar.current.component(.month, from: $0.startDate)
        }

        return grouped.keys.sorted().map { month in
            ScheduleMonthGroup(month: month, events: grouped[month] ?? [])
        }
    }

    private var scheduleBaseMonth: Date {
        let calendar = Calendar.current
        let today = Date()
        let base = scheduleViewMode == .next
            ? (calendar.date(byAdding: .month, value: 1, to: today) ?? today)
            : today
        let components = calendar.dateComponents([.year, .month], from: base)
        return calendar.date(from: components) ?? today
    }

    private func status(for event: ScheduleEventData) -> (label: String, isActive: Bool) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: event.startDate)
        let end = calendar.startOfDay(for: event.endDate)

        if today >= start && today <= end {
            return (calendar.isDate(start, inSameDayAs: end) ? "오늘" : "진행중", true)
        }
        if start > today {
            return ("예정", false)
        }
        return ("완료", false)
    }

    private func category(for event: ScheduleEventData) -> String {
        let title = event.title
        if title.contains("공휴일") || title.contains("노동절") || title.contains("현충일") || title.contains("추석") || title.contains("개천절") || title.contains("재량휴업일") {
            return "휴일"
        }
        if title.contains("시험") || title.contains("정기시험") || title.contains("평가") || title.contains("검정") || title.contains("합격") || title.contains("접수") {
            return "시험/검정"
        }
        if title.contains("신입학") || title.contains("입학식") || title.contains("예비소집") || title.contains("원서접수") || title.contains("면접") {
            return "입학/전형"
        }
        return "행사"
    }

    private func eventRange(_ event: ScheduleEventData) -> String {
        if Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
            return dotDate(event.startDate)
        }
        return "\(dotDate(event.startDate)) ~ \(dotDate(event.endDate))"
    }

    private func dotDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private var formattedToday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd EEEE"
        return formatter.string(from: Date())
    }

    private var currentTheme: ThemePreference {
        ThemePreference(rawValue: themePreference) ?? .system
    }

    private func cycleTheme() {
        themePreference = currentTheme.next.rawValue
    }

    private func toggleNotifications() {
        if notificationsEnabled {
            notificationsEnabled = false
            notificationStatusMessage = "앱 알림이 취소되었습니다."

            Task {
                await NativeNotificationService.disableNotifications()
            }
            return
        }

        notificationStatusMessage = "앱 알림 권한을 요청하는 중입니다."

        Task {
            let granted = await NativeNotificationService.requestAuthorization()
            await MainActor.run {
                notificationsEnabled = granted
                notificationStatusMessage = granted
                    ? "앱 알림 설정이 완료되었습니다."
                    : "알림 권한이 없어 앱 알림을 받을 수 없습니다."
            }
        }
    }

    private func refreshVisitorCount() async {
        do {
            let count = try await VisitorCounterService.incrementCount()
            await MainActor.run {
                visitorCountText = NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
            }
        } catch {
            if let count = try? await VisitorCounterService.fetchCount() {
                await MainActor.run {
                    visitorCountText = NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
                }
            } else {
                await MainActor.run {
                    visitorCountText = "확인 불가"
                }
            }
        }
    }

    private func shareApp() {
        // Connect this to ShareLink or UIKit activity presentation in the host app.
    }
}

private enum MealViewMode {
    case today
    case tomorrow

    var title: String {
        switch self {
        case .today:
            return "오늘의 급식"
        case .tomorrow:
            return "내일의 급식"
        }
    }

    var switchTitle: String {
        switch self {
        case .today:
            return "내일의 급식"
        case .tomorrow:
            return "오늘의 급식"
        }
    }
}

private enum ScheduleViewMode {
    case current
    case next

    var title: String {
        switch self {
        case .current:
            return "이번달 일정표"
        case .next:
            return "다음달 일정표"
        }
    }

    var switchTitle: String {
        switch self {
        case .current:
            return "다음달 일정표"
        case .next:
            return "이번달 일정표"
        }
    }
}

private struct ScheduleMonthGroup {
    let month: Int
    let events: [ScheduleEventData]
}

private struct StudentCodeSheet: View {
    @Binding var studentName: String
    @Binding var studentId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var draftName = ""
    @State private var draftId = ""
    @State private var errorMessage: String?

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedId: String {
        draftId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canRenderBarcode: Bool {
        isValidStudentId(trimmedId)
    }

    private func isValidStudentId(_ value: String) -> Bool {
        value.range(of: #"^[1-3]0[1-8](0[1-9]|1[0-9]|2[0-4])$"#, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    studentCard

                    VStack(spacing: 12) {
                        TextField("이름", text: $draftName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        TextField("학번", text: $draftId)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: draftId) { newValue in
                                let filtered = newValue.filter(\.isNumber)
                                if filtered != newValue {
                                    draftId = String(filtered.prefix(5))
                                } else if newValue.count > 5 {
                                    draftId = String(newValue.prefix(5))
                                }
                            }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("초기화") {
                            studentName = ""
                            studentId = ""
                            draftName = ""
                            draftId = ""
                            errorMessage = nil
                        }
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(AppTheme.text(scheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(AppTheme.pill(scheme))
                        .clipShape(Capsule())

                        PrimaryButton(title: "저장", systemImage: "checkmark") {
                            guard canRenderBarcode else {
                                errorMessage = "학번은 1~3학년, 01~08반, 01~24번 형식으로 입력해 주세요."
                                return
                            }

                            studentName = trimmedName
                            studentId = trimmedId
                            errorMessage = nil
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background(scheme).ignoresSafeArea())
            .navigationTitle("학생 코드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                draftName = studentName
                draftId = studentId
            }
        }
    }

    private var studentCard: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white)
                .frame(height: 72)

            Divider()

            Text(trimmedName.isEmpty ? "이름" : trimmedName)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

            Divider()

            Text(trimmedId.isEmpty ? "학번" : trimmedId)
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)

            Divider()

            if canRenderBarcode {
                Code39BarcodeView(value: trimmedId)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
            } else {
                Text("학번을 입력하면 바코드가 표시됩니다.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 46)
            }
        }
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct Code39BarcodeView: View {
    let value: String

    private var modules: [BarcodeModule] {
        Code39Encoder.modules(for: value)
    }

    var body: some View {
        GeometryReader { proxy in
            let totalUnits = max(1, modules.reduce(0) { $0 + $1.units })
            let unitWidth = proxy.size.width / CGFloat(totalUnits)

            HStack(spacing: 0) {
                ForEach(Array(modules.enumerated()), id: \.offset) { _, module in
                    if module.isBar {
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: max(1, CGFloat(module.units) * unitWidth))
                    } else {
                        Color.clear
                            .frame(width: CGFloat(module.units) * unitWidth)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .frame(height: 72)
        .accessibilityLabel("학번 바코드")
    }
}

private struct BarcodeModule {
    let isBar: Bool
    let units: Int
}

private enum Code39Encoder {
    private static let patterns: [Character: String] = [
        "0": "nnnwwnwnw",
        "1": "wnnwnnnnw",
        "2": "nnwwnnnnw",
        "3": "wnwwnnnnn",
        "4": "nnnwwnnnw",
        "5": "wnnwwnnnn",
        "6": "nnwwwnnnn",
        "7": "nnnwnnwnw",
        "8": "wnnwnnwnn",
        "9": "nnwwnnwnn",
        "*": "nwnnwnwnn"
    ]

    static func modules(for rawValue: String) -> [BarcodeModule] {
        let encoded = "*\(rawValue.uppercased())*"
        var modules: [BarcodeModule] = []

        for character in encoded {
            guard let pattern = patterns[character] else {
                continue
            }

            for (index, width) in pattern.enumerated() {
                modules.append(BarcodeModule(isBar: index.isMultiple(of: 2), units: width == "w" ? 3 : 1))
            }

            modules.append(BarcodeModule(isBar: false, units: 1))
        }

        return modules
    }
}

#Preview {
    ContentView()
}
