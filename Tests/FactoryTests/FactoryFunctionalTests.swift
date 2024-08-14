import XCTest
import os
@testable import Factory

typealias OpenURLFunction = (_ url: URL) -> Bool

extension Container {
    var openURL: Factory<OpenURLFunction> {
        self { { _ in false } }
    }
}

private class MyViewModel {
    @Injected(\.openURL) var openURL
    func open(site: String) {
        _ = openURL(URL(string: site)!)
    }
}

final class OpenURLFunctionMock: Sendable {
    let openedURL: OSAllocatedUnfairLock<URL?> = .init(initialState: nil)
    init() {
      Container.shared.openURL.register {
            { [weak self] url in
              self?.openedURL.withLock { $0 = url }
                return false
            }
        }
    }
}

final class FactoryFunctionalTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Container.shared.reset()
    }


    func testOpenFuctionality() throws {
        let openedURL: OSAllocatedUnfairLock<URL?> = .init(initialState: nil)
        Container.shared.openURL.register {
            { url in
                openedURL.withLock { $0 = url }
                return false
            }
        }
        let viewModel = MyViewModel()
        viewModel.open(site: "https://google.com")
        XCTAssert(openedURL.withLock { $0 } != nil)
    }

    func testMockFuctionality() throws {
        let mock = OpenURLFunctionMock()
        let viewModel = MyViewModel()
        viewModel.open(site: "https://google.com")
        XCTAssert(mock.openedURL.withLock { $0 } != nil)
    }

}

