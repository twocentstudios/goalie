import Combine
import CustomDump
import Dependencies
import IdentifiedCollections
import SwiftUI
import SwiftUINavigation
import SystemColors

struct Topic: Equatable, Identifiable, Codable {
    let id: UUID
    var activeSessionStart: Date? // non-nil when a session is active
    var sessions: IdentifiedArrayOf<Session> // assume sorted past to future
    var goals: IdentifiedArrayOf<Goal> // assume sorted past to future
}

extension Topic {
    static var new: Self {
        // NEXT: currently, only one hardcoded topic is supported. In the future, this should load the last opened topic ID from UserDefaults.
        let onlyTopicId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        return Topic(id: onlyTopicId, activeSessionStart: nil, sessions: .init(), goals: .init())
    }
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
            // customDump(topic)
        }
    }
    @Published var startOfToday: Date!
    @Published var destination: Destination?

    enum Destination {
        case goalAdd(TimeInterval?) // the current goal as the initial value
        case confirmingCancelCurrentSession(AlertState<AlertAction>)
    }

    enum AlertAction {
        case cancelCurrentSession
    }

    private var save: (Topic) -> Void
    private var timerCancellable: Cancellable?

    init(topic: Topic, save: @escaping ((Topic) -> Void)) {
        self.topic = topic
        self.save = save
        startOfToday = calendar.startOfDay(for: now)

        // TODO: This crashes?
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

    func startStopButtonTapped() {
        if let start = topic.activeSessionStart {
            let newSession = Session(id: uuid(), start: start, end: now)
            topic.activeSessionStart = nil
            topic.sessions.append(newSession)
        } else {
            topic.activeSessionStart = now
        }
    }

    func showGoalAddButtonTapped() {
        destination = .goalAdd(topic.currentGoal?.duration ?? 0)
    }

    func addGoalButtonTapped(_ newGoal: TimeInterval?) {
        if topic.currentGoal?.duration == newGoal {
            // goal hasn't changed, do nothing
            return
        }

        topic.goals.append(.init(id: uuid(), start: now, duration: newGoal))
    }

    func cancelCurrentSessionButtonTapped() {
        guard destination == nil else {
            assertionFailure("Unexpected state: destination is already set")
            return
        }

        if topic.activeSessionStart != nil {
            destination = .confirmingCancelCurrentSession(
                AlertState {
                    TextState("Are you sure you want to the remove the currently running session?")
                } actions: {
                    ButtonState(role: .destructive, action: .send(.cancelCurrentSession)) {
                        TextState("Remove Session")
                    }
                    ButtonState(role: .cancel, action: .send(nil)) {
                        TextState("Continue Session")
                    }
                }
            )
        }
    }

    func alertButtonTapped(_ action: AlertAction?) {
        switch action {
        case .none:
            break
        case .cancelCurrentSession:
            topic.activeSessionStart = nil
        }
    }

    func editSessionsButtonTapped() {}

    func debugResetTopic() {
        topic = Topic.new
    }
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
    struct SessionRow: Equatable, Identifiable {
        let id: UUID
        let start: String
        let duration: String
    }

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

    func sessionCountTitle(start: Date, end: Date) -> AttributedString? {
        let sessionsCount = topic.sessionCountBetween(start: start, end: end)
        if sessionsCount > 0 {
            let unitTitle = sessionsCount == 1 ? "session" : "sessions"
            let title: AttributedString = (try? .init(markdown: "**\(sessionsCount)** \(unitTitle) today")) ?? .init()
            return title
        } else {
            return nil
        }
    }

    var activeSessionStartTitle: String? {
        if let activeSessionStart = topic.activeSessionStart {
            let formattedStart = activeSessionStart.formatted(date: .omitted, time: .shortened)
            return "Running since \(formattedStart)"
        } else {
            return nil
        }
    }

    func sessionRows(start: Date, end: Date) -> [SessionRow] {
        let todaysSessions = Topic.sessionsBetween(start: start, end: end, from: topic.sessions)
        let rows = todaysSessions.map { session in
            SessionRow(
                id: session.id,
                start: session.start.formatted(date: .omitted, time: .shortened),
                duration: Duration.seconds(session.end.timeIntervalSince(session.start)).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 0, roundFractionalSeconds: .up)))
            )
        }
        return rows
    }
}

