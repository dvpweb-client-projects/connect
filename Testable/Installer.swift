import AppKit
import Combine

public class Installer: NSObject {
    @Published public var state: State = .login
    var cancellables = Set<AnyCancellable>()
    @Inject var errorReporter: ErrorReporting
}

extension Installer: Installation {
    public func installationURL() -> URL {
        applicationSupportURL().appendingPathComponent(Bundle.main.bundleIdentifier!)
    }
    public func applicationSupportURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .last!
    }

    public enum ApiError: LocalizedError {
        case server(message: String)
        public var errorDescription: String? {
            switch self {
            case let .server(message):
                return message
            }
        }
    }

    public func makeRequest(_ request: URLRequest) {
        let progress = Progress()
        progress.kind = .file
        progress.fileOperationKind = .receiving
        progress.isCancellable = true
        state = .busy(value: progress)

        URLSession.shared
            .dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: HTTPLoginResponse.self, decoder: JSONDecoder())
            .tryMap { response -> HTTPLoginMessage in
                try FileManager.default.createDirectory(at: self.installationURL(),
                                                        withIntermediateDirectories: true)
                switch response {
                case .failure(value: let serverError):
                    throw ApiError.server(message: serverError.error)
                case .success(value: let success):
                    //                self.process(success.org)
                    //                self.process(success.vernalFallsConfig)
                    print(success.vernalFallsConfig)
                    return success.message
                }
            }
        .sink(receiveCompletion: { complete in
            switch complete {
            case .finished:
                print("Finished")
            case .failure(let error):
                DispatchQueue.main.async {
                    self.cancelInstallation()
                    self.errorReporter.report(error: error)
                }
                print("failure error: ", error)
            }
        }, receiveValue: { response in
            print("final response: ", response)
            self.state = .complete
        })
        .store(in: &cancellables)
    }

    public func beginInstallation(login: Login) {
        assert(state == .login)
        makeRequest(loginRequest(login))
    }

    public func cancelInstallation() {
        state = .login
    }

    public func uninstall() {
        state = .login
    }
}
