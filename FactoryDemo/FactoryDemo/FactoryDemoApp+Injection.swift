//
//  FactoryDemoApp+Injection.swift
//  FactoryDemo
//
//  Created by Michael Long on 6/2/22.
//

import Foundation
import Factory
import Common
import SwiftUI

extension Container {

    var simpleService: Factory<SimpleService> {
        self { SimpleService() }
    }

    var simpleService2: Factory<SimpleService> {
        register { SimpleService() }
    }

    var simpleService3: Factory<SimpleService> {
        unique { SimpleService() }
    }

    var simpleService4: Factory<SimpleService> {
        singleton { SimpleService() }
    }

}

extension Container {
    var contentViewModel: Factory<ContentModuleViewModel> { self { ContentModuleViewModel() } }
}

extension SharedContainer {
    var myServiceType: Factory<MyServiceType> { self { MyService() } }
    var sharedService: Factory<MyServiceType> { self { MyService() }.shared }
}

final class DemoContainer: ObservableObject, SharedContainer {
    static var shared = DemoContainer()

    var optionalService: Factory<SimpleService?> { self { nil } }

    var constructedService: Factory<MyConstructedService> {
        self {
            MyConstructedService(service: self.myServiceType())
        }
    }

    var additionalService: Factory<SimpleService> {
        self { SimpleService() }
            .custom(scope: .session)
    }

    var manager = ContainerManager()
}

extension DemoContainer {
    var argumentService: ParameterFactory<Int, ParameterService> {
        self { count in ParameterService(count: count) }
    }
}

extension DemoContainer {
    var selfService: Factory<MyServiceType> {
        self { MyService() }
    }
}

#if DEBUG
extension DemoContainer {
    static var mock1: DemoContainer {
        shared.myServiceType.register { ParameterService(count: 3) }
        return shared
    }
}
#endif

extension Scope {
    static var session = Cached()
}

extension Container {
    func setupMocks() {
        myServiceType.register { MockServiceN(4) }

        DemoContainer.shared.optionalService.register { SimpleService() }

    }
}

// implements

class CycleDemo {
    @Injected(\.aService) var aService: AServiceType
    @Injected(\.bService) var bService: BServiceType
}

public protocol AServiceType: AnyObject {
    var id: UUID { get }
}

public protocol BServiceType: AnyObject {
    func text() -> String
}

class ImplementsAB: AServiceType, BServiceType {
    @Injected(\.networkService) var networkService
    var id: UUID = UUID()
    func text() -> String {
        "Multiple"
    }
}

class NetworkService {
    @LazyInjected(\.preferences) var preferences
    func load() {}
}

class Preferences {
    func load() {}
}

extension Container {
    var cycleDemo: Factory<CycleDemo> {
        self { CycleDemo() }
    }
    var aService: Factory<AServiceType> {
        self { self.implementsAB() }
    }
    var bService: Factory<BServiceType> {
        self { self.implementsAB() }
    }
    var networkService: Factory<NetworkService> {
        self { NetworkService() }
    }
    var preferences: Factory<Preferences> {
        self { Preferences() }
    }
    private var implementsAB: Factory<AServiceType&BServiceType> {
        self { ImplementsAB() }.singleton
    }
}

extension SharedContainer {
//    @inlinable public func scope<T>(_ scope: Scope?, key: String = #function, _ factory: @escaping () -> T) -> Factory<T> {
//        Factory(self, key: key, factory).custom(scope: scope)
//    }
//
//    var someOtherService: Factory<MyServiceType> { scope(.shared) { MyService() } }
}