struct TopicView: View {
    @ObservedObject var store: TopicStore
    @State var isShowingTodaysSessions: Bool = false

    private var viewData: TopicViewData {
        .init(topic: store.topic)
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: 1, paused: viewData.isTimerPaused)) { timeline in
                Text(viewData.timerTitle(startOfDay: store.startOfToday, now: timeline.date))
                    .monospacedDigit()
                    .font(.largeTitle)
                    .onTapGesture(count: 10) {
                        // TODO: debug only
                        store.debugResetTopic()
                    }
                Spacer().frame(height: 2)
                HStack(spacing: 4) {
                    Text(viewData.currentGoalTitle)
                        .font(.title3)
                        .foregroundColor(Color.secondaryLabel)

                    Button {
                        store.showGoalAddButtonTapped()
                    } label: {
                        HStack(spacing: 2) {
                            Text("Goal")
                                .foregroundColor(viewData.isGoalComplete(startOfDay: store.startOfToday, now: timeline.date) ? Color.green.opacity(0.7) : Color.tertiaryLabel)
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(Color.tertiaryLabel)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer().frame(height: 16)
                Button {
                    store.startStopButtonTapped()
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
                                    LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                }
                                .cornerRadius(10)
                        }
                }
                .buttonStyle(.plain)

                if let activeSessionStartTitle = viewData.activeSessionStartTitle {
                    Spacer().frame(height: 14)
                    HStack(spacing: 2) {
                        Text(activeSessionStartTitle)
                            .font(Font.footnote)
                            .foregroundColor(Color.tertiaryLabel)
                        Button {
                            store.cancelCurrentSessionButtonTapped()
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                        .alert(unwrapping: $store.destination, case: /TopicStore.Destination.confirmingCancelCurrentSession) { action in
                            store.alertButtonTapped(action)
                        }
                    }
                    .foregroundColor(Color.tertiaryLabel)
                }

                Spacer().frame(height: 10)

                if let sessionsCountTitle = viewData.sessionCountTitle(start: store.startOfToday, end: timeline.date) {
                    Button {
                        isShowingTodaysSessions.toggle()
                    } label: {
                        HStack(spacing: 2) {
                            Text(sessionsCountTitle)
                                .font(.subheadline)
                            Image(systemName: "chevron.down.circle")
                                .rotationEffect(isShowingTodaysSessions ? .degrees(180) : .degrees(0))
                                .animation(.interactiveSpring(), value: isShowingTodaysSessions)
                        }
                        .foregroundColor(isShowingTodaysSessions ? Color.label : Color.secondaryLabel)
                    }
                    .buttonStyle(.plain)
                }

                if isShowingTodaysSessions {
                    Spacer().frame(height: 6)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewData.sessionRows(start: store.startOfToday, end: timeline.date)) { row in
                            HStack(spacing: 0) {
                                Button {
                                    //                                store.deleteSessionButtonTapped(row.id)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .padding(5)
                                }
                                .foregroundColor(Color.secondaryLabel)
                                .buttonStyle(.plain)

                                Text(row.start)
                                    .monospacedDigit()
                                    .foregroundColor(Color.secondaryLabel)
                                Spacer()
                                Text(row.duration)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
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
                save: { newGoal in store.addGoalButtonTapped(newGoal) }
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TopicView(store: .init(topic: .init(id: .init(), activeSessionStart: .now, sessions: .init(), goals: .init(uniqueElements: [.init(id: .init(), start: .distantPast, duration: 5)])), save: { _ in }))
    }
}
