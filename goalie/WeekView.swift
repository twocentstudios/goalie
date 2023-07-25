import Dependencies
import Foundation
import SwiftUI
import SystemColors

final class WeekStore: ObservableObject {
    @Dependency(\.date.now) var now
    @Dependency(\.timeZone) var timeZone
    @Dependency(\.locale) var locale

    @Published var topicWeek: TopicWeek
    let calendar: Calendar

    init(topic: Topic) {
        @Dependency(\.date.now) var now
        @Dependency(\.timeZone) var timeZone
        @Dependency(\.locale) var locale

        // Use Gregorian calendar to ensure consistency
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        self.calendar = calendar

        let week = Week(date: now, calendar: calendar)
        let topicWeek = TopicWeek(topic: topic, week: week)
        self.topicWeek = topicWeek
    }

    func previousWeekTapped() {
        guard let newWeek = topicWeek.week.previousWeek(calendar: calendar) else {
            assertionFailure("Previous week has no entries")
            return
        }
        var newTopicWeek = topicWeek
        newTopicWeek.week = newWeek
        topicWeek = newTopicWeek
    }

    func nextWeekTapped() {
        guard let newWeek = topicWeek.week.nextWeek(calendar: calendar) else {
            assertionFailure("Next week has no entries")
            return
        }
        var newTopicWeek = topicWeek
        newTopicWeek.week = newWeek
        topicWeek = newTopicWeek
    }
}

extension Week {
    init(date: Date, calendar: Calendar) {
        let inputDateComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .month], from: date)
        self.init(inputDateComponents: inputDateComponents, calendar: calendar)
    }

    /// inputDateComponents should contain `.yearForWeekOfYear`, `.weekOfYear`, `.month`.
    init(inputDateComponents: DateComponents, calendar: Calendar) {
        assert(inputDateComponents.yearForWeekOfYear != nil)
        assert(inputDateComponents.weekOfYear != nil)
        assert(inputDateComponents.month != nil)

        // Get the date components for the first day of the relevant week
        var firstDayOfWeekComponents = inputDateComponents
        firstDayOfWeekComponents.weekday = 1
        firstDayOfWeekComponents.calendar = calendar
        let firstDayOfWeekDate = firstDayOfWeekComponents.date!

        // Use the date of the first day of the week to calculate the day
        firstDayOfWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .month, .day], from: firstDayOfWeekDate)

        yearForWeekOfYear = inputDateComponents.yearForWeekOfYear!
        weekOfYear = inputDateComponents.weekOfYear!
        month = inputDateComponents.month!
        firstDayOfWeek = firstDayOfWeekComponents.day!
        weekDayIntervals = Self.weekDayIntervals(dateComponents: inputDateComponents, calendar: calendar)
    }

    static func dayInterval(for inputDateComponents: DateComponents) -> DayInterval {
        assert(inputDateComponents.yearForWeekOfYear != nil)
        assert(inputDateComponents.weekOfYear != nil)
        assert(inputDateComponents.month != nil)
        assert(inputDateComponents.weekday != nil)
        assert(inputDateComponents.calendar != nil)
        let calendar = inputDateComponents.calendar!

        let start = inputDateComponents.date!
        assert(start == calendar.startOfDay(for: start))

        let almostOneDayComponents = DateComponents(day: 1, second: -1)
        guard let end = calendar.date(byAdding: almostOneDayComponents, to: start, wrappingComponents: false) else {
            fatalError("Couldn't get endDate from startDate: \(start)")
        }

        return DayInterval(startDate: start, endDate: end)
    }

    var firstMoment: Date {
        weekDayIntervals[0].startDate
    }

    var lastMoment: Date {
        weekDayIntervals[6].endDate
    }

    var range: Range<Date> {
        firstMoment ..< lastMoment
    }

    // Returns first day of week
    var dateComponents: DateComponents {
        var components = DateComponents()
        components.yearForWeekOfYear = yearForWeekOfYear
        components.weekOfYear = weekOfYear
        components.month = month
        components.weekday = 1
        components.day = firstDayOfWeek
        return components
    }

    func previousWeek(calendar: Calendar) -> Week? {
        let minusOneWeekDurationComponents = DateComponents(weekOfYear: -1)
        return weekByAddingDateComponents(durationComponents: minusOneWeekDurationComponents, calendar: calendar)
    }

    func nextWeek(calendar: Calendar) -> Week? {
        let plusOneWeekDurationComponents = DateComponents(weekOfYear: 1)
        return weekByAddingDateComponents(durationComponents: plusOneWeekDurationComponents, calendar: calendar)
    }

    func weekByAddingDateComponents(durationComponents: DateComponents, calendar: Calendar) -> Week? {
        let components = dateComponents
        guard let currentDate = calendar.date(from: components) else { return nil }
        guard let nextWeekDate = calendar.date(byAdding: durationComponents, to: currentDate, wrappingComponents: true) else { return nil }
        let nextWeek = Week(date: nextWeekDate, calendar: calendar)
        return nextWeek
    }

    /// Returns an array of exactly 7 DayIntervals corresponding to the 7 days of the week starting on Sunday
    /// The DayInterval start date is midnight, the DayInterval end date is the last second of the same day.
    static func weekDayIntervals(dateComponents: DateComponents, calendar: Calendar) -> [DayInterval] {
        assert(dateComponents.yearForWeekOfYear != nil)
        assert(dateComponents.weekOfYear != nil)
        assert(dateComponents.month != nil)

        let startDateComponents = dateComponents
        var dayIntervals: [DayInterval] = []
        for weekday in 1 ... 7 {
            var weekdayComponents = startDateComponents
            weekdayComponents.weekday = weekday
            weekdayComponents.day = nil
            weekdayComponents.calendar = calendar
            let dayInterval = Self.dayInterval(for: weekdayComponents)
            dayIntervals.append(dayInterval)
        }
        assert(dayIntervals.count == 7)
        return dayIntervals
    }
}

