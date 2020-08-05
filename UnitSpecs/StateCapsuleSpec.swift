import Nimble
import Quick
import Testable

class StateCapsuleSpec: QuickSpec {
    override func spec() {
        describe(StateCapsule.self) {
            var defaults: UserDefaults!
            var subject: StateCapsule!
            beforeEach {
                defaults = .init()
                defaults.removeObject(forKey: "complete")
                TestDependency.register(Inject(defaults!))
                subject = .init()
            }
            context(StateCapsule.init) {
                beforeEach {
                    defaults.set(true, forKey: "complete")
                }
                it("should load initial state") {
                    expect(StateCapsule().state) == .complete
                }
            }

            context(StateCapsule.startReceiving) {
                it("should start state progress") {
                    subject.startReceiving()
                    expect(subject.state.progress()).notTo(beNil())
                }
            }
            context(StateCapsule.reset) {
                it("should reset state to login and save false to defaults") {
                    subject.reset()
                    expect(subject.state) == .login
                    expect(defaults.bool(forKey: "complete")) == false
                }
            }
            context(StateCapsule.complete) {
                it("should set state to complete and save true to defaults") {
                    subject.complete()
                    expect(subject.state) == .complete
                    expect(defaults.bool(forKey: "complete")) == true
                }
            }
            context(StateCapsule.update(progress:)) {
                context("busy") {
                    beforeEach {
                        subject.state = .busy(value: .init())
                    }
                    it("should set state to busy with new progress") {
                        let progress = Progress(totalUnitCount: 2_020, parent: .init(), pendingUnitCount: 10)
                        subject.update(progress: progress)
                        expect(subject.state.progress()) == progress
                    }
                }
                context("complete") {
                    beforeEach {
                        subject.state = .complete
                    }
                    it("should not change to busy") {
                        subject.update(progress: .init())
                        expect(subject.state) == .complete
                    }
                }
            }
        }
    }
}