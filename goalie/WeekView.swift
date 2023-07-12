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

        // Get components for the relevant week
        let nowComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .month], from: now)

        // Get the date components for the first day of the relevant week
        var firstDayOfWeekComponents = nowComponents
        firstDayOfWeekComponents.weekday = 1
        firstDayOfWeekComponents.calendar = calendar
        let firstDayOfWeekDate = firstDayOfWeekComponents.date!
        
        // Use the date of the first day of the week to calculate the day
        firstDayOfWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .month, .day], from: firstDayOfWeekDate)
        
        // Get the date components for the last day of the relevant week
        var lastDayOfWeekComponents = nowComponents
        lastDayOfWeekComponents.weekday = 7
        lastDayOfWeekComponents.calendar = calendar
        let lastDayOfWeekDate = lastDayOfWeekComponents.date!
        
        lastDayOfWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .month, .day], from: lastDayOfWeekDate)
        // Use the date of the first day of the week to calculate the day

        let week = Week(yearForWeekOfYear: nowComponents.yearForWeekOfYear!, weekOfYear: nowComponents.weekOfYear!, month: nowComponents.month!, firstDayOfWeek: firstDayOfWeekComponents.day!, lastDayOfWeek: lastDayOfWeekComponents.day!)
        let topicWeek = TopicWeek(topic: topic, week: week)
        self.topicWeek = topicWeek
        
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = timeZone
        self.dateFormatter = dateFormatter
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
            previousWeekDisabled: false, // TODO
            nextWeekDisabled: false, // TODO
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
