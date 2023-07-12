import Dependencies
import Foundation
import SwiftUI
import SystemColors

final class WeekStore: ObservableObject {
//    @Dependency(\.uuid) var uuid
    // @Dependency(\.mainRunLoop) var mainRunLoop

    @Published var topicWeek: TopicWeek
    let dateFormatter: DateFormatter

    init(topic: Topic) {
        @Dependency(\.date.now) var now
        @Dependency(\.calendar) var calendar
        @Dependency(\.timeZone) var timeZone
        
        // TODO: should we use Gregorian Calendar for calendar?

        let week = Week(date: now, calendar: calendar)
        let topicWeek = TopicWeek(topic: topic, week: week)
        self.topicWeek = topicWeek

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = timeZone
        self.dateFormatter = dateFormatter
    }
}

extension Week {
    init(date: Date, calendar: Calendar) {
        // Get components for the relevant week
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

        // Get the date components for the last day of the relevant week
        var lastDayOfWeekComponents = inputDateComponents
        lastDayOfWeekComponents.weekday = 7
        lastDayOfWeekComponents.calendar = calendar
        let lastDayOfWeekDate = lastDayOfWeekComponents.date!

        lastDayOfWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .month, .day], from: lastDayOfWeekDate)
        // Use the date of the first day of the week to calculate the day

        yearForWeekOfYear = inputDateComponents.yearForWeekOfYear!
        weekOfYear = inputDateComponents.weekOfYear!
        month = inputDateComponents.month!
        firstDayOfWeek = firstDayOfWeekComponents.day!
        lastDayOfWeek = lastDayOfWeekComponents.day!
    }

    static func dayInterval(for inputDateComponents: DateComponents) -> DayInterval {
        assert(inputDateComponents.yearForWeekOfYear != nil)
        assert(inputDateComponents.weekOfYear != nil)
        assert(inputDateComponents.month != nil)
        assert(inputDateComponents.day != nil)
        assert(inputDateComponents.calendar != nil)
        let calendar = inputDateComponents.calendar!

        let start = inputDateComponents.date!
        assert(start == calendar.startOfDay(for: start))

        let almostOneDayComponents = DateComponents(day: 1, second: -1)
        guard let end = calendar.date(byAdding: almostOneDayComponents, to: start, wrappingComponents: true) else {
            fatalError("Couldn't get endDate from startDate: \(start)")
        }
        
        return DayInterval(startDate: start, endDate: end)
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

    /// Returns an array of 7 tuples corresponding to the 7 days of the week starting on Sunday
    /// The first date is midnight, the second is the last second of the same day.
    func weekDayIntervals(calendar: Calendar) -> (DayInterval, DayInterval, DayInterval, DayInterval, DayInterval, DayInterval, DayInterval) {
        let startDateComponents = dateComponents
        var dayIntervals: [DayInterval] = []
        for weekday in 1...7 {
            var weekdayComponents = startDateComponents
            weekdayComponents.weekday = weekday
            weekdayComponents.day = nil
            let dayInterval = Self.dayInterval(for: weekdayComponents)
            dayIntervals.append(dayInterval)
        }
        return (dayIntervals[0], dayIntervals[1], dayIntervals[2], dayIntervals[3], dayIntervals[4], dayIntervals[5], dayIntervals[6])
    }
}

struct TopicWeek: Equatable, Identifiable {
    var id: String { "\(topic.id):\(week.id)" }
    let topic: Topic
    let week: Week
}

struct Week: Equatable, Identifiable {
    var id: String { "\(yearForWeekOfYear):\(weekOfYear)" } // 2023:32
    var yearForWeekOfYear: Int
    var weekOfYear: Int
    var month: Int
    var firstDayOfWeek: Int // 9 -> July 9th
    var lastDayOfWeek: Int
}

struct DayInterval: Equatable {
    var startDate: Date // Midnight
    var endDate: Date // Midnight of next day minus 1 minute
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
        let monthName = store.dateFormatter.standaloneMonthSymbols[topicWeek.week.month - 1]
        let viewData = WeekViewData(
            title: "Week \(topicWeek.week.weekOfYear)",
            subtitle: "\(monthName) \(topicWeek.week.firstDayOfWeek)-\(topicWeek.week.lastDayOfWeek), \(topicWeek.week.yearForWeekOfYear)",
            previousWeekDisabled: false, // TODO:
            nextWeekDisabled: false, // TODO:
            days: []
        )
        return viewData
    }

    var body: some View {
        WeekView(viewData: viewData)
    }
}

struct WeekView: View {
    let viewData: WeekViewData
    var previousWeekTapped: (() -> Void)?
    var nextWeekTapped: (() -> Void)?

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
                            .monospacedDigit()
                        Text("/")
                            .foregroundColor(Color.tertiaryLabel)
                            .monospacedDigit()
                            .padding(.horizontal, 2)
                        Text(day.goal)
                            .foregroundColor(Color.tertiaryLabel)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}

struct WeekView_Previews: PreviewProvider {
    static var previews: some View {
        WeekView(viewData: .mock)
            .frame(width: 200)
        WeekScreen(store: .init(topic: .new))
            .frame(width: 200)
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
