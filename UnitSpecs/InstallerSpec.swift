import Combine
import Nimble
import Quick
import Testable

class InstallerSpec: QuickSpec {
    override func spec() {
        describe(Installer.self) {
            var subject: Installer!
            var stateContainer: MockStateContainer!
            beforeEach {
                stateContainer = .createAndInject()
                subject = .init()
            }
            context(Installer.beginInstallation(login:)) {
                let installationUrl = URL(fileURLWithPath: "/tmp/test-installation")
                context("success") {
                    var downloader: MockDownloader!
                    var request: LoginRequest!
                    let fileManager = FileManager.default
                    beforeEach {
                        downloader = .createAndInject()
                        TestDependency.register(Inject(FileManager.default))
                        TestDependency.register(Inject(installationUrl, name: "installation url"))
                        TestDependency.register(Inject("successful client id", name: "unique client id"))
                        let scriptUrl = testBundle.url(forResource: "install_vernal_falls", withExtension: "sh")!
                        TestDependency.register(Inject(scriptUrl, name: "installation script url"))

                        try? fileManager.removeItem(at: installationUrl)
                        expect(fileManager.fileExists(atPath: installationUrl.path)) == false
                        request = Init(.init()) {
                            $0?.baseUrlString = testBundleUrl("successful-response-invalid-tar.json").absoluteString
                        }
                        downloader.downloadedContentsUrl = testBundleUrl("tiny-valid.tar.gz")
                    }
                    func verify(file: String, at url: URL) {
                        let expectedPath = testBundleUrl(file).path
                        let equalContent = fileManager.contentsEqual(atPath: url.path,
                                                                     andPath: expectedPath)

                        expect(equalContent).to(beTrue(), description: "found: \(String(describing: try? String(contentsOf: url)))")
                    }
                    it("should transition to busy then to complete") {
                        subject.beginInstallation(login: request)
                        expect(stateContainer.didTransition).toEventually(equal(["startReceiving()", "complete()"]))
                        let config = installationUrl.appendingPathComponent("vernal_falls_config.yml")
                        verify(file: "expected-config.yml", at: config)
                    }
                    it("should download vernal falls archive") {
                        subject.beginInstallation(login: request)
                        expect(stateContainer.didTransition).toEventually(contain("complete()"))
                        expect(downloader.didProvideReporting).notTo(beNil())
                        verify(file: "tiny-valid.tar.gz",
                               at: installationUrl.appendingPathComponent("vernal_falls.tar.gz"))
                    }
                    it("should install vernal falls") {
                        subject.beginInstallation(login: request)
                        expect(stateContainer.didTransition).toEventually(contain("complete()"))
                        let unTaredContents = try? String(contentsOf: installationUrl.appendingPathComponent("vernal_falls/small-file.txt"))
                        expect(unTaredContents) == ""
                    }
                    context("download progress") {
                        var progressReporter: Progressing!
                        beforeEach {
                            expect(downloader.didProvideReporting).to(beNil())
                            subject.beginInstallation(login: request)
                            expect(stateContainer.didTransition).toEventually(contain("complete()"))
                            progressReporter = downloader.didProvideReporting
                        }
                        it("should set state to busy with the progress of download") {
                            let progress = Progress()
                            progressReporter(progress)
                            expect(stateContainer.didProgress) == progress
                        }
                    }
                    context("installation failure") {
                        var errorReporter: MockErrorReporter!
                        beforeEach {
                            errorReporter = .createAndInject()
                            let invalidArchive = testBundleUrl("expected-config.yml")
                            downloader.downloadedContentsUrl = invalidArchive
                        }
                        it("should report error and status code") {
                            subject.beginInstallation(login: request)
                            expect(stateContainer.didTransition).toEventually(equal(["startReceiving()", "reset()"]))
                            let reportedError = errorReporter.didReport as? LocalizedError
                            expect(reportedError?.localizedDescription)
                                == "Failed with exit code: 1"
                            expect(reportedError?.recoverySuggestion)
                                == "tar: Error opening archive: Unrecognized archive format\n"
                        }
                    }
                }
                context("server error") {
                    var errorReporter: MockErrorReporter!
                    beforeEach {
                        errorReporter = .createAndInject()
                        TestDependency.register(Inject("failing client id", name: "unique client id"))
                    }
                    func beginLogin(urlString: String) {
                        let loginRequest = Init(LoginRequest()) {
                            $0.baseUrlString = urlString
                        }
                        subject.beginInstallation(login: loginRequest)
                    }
                    it("should report errors while connecting") {
                        beginLogin(urlString: "file://invalid-url")
                        expect(stateContainer.didTransition).toEventually(equal(["startReceiving()", "reset()"]))
                        expect(errorReporter.didReport!.localizedDescription)
                            == "The requested URL was not found on this server."
                    }
                    it("should start progress, transition back to login and report error from server") {
                        beginLogin(urlString: testBundleUrl("server-error-response.json").absoluteString)
                        expect(stateContainer.didTransition).toEventually(equal(["startReceiving()", "reset()"]))
                        let reportedError = errorReporter.didReport as? LocalizedError
                        expect(reportedError?.localizedDescription)
                            == "Server Error"
                        expect(reportedError?.recoverySuggestion)
                            == "Email and password are not valid"
                    }
                }
            }
            context(Installer.cancelInstallation) {
                it("should transition to login") {
                    subject.cancelInstallation()
                    expect(stateContainer.didTransition) == ["reset()"]
                }
            }
            context(Installer.uninstall) {
                it("should transition to login") {
                    subject.uninstall()
                    expect(stateContainer.didTransition) == ["reset()"]
                }
            }
        }
    }
}
