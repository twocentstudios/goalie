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
                        Task { await store.retry() }
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

    func task() async {
        await loadTopic()
    }

    func retry() async {
        await loadTopic()
    }

    @MainActor private func loadTopic() async {
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
            async let maybeTopic = Task { try persistenceClient.readTopic(Topic.new.id) }.value
            guard let topic = try await maybeTopic else { throw CocoaError(.fileReadNoSuchFile) }
            let topicStore = TopicStore(topic: topic, save: save)
            topicStoreState = .loaded(topicStore)
        } catch CocoaError.fileReadNoSuchFile {
            let newTopic = Topic.new
            let topicStore = TopicStore(topic: newTopic, save: save)
            topicStoreState = .loaded(topicStore)
        } catch {
            topicStoreState = .loadingFailed(error)
        }
    }
}
