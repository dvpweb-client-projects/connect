import Nimble
import Quick
import SpartaConnect
import Testable

class AppAssemblySpec: QuickSpec {
    override func spec() {
        describe(AppAssembly.self) {
            context(Inject<URL>.self) {
                var injectedUrl: Inject<URL>!
                context("installation url") {
                    beforeEach {
                        injectedUrl = Inject<URL>("installation url")
                    }
                    it("should have path that ends with library app support bundle id") {
                        expect(injectedUrl.wrappedValue.path).to(
                            endWith("/Library/Application Support/com.spartascience.SpartaConnect")
                        )
                    }
                }
                context("start script url") {
                    beforeEach {
                        injectedUrl = Inject<URL>("start script url")
                    }
                    it("should contain launchctl bootstap") {
                        expect(try? String(contentsOf: injectedUrl.wrappedValue)).to(
                            contain("/bin/launchctl bootstrap gui")
                        )
                    }
                }
                context("installation script url") {
                    beforeEach {
                        injectedUrl = Inject<URL>("installation script url")
                    }
                    it("should contain commands to untar and lauchctl plist with keep alive") {
                        expect(try? String(contentsOf: injectedUrl.wrappedValue)).to(contain(
                            """
                            tar xf ../vernal_falls.tar.gz
                            ln -s . CURRENT
                            """,
                            """
                                <key>KeepAlive</key>
                            """
                        ))
                    }
                }
            }
        }
    }
}
