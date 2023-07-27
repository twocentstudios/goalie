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
        guard let newWeek = topicWeek.week.previousWeek(calendar: calendar) else { assertionFailure("Unexpected calendar math error"); return }
        var newTopicWeek = topicWeek
        newTopicWeek.week = newWeek
        topicWeek = newTopicWeek
    }

    func nextWeekTapped() {
        guard let newWeek = topicWeek.week.nextWeek(calendar: calendar) else { assertionFailure("Unexpected calendar math error"); return }
        var newTopicWeek = topicWeek
        newTopicWeek.week = newWeek
        topicWeek = newTopicWeek
    }
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

extension WeekViewData {
    init(topicWeek: TopicWeek, now: Date, locale: Locale) {
        // TODO: `formatted` presumably uses system calendar/locale/timezone directly instead of via dependency
        title = "Week " + topicWeek.week.firstMoment.formatted(.dateTime.week(.defaultDigits))
        subtitle = topicWeek.week.range.formatted(.interval.year().month(.abbreviated).day().locale(locale))
        previousWeekDisabled = false // TODO:
        nextWeekDisabled = false // TODO:
        days = topicWeek.week.weekDayIntervals.map { interval -> WeekViewData.Day in
            let dayTitle = interval.startDate.formatted(.dateTime.month(.twoDigits).day(.twoDigits))

            let emptyInterval = "--:--:--"

            let durationInterval: TimeInterval?
            let duration: String
            if now < interval.startDate {
                // Interval is in the future
                duration = emptyInterval
                durationInterval = nil
            } else if !topicWeek.topic.sessionsBefore(date: interval.startDate) {
                // Interval exists before any sessions
                duration = emptyInterval
                durationInterval = nil
            } else {
                let validatedEnd = min(now, interval.endDate)
                let validDurationInterval = topicWeek.topic.totalIntervalBetween(start: interval.startDate, end: validatedEnd)
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
    }
}

struct WeekScreen: View {
    @ObservedObject var store: WeekStore
    @Environment(\.dismiss) private var dismiss

    private var viewData: WeekViewData {
        .init(topicWeek: store.topicWeek, now: store.now, locale: store.locale)
    }

    var body: some View {
        WeekView(
            viewData: viewData,
            previousWeekTapped: store.previousWeekTapped,
            nextWeekTapped: store.nextWeekTapped,
            dismissTapped: dismiss.callAsFunction
        )
    }
}

struct WeekView: View {
    let viewData: WeekViewData
    var previousWeekTapped: (() -> Void)?
    var nextWeekTapped: (() -> Void)?
    var dismissTapped: (() -> Void)?

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
                        .contentShape(Rectangle())
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
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewData.nextWeekDisabled)
            }

            Spacer().frame(height: 8)

            VStack(spacing: 6) {
                ForEach(viewData.days) { day in
                    HStack(spacing: 0) {
                        Image(systemName: day.goalRatioSymbolName)
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
                    dismissTapped?()
                }
                .keyboardShortcut("y", modifiers: [.command])
            }
        }
        .frame(minWidth: 244, maxWidth: 320)
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