struct TopicWeek: Equatable, Identifiable {
    var id: String { "\(topic.id):\(week.id)" }
    var topic: Topic
    var week: Week
}

struct Week: Equatable, Identifiable {
    var id: String { "\(yearForWeekOfYear):\(weekOfYear)" } // 2023:32
    var yearForWeekOfYear: Int
    var weekOfYear: Int
    var month: Int
    var firstDayOfWeek: Int // 9 -> July 9th
    var weekDayIntervals: [DayInterval]
}

struct DayInterval: Equatable {
    var startDate: Date // Midnight
    var endDate: Date // Midnight of next day minus 1 second
}

struct WeekViewData {
    struct Day: Equatable, Identifiable {
        var id: String { dayTitle }
        let goalRatioSymbolName: String
        let dayTitle: String
        let duration: String
        let goal: String
    }
    let title: String
    let subtitle: String
    let previousWeekDisabled: Bool
    let nextWeekDisabled: Bool
    let days: [Day]
}

struct WeekScreen: View {
    @ObservedObject var store: WeekStore

    private var viewData: WeekViewData {
        let topicWeek = store.topicWeek
        let title = "Week " + topicWeek.week.firstMoment.formatted(.dateTime.week(.defaultDigits))
        let subtitle: String = topicWeek.week.range.formatted(.interval.year().month(.wide).day().locale(store.locale))
        let viewData = WeekViewData(
            title: title,
            subtitle: subtitle,
            previousWeekDisabled: false, // TODO:
            nextWeekDisabled: false, // TODO:
            days: topicWeek.week.weekDayIntervals.map { interval -> WeekViewData.Day in
                let dayTitle = interval.startDate.formatted(.dateTime.month(.twoDigits).day(.twoDigits))

                let emptyInterval = "--:--:--"

                let durationInterval: TimeInterval?
                let duration: String
                if store.now < interval.startDate {
                    duration = emptyInterval
                    durationInterval = nil
                } else {
                    let validDurationInterval = topicWeek.topic.totalIntervalBetween(start: interval.startDate, end: interval.endDate)
                    let durationDuration = Duration.seconds(validDurationInterval)
                    duration = durationDuration.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 0, roundFractionalSeconds: .up)))
                    durationInterval = validDurationInterval
                }

