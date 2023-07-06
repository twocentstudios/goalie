import Combine
import CustomDump
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
            customDump(topic)
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
        goals.max(by: { $0.start < $1.start })
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

    /// Includes `activeSession` if there is one currently running and not yet complete.
    func sessionCountBetween(start: Date, end: Date) -> Int {
        let matchingSessionsCount = Self.sessionsBetween(start: start, end: end, from: sessions).count
        let activeSessionCount = activeSessionStart != nil ? 1 : 0
        let totalCount = matchingSessionsCount + activeSessionCount
        return totalCount
    }

    /// Assumes `from` sessions are sorted.
    static func sessionsBetween(start: Date, end: Date, from sessions: IdentifiedArrayOf<Session>) -> IdentifiedArrayOf<Session> {
        var matchingSessions: IdentifiedArrayOf<Session> = []
        for session in sessions.reversed() {
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

struct TopicViewData {
    let topic: Topic

    var isTimerPaused: Bool {
        topic.activeSessionStart == nil
    }

    func timerTitle(startOfDay: Date, now: Date) -> String {
        let totalIntervalToday = topic.totalIntervalBetween(start: startOfDay, end: now)
        let duration = Duration.seconds(totalIntervalToday)
        return duration.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 0, roundFractionalSeconds: .up)))
    }

    var currentGoalTitle: String {
        if let goalDuration = topic.currentGoal?.duration {
            let duration = Duration.seconds(goalDuration)
            return duration.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 0, roundFractionalSeconds: .up)))
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

    func sessionCountTitle(start: Date, end: Date) -> AttributedString {
        let sessionsCount = topic.sessionCountBetween(start: start, end: end)
        let unitTitle = sessionsCount == 1 ? "session" : "sessions"
        let title: AttributedString = (try? .init(markdown: "**\(sessionsCount)** \(unitTitle) today")) ?? .init()
        return title
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
                Text(viewData.timerTitle(startOfDay: store.startOfToday, now: timeline.date))
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
                Spacer().frame(height: 16)
                Button {
                    store.startStop()
                } label: {
                    Text(viewData.startStopButtonTitle)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background {
                            Color.black
                                .overlay {
                                    LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                }
                                .cornerRadius(10)
                        }
                }
                .buttonStyle(.plain)

                // TODO: implement current session cancellation
                if false {
                    Spacer().frame(height: 14)
                    HStack(spacing: 2) {
                        Text("Current session started at 1:02pm")
                            .font(.subheadline)
                            .foregroundColor(Color(.secondaryLabelColor))
                        Button {
                            // TODO: confirm cancel session
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(Color(.tertiaryLabelColor))
                }

                Spacer().frame(height: 10)

                Button {
                    // TODO: edit sessions
                } label: {
                    HStack(spacing: 2) {
                        Text(viewData.sessionCountTitle(start: store.startOfToday, end: timeline.date))
                            .font(.subheadline)
                            .foregroundColor(Color(.secondaryLabelColor))
                        Image(systemName: "square.and.pencil")
                    }
                    .foregroundColor(Color(.tertiaryLabelColor))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: 300)
        .sheet(
            unwrapping: $store.destination,
            case: /TopicStore.Destination.goalAdd
        ) { $initialGoal in
            GoalAddView(
                initialGoal: initialGoal,
                save: { newGoal in store.addGoal(newGoal) }
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TopicView(store: .init(topic: .init(id: .init(), sessions: .init(), goals: .init(uniqueElements: [.init(id: .init(), start: .distantPast, duration: 5)])), save: { _ in }))
    }
}
