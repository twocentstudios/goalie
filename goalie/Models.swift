import Foundation
import IdentifiedCollections

struct Topic: Equatable, Identifiable, Codable {
    let id: UUID
    var activeSessionStart: Date? // non-nil when a session is active
    var sessions: IdentifiedArrayOf<Session> // assume sorted past to future
    var goals: IdentifiedArrayOf<Goal> // assume sorted past to future
}

struct Session: Equatable, Identifiable, Codable {
    let id: UUID
    let start: Date
    let end: Date

    init(id: UUID, start: Date, end: Date) {
        // TODO: check start > end
        self.id = id
        self.start = start
        self.end = end
    }
}

struct Goal: Equatable, Identifiable, Codable {
    let id: UUID
    let start: Date // always normalized to the start of a day
    let duration: TimeInterval? // nil intentionally unsets a goal, always > 0

    init(id: UUID, start: Date, duration: TimeInterval?) {
        let validDuration: TimeInterval?
        if let duration, duration > 0 {
            validDuration = duration
        } else {
            validDuration = nil
        }

        self.id = id
        self.start = start
        self.duration = validDuration
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

extension Topic {
    static var new: Self {
        // NEXT: currently, only one hardcoded topic is supported. In the future, this should load the last opened topic ID from UserDefaults.
        let onlyTopicId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        return Topic(id: onlyTopicId, activeSessionStart: nil, sessions: .init(), goals: .init())
    }

    var currentGoal: Goal? {
        goals.max(by: { $0.start < $1.start })
    }

    func goal(for date: Date) -> Goal? {
        goals.reversed().first(where: { $0.start <= date })
    }

    /// Generally assumes `start` is midnight on day D.
    /// If day D is earlier than today, `end` is assumed to be one second before midnight on day D.
    /// If day D is today, `end` is assumed to be `now`.
    func totalIntervalBetween(start: Date, end: Date) -> TimeInterval {
        let activeInterval: TimeInterval
        if let sessionStart = activeSessionStart {
            activeInterval = end.timeIntervalSince(sessionStart)
        } else {
            activeInterval = 0
        }

        var matchingTimeIntervals: [TimeInterval] = [activeInterval]
        for session in Self.sessionsBetween(start: start, end: end, from: sessions) {
            // Ensure session.start interval before the `start` date is not counted.
            var validatedStart = session.start
            if session.start < start {
                validatedStart = start
            }

            // Ensure session.end interval before the `end` date is not counted.
            var validatedEnd = session.end
            if session.end > end {
                validatedEnd = end
            }

            let validatedTimeInterval = validatedEnd.timeIntervalSince(validatedStart)
            matchingTimeIntervals.append(validatedTimeInterval)
        }

        let totalInterval = matchingTimeIntervals.reduce(0, +)
        return totalInterval
    }

    /// Are there any sessions before the specified (start) date?
    /// Assumes `sessions` is sorted.
    func sessionsBefore(date: Date) -> Bool {
        if let earliestSession = sessions.first {
            return earliestSession.start <= date
        } else if let activeSessionStart {
            // No recorded sessions, but an active session.
            return activeSessionStart <= date
        } else {
            // No sessions recorded
            return false
        }
    }

    /// Includes `activeSession` if there is one currently running and not yet complete.
    func sessionCountBetween(start: Date, end: Date) -> Int {
        let matchingSessionsCount = Self.sessionsBetween(start: start, end: end, from: sessions).count
        let activeSessionCount = activeSessionStart != nil ? 1 : 0
        let totalCount = matchingSessionsCount + activeSessionCount
        return totalCount
    }

    /// Assumes `from` sessions are sorted.
    static func sessionsBetween(start: Date, end: Date, from sessions: IdentifiedArrayOf<Session>) -> IdentifiedArrayOf<Session> {
        guard start <= end else {
            assertionFailure("start is not before end\n\(start)\n\(end)")
            return []
        }
        var matchingSessions: IdentifiedArrayOf<Session> = []
        for session in sessions.reversed() {
            // TODO: new day trigger crashes here with an assertion failure
            // Probable cause is that ClosedRange requires lowerBound <= upperBound
            if (start ... end).contains(session.start) || (start ... end).contains(session.end) {
                matchingSessions.append(session)
            } else if !matchingSessions.isEmpty {
                // For performance, assume sessions array is sorted.
                // If we've passed the relevant block of dates, then assume no more dates will match.
                break
            }
        }
        return matchingSessions
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
        guard let nextWeekDate = calendar.date(byAdding: durationComponents, to: currentDate, wrappingComponents: false) else { return nil }
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
