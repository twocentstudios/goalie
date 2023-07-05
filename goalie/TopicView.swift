import Combine
import Dependencies
import IdentifiedCollections
import SwiftUI
import SwiftUINavigation

struct Topic: Equatable, Identifiable {
    let id: UUID
    var activeSessionStart: Date? // non-nil when a session is active
    var sessions: IdentifiedArrayOf<Session> // assume sorted past to future
    var goals: IdentifiedArrayOf<Goal> // assume sorted past to future
}

struct Session: Equatable, Identifiable {
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

struct Goal: Equatable, Identifiable {
    let id: UUID
    let start: Date
    let duration: TimeInterval? // nil intentionally unsets a goal
}

final class TopicStore: ObservableObject {
    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid
    @Dependency(\.calendar) var calendar
    @Dependency(\.mainRunLoop) var mainRunLoop

    @Published var topic: Topic {
        didSet {
            save(topic)
        }
    }
    @Published var startOfToday: Date!
    @Published var destination: Destination?

    enum Destination {
        case goalAdd(TimeInterval?) // the current goal as the initial value
    }

    private var save: (Topic) -> Void
    private var timerCancellable: Cancellable?

    init(topic: Topic, save: @escaping ((Topic) -> Void)) {
        self.topic = topic
        self.save = save
        startOfToday = calendar.startOfDay(for: now)

        let approximateOneDayInterval: TimeInterval = 60 * 60 * 24
        timerCancellable = mainRunLoop.schedule(
            after: .init(calendar.startOfDay(for: now.addingTimeInterval(approximateOneDayInterval))),
            interval: .seconds(approximateOneDayInterval),
            tolerance: .seconds(1)
        ) { [weak self] in
            guard let self else { return }
            self.startOfToday = calendar.startOfDay(for: self.now)
        }
    }

    func startStop() {
        if let start = topic.activeSessionStart {
            let newSession = Session(id: uuid(), start: start, end: now)
            topic.activeSessionStart = nil
            topic.sessions.append(newSession)
        } else {
            topic.activeSessionStart = now
        }
    }

    func showGoalAdd() {
        destination = .goalAdd(topic.currentGoal?.duration ?? 0)
    }

    func addGoal(_ newGoal: TimeInterval?) {
        if topic.currentGoal?.duration == newGoal {
            // goal hasn't changed, do nothing
            return
        }

        topic.goals.append(.init(id: uuid(), start: now, duration: newGoal))
    }

    func editSessions() {}
}

extension Topic {
    var currentGoal: Goal? {
        goals.max(by: { $0.start > $1.start })
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
        for session in sessions.reversed() {
            if (start ... end).contains(session.start) || (start ... end).contains(session.end) {
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
            } else if !matchingTimeIntervals.isEmpty {
                // For performance, assume sessions array is sorted.
                // If we've passed the relevant block of dates, then assume no more dates will match.
                break
            }
        }

        let totalInterval = matchingTimeIntervals.reduce(0, +)
        return totalInterval
    }
}

struct TopicViewData {
    let topic: Topic

    var isTimerPaused: Bool {
        topic.activeSessionStart == nil
    }

    func timerTitle(_ now: Date) -> String {
        if let start = topic.activeSessionStart {
            let interval = now.timeIntervalSince(start)
            let duration = Duration.seconds(interval)
            return duration.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 0, roundFractionalSeconds: .towardZero)))
        } else {
            return "00:00:00"
        }
    }

    var currentGoalTitle: String {
        if let goalDuration = topic.currentGoal?.duration {
            let duration = Duration.seconds(goalDuration)
            return duration.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 0, roundFractionalSeconds: .towardZero)))
        } else {
            return "--:--:--"
        }
    }

    func isGoalComplete(startOfDay: Date, now: Date) -> Bool {
        if let goalDuration = topic.currentGoal?.duration {
            let totalIntervalToday = topic.totalIntervalBetween(start: startOfDay, end: now)
            if totalIntervalToday >= goalDuration {
                return true
            }
        }
        return false
    }

    var startStopButtonTitle: String {
        if topic.activeSessionStart == nil {
            return "Start"
        } else {
            return "Stop"
        }
    }

    var sessionCountTitle: AttributedString {
        (try? .init(markdown: "**3** sessions today")) ?? .init()
    }
}

struct TopicView: View {
    @ObservedObject var store: TopicStore

    private var viewData: TopicViewData {
        .init(topic: store.topic)
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: 1, paused: viewData.isTimerPaused)) { timeline in
                Text(viewData.timerTitle(timeline.date))
                    .monospacedDigit()
                    .font(.largeTitle)
                Spacer().frame(height: 2)
                HStack(spacing: 4) {
                    Text(viewData.currentGoalTitle)
                        .font(.title3)
                        .foregroundColor(Color(.secondaryLabelColor))

                    Button {
                        store.showGoalAdd()
                    } label: {
                        HStack(spacing: 2) {
                            Text("Goal")
                                .foregroundColor(viewData.isGoalComplete(startOfDay: store.startOfToday, now: timeline.date) ? Color.green.opacity(0.7) : Color(.tertiaryLabelColor))
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(Color(.tertiaryLabelColor))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer().frame(height: 16)
            Button {
                store.startStop()
            } label: {
                Text(viewData.startStopButtonTitle)
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    }
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 10)

            Button {
                // TODO: edit goal
            } label: {
                HStack(spacing: 2) {
                    Text(viewData.sessionCountTitle)
                        .font(.subheadline)
                        .foregroundColor(Color(.secondaryLabelColor))
                    Image(systemName: "square.and.pencil")
                }
                .foregroundColor(Color(.tertiaryLabelColor))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: 300)
        .sheet(
            unwrapping: $store.destination,
            case: /TopicStore.Destination.goalAdd
        ) { $initialGoal in
            GoalAddView(initialGoal: initialGoal)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TopicView(store: .init(topic: .init(id: .init(), sessions: .init(), goals: .init(uniqueElements: [.init(id: .init(), start: .distantPast, duration: 5)])), save: { _ in }))
    }
}