                let goalInterval = topicWeek.topic.goal(for: interval.startDate)
                let goal: String
                if let goalDuration = goalInterval?.duration {
                    let duration = Duration.seconds(goalDuration)
                    goal = duration.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 0, roundFractionalSeconds: .up)))
                } else {
                    goal = emptyInterval
                }

                let goalRatioSymbolName: String
                if let durationInterval, let goalDuration = goalInterval?.duration {
                    let ratio = durationInterval / goalDuration
                    switch ratio {
                    case ...0: goalRatioSymbolName = "circle"
                    case 0 ..< 1: goalRatioSymbolName = "circle.bottomhalf.fill"
                    case 1...: goalRatioSymbolName = "circle.fill"
                    default: fatalError()
                    }
                } else {
                    goalRatioSymbolName = "circle.dotted"
                }

                let day = WeekViewData.Day(
                    goalRatioSymbolName: goalRatioSymbolName,
                    dayTitle: dayTitle,
                    duration: duration,
                    goal: goal
                )
                return day
            }
        )
        return viewData
    }

    var body: some View {
        WeekView(viewData: viewData, previousWeekTapped: store.previousWeekTapped, nextWeekTapped: store.nextWeekTapped)
    }
}

struct WeekView: View {
    let viewData: WeekViewData
    var previousWeekTapped: (() -> Void)?
    var nextWeekTapped: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    previousWeekTapped?()
                } label: {
                    Image(systemName: "arrow.left.circle")
                        .font(.body)
                        .foregroundColor(Color.label)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .disabled(viewData.previousWeekDisabled)
                Spacer()
                VStack(spacing: 1) {
                    Text(viewData.title)
                        .font(.headline)
                    Text(viewData.subtitle)
                        .font(.subheadline)
                }
                Spacer()
                Button {
                    nextWeekTapped?()
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.body)
                        .foregroundColor(Color.label)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .disabled(viewData.nextWeekDisabled)
            }

            Spacer().frame(height: 8)

            VStack(spacing: 6) {
                ForEach(viewData.days) { day in
                    HStack(spacing: 0) {
                        Image(systemName: day.goalRatioSymbolName) // "circle.fill" "circle.bottomhalf.fill"
                            .font(.caption)
                            .foregroundColor(Color.label)
                        Text(day.dayTitle)
                            .monospacedDigit()
                            .padding(.horizontal, 4)
                        Spacer()
                        Text(day.duration)
                            .monospaced()
                        Text("/")
                            .foregroundColor(Color.tertiaryLabel)
                            .monospaced()
                            .padding(.horizontal, 2)
                        Text(day.goal)
                            .foregroundColor(Color.tertiaryLabel)
                            .monospaced()
                    }
                }
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }
}

struct WeekView_Previews: PreviewProvider {
    static var previews: some View {
        WeekView(viewData: .mock)
            .frame(width: 250)
        WeekScreen(store: .init(topic: .new))
            .frame(width: 250)
    }
}

extension WeekViewData {
    static let mock: Self = .init(
        title: "Week 1",
        subtitle: "July 9-15, 2023",
        previousWeekDisabled: false,
        nextWeekDisabled: true,
        days: [
            .init(goalRatioSymbolName: "circle", dayTitle: "7/9", duration: "00:00", goal: "02:00"),
            .init(goalRatioSymbolName: "circle.fill", dayTitle: "7/10", duration: "03:31", goal: "02:00"),
            .init(goalRatioSymbolName: "circle.bottomhalf.fill", dayTitle: "7/11", duration: "02:00", goal: "03:00"),
            .init(goalRatioSymbolName: "circle.dotted", dayTitle: "7/12", duration: "--:--", goal: "03:00"),
            .init(goalRatioSymbolName: "circle.dotted", dayTitle: "7/13", duration: "--:--", goal: "03:00"),
            .init(goalRatioSymbolName: "circle.dotted", dayTitle: "7/14", duration: "--:--", goal: "03:00"),
            .init(goalRatioSymbolName: "circle.dotted", dayTitle: "7/15", duration: "--:--", goal: "03:00"),
        ]
    )
}
