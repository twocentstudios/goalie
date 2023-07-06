import Foundation

enum StoreState<T> {
    case initialized
    case loading
    case loadingFailed(Error)
    case loaded(T)
}

extension StoreState {
    var isLoading: Bool {
        switch self {
        case .initialized:
            return true
        case .loading:
            return true
        case .loadingFailed,
             .loaded:
            return false
        }
    }

    var isLoaded: Bool {
        switch self {
        case .initialized,
             .loading,
             .loadingFailed:
            return false
        case .loaded:
            return true
        }
    }

    var isLoadingFirstTime: Bool {
        switch self {
        case .initialized:
            return false
        case .loading:
            return true
        case .loadingFailed,
             .loaded:
            return false
        }
    }

    var shouldLoad: Bool {
        switch self {
        case .initialized:
            return true
        case .loading:
            return false
        case .loadingFailed,
             .loaded:
            return true
        }
    }

    var stateByLoading: Self? {
        switch self {
        case .initialized:
            return .loading
        case .loading:
            return nil
        case .loadingFailed:
            return .loading
        case .loaded:
            return nil
        }
    }

    var store: T? {
        switch self {
        case .initialized,
             .loading,
             .loadingFailed:
            return nil
        case let .loaded(value):
            return value
        }
    }

    var errorMessage: String? {
        switch self {
        case let .loadingFailed(error):
            return error.localizedDescription
        case .initialized,
             .loading,
             .loaded:
            return nil
        }
    }
}
