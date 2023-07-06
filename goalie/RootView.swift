import Dependencies
import SwiftUI

struct RootView: View {
    @ObservedObject var store: RootStore

    var body: some View {
        ZStack {
            switch store.topicStoreState {
            case .initialized,
                 .loading:
                ProgressView()
                    .padding()
            case let .loadingFailed(error):
                VStack(spacing: 10) {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        store.retry()
                    }
                }
                .padding()
            case let .loaded(topicStore):
                TopicView(store: topicStore)
            }
        }
        .task {
            await store.task()
        }
    }
}

final class RootStore: ObservableObject {
    @Published var topicStoreState: StoreState<TopicStore> = .initialized
    @Dependency(\.goaliePersistenceClient) var persistenceClient

    @MainActor
    func task() async {
        loadTopic()
    }

    func retry() {
        loadTopic()
    }

    // TODO: how to make this async?
    private func loadTopic() {
        // NEXT: currently, only one hardcoded topic is supported. In the future, this should load the last opened topic ID from UserDefaults.
        let onlyTopicId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

        let save: ((Topic) -> Void) = { [persistenceClient] t in
            do {
                try persistenceClient.writeTopic(t)
            } catch {
                assertionFailure(error.localizedDescription)
            }
        }

        guard let nextState = topicStoreState.stateByLoading else { return }
        topicStoreState = nextState
        do {
            guard let topic = try persistenceClient.readTopic(onlyTopicId) else { throw CocoaError(.fileReadNoSuchFile) }
            let topicStore = TopicStore(topic: topic, save: save)
            topicStoreState = .loaded(topicStore)
        } catch CocoaError.fileReadNoSuchFile {
            let newTopic = Topic(id: onlyTopicId, activeSessionStart: nil, sessions: .init(), goals: .init())
            let topicStore = TopicStore(topic: newTopic, save: save)
            topicStoreState = .loaded(topicStore)
        } catch {
            topicStoreState = .loadingFailed(error)
        }
    }
}
