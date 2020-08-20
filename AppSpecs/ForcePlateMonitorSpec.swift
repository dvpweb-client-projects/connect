import Nimble
import Quick
import SpartaConnect
@testable import USBDeviceSwift

class FakeMonitor: SerialDeviceMonitor {
    var didStartOnBackground: Bool?
    override func start() {
        didStartOnBackground = !Thread.isMainThread
    }
}

extension SerialDevice {
    init(vendor: Identifier, product: Identifier) {
        self.init(path: "")
        vendorId = vendor.rawValue
        productId = product.rawValue
    }
}

class ForcePlateMonitorSpec: QuickSpec {
    override func spec() {
        describe(ForcePlateMonitor.self) {
            var subject: ForcePlateMonitor!
            var fake: FakeMonitor!
            var updating: ((String) -> Void)!
            beforeEach {
                fake = .init()
                subject = .init(monitor: fake)
                updating = { _ in }
            }
            context(ForcePlateMonitor.start) {
                it("should start device monitor") {
                    subject.start(update: updating)
                    expect(fake.didStartOnBackground).toEventually(beTrue())
                }
                it("should configure filter") {
                    subject.start(update: updating)
                    expect(fake.filterDevices).notTo(beNil())
                }
                context(\SerialDeviceMonitor.filterDevices) {
                    var devices: [SerialDevice]!
                    beforeEach {
                        let valid = SerialDevice(vendor: .stMicroelectronics, product: .virtualComPort)
                        let noVendor = SerialDevice(path: "")
                        let wrongProduct = SerialDevice(vendor: .stMicroelectronics, product: .stMicroelectronics)
                        let wrongVendor = SerialDevice(vendor: .virtualComPort, product: .virtualComPort)
                        devices = [
                            valid,
                            noVendor,
                            wrongProduct,
                            wrongVendor
                        ]
                        subject.start(update: updating)
                        it("should only allow valid") {
                            expect(fake.filterDevices!(devices)).to(haveCount(1))
                        }
                    }
                }
            }
        }
    }
}
