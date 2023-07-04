import Dependencies
import IdentifiedCollections
import SwiftUI

struct Topic: Equatable, Identifiable {
    let id: UUID
    var activeSessionStart: Date?
    var sessions: IdentifiedArrayOf<Session>
    var goals: IdentifiedArrayOf<Goal>
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

    @Published var topic: Topic

    private var save: (Topic) -> Void

    init(topic: Topic, save: @escaping ((Topic) -> Void)) {
        self.topic = topic
        self.save = save
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

    func editGoal() {}

    func editSessions() {}
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
        "--:--:--"
    }

    var isGoalComplete: Bool {
        false
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

struct ContentView: View {
    @ObservedObject var store: TopicStore

    private var viewData: TopicViewData {
        .init(topic: store.topic)
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: 1, paused: viewData.isTimerPaused)) { value in
                Text(viewData.timerTitle(value.date))
                    .monospacedDigit()
                    .font(.largeTitle)
            }
            Spacer().frame(height: 2)
            HStack(spacing: 4) {
                Text(viewData.currentGoalTitle)
                    .font(.title3)
                    .foregroundColor(viewData.isGoalComplete ? Color.green : Color(.secondaryLabelColor))

                Button {
                    // TODO: edit goal
                } label: {
                    HStack(spacing: 2) {
                        Text("Goal")
                        Image(systemName: "square.and.pencil")
                    }
                    .foregroundColor(Color(.tertiaryLabelColor))
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(store: .init(topic: .init(id: .init(), sessions: .init(), goals: .init()), save: { _ in }))
    }
}
