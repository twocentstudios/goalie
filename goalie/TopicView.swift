import Combine
import CustomDump
import Dependencies
import SwiftUI
import SwiftUINavigation
import SystemColors

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
        case history(WeekStore)
        case confirmingCancelCurrentSession(AlertState<AlertAction>)
        case confirmingDeleteSession(AlertState<AlertAction>)
    }

    enum AlertAction {
        case cancelCurrentSession
        case deleteSession(UUID)
    }

    private var save: (Topic) -> Void
    private var timerCancellable: Cancellable?

    init(topic: Topic, save: @escaping ((Topic) -> Void)) {
        self.topic = topic
        self.save = save
        startOfToday = calendar.startOfDay(for: now)

        // TODO: This crashes? Or doesn't update on the next day?
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

        topic.goals.append(.init(id: uuid(), start: calendar.startOfDay(for: now), duration: newGoal))
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

    func deleteSessionButtonTapped(_ sessionID: UUID) {
        guard destination == nil else {
            assertionFailure("Unexpected state: destination is already set")
            return
        }

        destination = .confirmingDeleteSession(
            AlertState {
                TextState("Are you sure you want to the delete this session?")
            } actions: {
                ButtonState(role: .destructive, action: .send(.deleteSession(sessionID))) {
                    TextState("Delete Session")
                }
                ButtonState(role: .cancel, action: .send(nil)) {
                    TextState("Cancel")
                }
            }
        )
    }

    func alertButtonTapped(_ action: AlertAction?) {
        switch action {
        case .none:
            break
        case .cancelCurrentSession:
            topic.activeSessionStart = nil
        case let .deleteSession(id):
            topic.sessions.remove(id: id)
        }
    }

    func editSessionsButtonTapped() {}

    func historyButtonTapped() {
        destination = .history(.init(topic: topic))
    }

    func debugResetTopic() {
        topic = Topic.new
    }
}

struct TopicViewData {
    struct SessionRow: Equatable, Identifiable {
        let id: UUID
        let start: String
        let duration: String
    }

    struct ActiveSessionRow: Equatable {
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

    func activeSessionRow(end: Date) -> ActiveSessionRow? {
        if let activeSessionStart = topic.activeSessionStart {
            return ActiveSessionRow(
                start: activeSessionStart.formatted(date: .omitted, time: .shortened),
                duration: Duration.seconds(end.timeIntervalSince(activeSessionStart)).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 0, roundFractionalSeconds: .up)))
            )
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
            Button {
                store.historyButtonTapped()
            } label: {
                Image(systemName: "calendar")
                    .font(.body)
                    .foregroundColor(Color.label)
            }
            .keyboardShortcut("y", modifiers: [.command])
            .frame(maxWidth: .infinity, alignment: .trailing)
            
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
                .keyboardShortcut(.return, modifiers: [.command])

                // Previews times out without this lol
                if false {}

                Spacer().frame(height: 16)

                if let sessionsCountTitle = viewData.sessionCountTitle(start: store.startOfToday, end: timeline.date) {
                    Button {
                        isShowingTodaysSessions.toggle()
                    } label: {
                        HStack(spacing: 2) {
                            Text(sessionsCountTitle)
                                .font(.subheadline)
                            Image(systemName: "chevron.down.circle")
                                .rotationEffect(isShowingTodaysSessions ? .degrees(180) : .degrees(0))
                        }
                        .foregroundColor(isShowingTodaysSessions ? Color.label : Color.secondaryLabel)
                    }
                    .buttonStyle(.plain)
                }

                if isShowingTodaysSessions {
                    Spacer().frame(height: 6)

                    VStack(alignment: .leading, spacing: 0) {
                        if let activeSessionRow = viewData.activeSessionRow(end: timeline.date) {
                            HStack(spacing: 0) {
                                Button {
                                    store.cancelCurrentSessionButtonTapped()
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .padding(5)
                                }
                                .foregroundColor(Color.secondaryLabel)
                                .buttonStyle(.plain)
                                .alert(unwrapping: $store.destination, case: /TopicStore.Destination.confirmingCancelCurrentSession) { action in
                                    store.alertButtonTapped(action)
                                }

                                Text(activeSessionRow.start)
                                    .monospacedDigit()
                                    .foregroundColor(Color.secondaryLabel)
                                Spacer()
                                Text(activeSessionRow.duration)
                                    .monospacedDigit()
                            }
                        }

                        ForEach(viewData.sessionRows(start: store.startOfToday, end: timeline.date)) { row in
                            HStack(spacing: 0) {
                                Button {
                                    store.deleteSessionButtonTapped(row.id)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .padding(5)
                                }
                                .foregroundColor(Color.secondaryLabel)
                                .buttonStyle(.plain)
                                .alert(unwrapping: $store.destination, case: /TopicStore.Destination.confirmingDeleteSession) { action in
                                    store.alertButtonTapped(action)
                                }

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
        .sheet(
            unwrapping: $store.destination,
            case: /TopicStore.Destination.history
        ) { $weekStore in
            WeekScreen(store: weekStore)
        }
    }
}

struct TopicView_Previews: PreviewProvider {
    static var previews: some View {
        TopicView(store: .init(topic: .init(id: .init(), activeSessionStart: .now, sessions: .init(uniqueElements: [.init(id: .init(), start: .now.addingTimeInterval(-100), end: .now.addingTimeInterval(-20))]), goals: .init(uniqueElements: [.init(id: .init(), start: .distantPast, duration: 5)])), save: { _ in }))
    }
}
