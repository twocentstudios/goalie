import Dependencies
import Foundation

struct FileStorageClient {
    var writeData: (Data, String) throws -> Void
    var readData: (String) throws -> Data?
    var removeData: (String) throws -> Void
//    var resetData: () throws -> Void
}

struct GoaliePersistenceClient {
    var writeTopic: (Topic) throws -> Void
    var readTopic: (UUID) throws -> Topic?
    var removeTopic: (UUID) throws -> Void
//    var removeAllTopics: () throws -> Void
}

extension GoaliePersistenceClient: DependencyKey {
    static let liveValue = GoaliePersistenceClient.live
    static let testValue = GoaliePersistenceClient.mock
    static let previewValue = GoaliePersistenceClient.mock
}

extension DependencyValues {
    var goaliePersistenceClient: GoaliePersistenceClient {
        get { self[GoaliePersistenceClient.self] }
        set { self[GoaliePersistenceClient.self] = newValue }
    }
}

extension FileStorageClient {
    init(rootDirectory: URL) {
        writeData = { data, path throws in
            let fileURL = rootDirectory.appending(path: path, directoryHint: .notDirectory)
            try data.write(to: fileURL)
        }
        readData = { path throws -> Data? in
            let fileURL = rootDirectory.appending(path: path, directoryHint: .notDirectory)
            let data = try Data(contentsOf: fileURL)
            return data
        }
        removeData = { path throws in
            let fileURL = rootDirectory.appending(path: path, directoryHint: .notDirectory)
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

extension GoaliePersistenceClient {
    private static func path(for topicId: UUID) -> String {
        "topics/\(topicId).json"
    }

    init(rootDirectory: URL) {
        let fileStorageClient = FileStorageClient(rootDirectory: rootDirectory)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        writeTopic = { topic throws in
            let data = try encoder.encode(topic)
            let path = Self.path(for: topic.id)
            try fileStorageClient.writeData(data, path)
        }
        readTopic = { id throws -> Topic? in
            let path = Self.path(for: id)
            guard let data = try fileStorageClient.readData(path) else { return nil }
            let topic = try decoder.decode(Topic.self, from: data)
            return topic
        }
        removeTopic = { id throws in
            let path = Self.path(for: id)
            try fileStorageClient.removeData(path)
        }
    }

    static let live = {
        let applicationSupportDirectory = URL.applicationSupportDirectory
        let applicationDirectory = applicationSupportDirectory.appending(path: "com.twocentstudios.goalie", directoryHint: URL.DirectoryHint.isDirectory)
        return Self(rootDirectory: applicationDirectory)
    }()

    static let mock = Self(rootDirectory: URL.temporaryDirectory)
}
