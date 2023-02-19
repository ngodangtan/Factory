//
// Factory.swift
//
// GitHub Repo and Documentation: https://github.com/hmlongco/Factory
//
// Copyright © 2022 Michael Long. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation

// MARK: - Factory

/// A Factory manages the dependency injection process for a specific object or service.
///
/// It's used to produce an object of the desired type when required. This may be a brand new instance or Factory may
/// return a previously cached value from the specified scope.
///
/// ## Defining a Factory
/// Let's define a Factory that returns an instance of `ServiceType`. To do that we need to extend a Factory `Container` and within
/// that container we define a new computed variable of type `Factory<ServiceType>`. The type must be explicitly defined, and is usually a
/// protocol to which the returned dependency conforms.
/// ```swift
/// extension Container {
///     var service: Factory<ServiceType> {
///         self { MyService() }
///     }
/// }
/// ```
/// Inside the computed variable we ask our container to make our factory for us, providing it a closure that
/// creates an instance of our dependency when required. That Factory is then returned to the caller, usually to be evaluated (see `callAsFunction()`
/// below). Every time we resolve this factory we'll get a new, unique instance of our object.
///
/// ## Transient
/// If you're concerned about building Factory's on the fly, don't be. Like SwiftUI Views, Factory structs and modifiers
/// are lightweight and transitory. They're created when needed and then immediately discarded once their purpose has
/// been served.
///
/// Other operations exist for Factory. See ``FactoryModifing``.
public struct Factory<T>: FactoryModifing {

    /// Private initializer creates a Factory capable of managing dependencies of the desired type.
    ///
    /// - Parameters:
    ///   - container: The bound container that manages registrations and scope caching for this Factory. The scope helper functions bind the
    ///   current container as well defining the scope.
    ///   - key: Hidden value used to differentiate different instances of the same type in the same container.
    ///   - factory: A factory closure that produces an object of the desired type when required.
    fileprivate init(_ container: SharedContainer, key: String = #function, _ factory: @escaping () -> T) {
        self.registration = FactoryRegistration<Void,T>(id: "\(container.self).\(key)", container: container, factory: factory)
    }

    /// Evaluates the factory and returns an object or service of the desired type. The resolved instance may be brand new or Factory may
    /// return a cached value from the specified scope.
    ///
    /// To resolve the Factory  one simply calls the Factory as a function. Here we use the `shared` container that's provided for each
    /// and every container type.
    /// ```swift
    /// let service = Container.shared.service()
    /// ```
    /// The resolved instance may be brand new or Factory may return a cached value from the specified ``Scope``.
    ///
    /// If you're passing an instance of a container around to your views or view models, just call it directly.
    /// ```swift
    /// let service = container.service()
    /// ```
    /// Finally, you can also use the @Injected property wrapper and specify a keyPaths to the desired dependency.
    /// ```swift
    /// @Injected(\.service) var service: ServiceType
    /// ```
    /// Unless otherwise specified, the @Injected property wrapper looks for dependencies in the standard shared container provided by Factory,
    /// so the above example is functionally identical to the `Container.shared.service()` example shown earlier. Here's one pointing to
    /// your own container.
    /// ```swift
    /// @Injected(\MyCustomContainer.service) var service: ServiceType
    /// ```
    /// - Returns: An object or service of the desired type.
    public func callAsFunction() -> T {
        registration.container.manager.resolve(registration, with: ())
    }

    /// Registers a new factory closure capable of producing an object or service of the desired type.
    ///
    /// This factory overrides the original factory closure and clears the associated scope so that the next time this factory is resolved
    /// Factory will evaluate the new closure and return an instance of the newly registered object instead.
    ///
    /// Here's an example of registering a new Factory closure.
    /// ```swift
    /// container.service.register {
    ///     SomeService()
    /// }
    /// ```
    /// This is how default functionality is overridden in order to change the nature of the system at runtime, and is the primary mechanism
    /// used to provide mocks and testing doubles.
    ///
    /// Registration "overrides" are stored in the associated container. If the container ever goes our of scope, so
    /// will all of its registrations.
    ///
    /// The original factory closure is preserved, and may be restored by resetting the Factory to its original state.
    ///
    /// - Parameter factory: A new factory closure that produces an object of the desired type when needed.
    public func register(factory: @escaping () -> T) {
        registration.container.manager.register(id: registration.id, factory: TypedFactory<Void,T>(factory: factory))
    }

    /// Internal parameters fort his Factory including id, container, the factory closure itself, the scope,
    /// and others.
    public var registration: FactoryRegistration<Void,T>

}

// MARK: ParameterFactory

/// Factory capable of taking parameters at runtime
///
/// Like it or not, some services require one or more parameters to be passed to them in order to be initialized correctly. In that case use `ParameterFactory`.
///
/// We define a ParameterFactory exactly as we do a normal factory with two exceptions: we need to specfic the
/// parameter type, and we need to consume the passed parameter in our factory closure.
/// ```swift
/// extension Container {
///     var parameterService: ParameterFactory<Int, MyServiceType> {
///        self { ParameterService(value: $0) }
///     }
/// }
/// ```
/// Resolving it is straightforward. Just pass the paramter to the Factory.
/// ```Swift
/// let myService = Container.shared.parameterService(n)
/// ```
/// One caveat is that you can't use the `@Injected` property wrapper with `ParameterFactory` as there's no way to get
/// the needed parameters to the property wrapper before the wrapper is initialized. That being the case, you'll
/// probably need to reference the container directly and do something similar to the following.
///  ```swift
///  class MyClass {
///      var myService: MyServiceType
///      init(_ n: Int) {
///          myService = Container.shared.parameterService(n)
///      }
///  }
/// ```
/// If you need to pass more than one parameter just use a tuple, dictionary, or struct.
/// ```swift
/// var tupleService: ParameterFactory<(Int, Int), MultipleParameterService> {
///     self { (a, b) in
///         MultipleParameterService(a: a, b: b)
///     }
/// }
/// ```
/// Finally, if you define a scope keep in mind that the first argument passed will be used to create the dependency
/// and *that* dependency will be cached. Since the cached object will be returned from now on any arguments passed in
/// later requests will be ignored until the factory or scope is reset.
public struct ParameterFactory<P,T>: FactoryModifing {

    /// Private initializer creates a factory capable of taking parameters at runtime.
    /// ```swift
    /// var parameterService: ParameterFactory<Int, ParameterService> {
    ///     ParameterFactory(self) { ParameterService(value: $0) }
    /// }
    /// ```
    fileprivate init(_ container: SharedContainer, key: String = #function, _ factory: @escaping (P) -> T) {
        self.registration = FactoryRegistration<P,T>(id: "\(container.self).\(key)", container: container, factory: factory)
    }

    /// Resolves a factory capable of taking parameters at runtime.
    /// ```swift
    /// let service = container.parameterService(16)
    /// ```
    public func callAsFunction(_ parameters: P) -> T {
        registration.container.manager.resolve(registration, with: parameters)
    }

    /// Registers a new factory capable of taking parameters at runtime.
    /// ```swift
    /// container.parameterService.register { n in
    ///     ParameterService(value: n)
    /// }
    /// ```
    public func register(factory: @escaping (P) -> T) {
        registration.container.manager.register(id: registration.id, factory: TypedFactory<P,T>(factory: factory))
    }

    /// Required registration
    public var registration: FactoryRegistration<P,T>

}

// MARK: Factory Modifiers

/// Public protocol with functionality common to all Factory's. Used to add scope and decorator modifiers to Factory.
public protocol FactoryModifing {
    /// The parameter type of the Factory, if any. Will be `Void` on the standard Factory.
    associatedtype P
    /// The return type of the Factory's dependency.
    associatedtype T
    /// Internal information that desribes this Factory.
    var registration: FactoryRegistration<P,T> { get set }
}

extension FactoryModifing {

    /// Defines this Factory's dependency scope to be cached. See ``Scope/Cached-swift.class``.
    /// ```swift
    /// var service: Factory<ServiceType> {
    ///     self { MyService() }
    ///         .cached
    /// }
    /// ```
   public var cached: Self {
        map { $0.registration.scope = .cached }
    }
    /// Defines this Factory's dependency scope to be graph. See ``Scope/Graph-swift.class``.
    /// ```swift
    /// var service: Factory<ServiceType> {
    ///     self { MyService() }
    ///         .graph
    /// }
    /// ```
    public var graph: Self {
        map { $0.registration.scope = .graph }
    }
    /// Defines this Factory's dependency scope to be shared. See ``Scope/Graph-swift.class``.
    /// ```swift
    /// var service: Factory<ServiceType> {
    ///     self { MyService() }
    ///         .shared
    /// }
    /// ```
    public var shared: Self {
        map { $0.registration.scope = .shared }
    }
    /// Defines this Factory's dependency scope to be singleton. See ``Scope/Singleton-swift.class``.
    /// ```swift
    /// var service: Factory<ServiceType> {
    ///     self { MyService() }
    ///         .singleton
    /// }
    /// ```
    public var singleton: Self {
        map { $0.registration.scope = .singleton }
    }
    /// Explicitly defines unique scope. See ``Scope``.
    /// ```swift
    /// var service: Factory<ServiceType> {
    ///     self { MyService() }
    /// }
    /// ```
    /// While you can add the modifier, Factory's are unique by default.
    public var unique: Self {
        map { $0.registration.scope = nil }
    }
    /// Defines a custom dependency scope for this Factory. See ``Scope``.
    /// ```swift
    /// var service: Factory<ServiceType> {
    ///     self { MyService() }
    ///         .custom(scope: .session)
    /// }
    /// ```
    public func custom(scope: Scope?) -> Self {
        map { $0.registration.scope = scope }
    }

    /// Adds a factory specific decorator. The decorator will be *always* be called with the resolved dependency
    /// for further examination or manipulation.
    ///
    /// This includes previously created items that may have been cached by a scope.
    /// ```swift
    /// var decoratedService: Factory<ParentChildService> {
    ///    self { ParentChildService() }
    ///        .decorated {
    ///            $0.child.parent = $0
    ///        }
    /// }
    /// ```
    /// As shown, decorator can come in handy when you need to perform some operation or manipulation after the fact.
    public func decorator(_ decorator: @escaping (_ instance: T) -> Void) -> Self {
        map { $0.registration.decorator = decorator }
    }

    /// Resets the Factory's behavior to its original state, removing any registrations and clearing any cached items from the specified scope.
    /// - Parameter options: options description
    public func reset(_ options: ContainerManager.ResetOptions = .all) {
        registration.container.manager.reset(options: options, for: registration.id)
    }

}

extension FactoryModifing {
    /// Allows builder-style mutation of self
    fileprivate func map (_ mutate: (inout Self) -> Void) -> Self {
        var mutable = self
        mutate(&mutable)
        return mutable
    }
}

// MARK: - Container

/// This is the default Container provided for your convenience by Factory.
///
/// Containers are used by Factory to manage object creation, object resolution, and object lifecycles in general.
///
/// Factory's are defined within container extensions, and must be provided with a reference to that container on initialization.
/// ```swift
/// extension Container {
///     var service: Factory<ServiceType> {
///         Factory(self) { MyService() }
///     }
/// }
/// ```
///  Registrations and scope caches will persist as long as the associated container remains in scope.
///
///  See <doc:Containers> for more information.
public final class Container: SharedContainer {

    /// Define the default shared container.
    public static var shared = Container()

    /// Define the container's manager.
    public var manager: ContainerManager = ContainerManager()

    /// Public initializer
    public init() {}

}

// MARK: - SharedContainer

/// SharedContainer defines the protocol all Containers must adopt.
///
///  See <doc:Containers> for more information.
public protocol SharedContainer: AnyObject {

    /// Defines a single "shared" container for that container type.
    ///
    /// This container is used by the various @Injected property wrappers to resolve the keyPath to a given Factory. Care should be taken in
    /// mixed environments where you're passing container references AND using the @Injected property wrappers.
    static var shared: Self { get }

    /// Defines the ContainerManager used to manage registrations, resolutions, and scope caching for that container. Encapsulating the code in
    /// this fashion makes creating and using your own custom containers much simpler.
    var manager: ContainerManager { get set }
}

/// Defines the default factory providers for containers
extension SharedContainer {

    /// Creates and returns a Factory struct associated with the current container. The default scope is
    /// `unique` unless otherwise specified using a scope modifier.
    public func callAsFunction<T>(key: String = #function, _ factory: @escaping () -> T) -> Factory<T> {
        Factory(self, key: key, factory)
    }

    /// Not sure about this one yet.
    public func register<T>(key: String = #function, _ factory: @escaping () -> T) -> Factory<T> {
        Factory(self, key: key, factory)
    }

    /// Creates and returns a ParameterFactory struct associated with the current container. The default scope is
    /// `unique` unless otherwise specified using a scope modifier.
    public func callAsFunction<P,T>(key: String = #function, _ factory: @escaping (P) -> T) -> ParameterFactory<P,T> {
        ParameterFactory(self, key: key, factory)
    }

    /// Not sure about this one yet.
    public func register<P,T>(key: String = #function, _ factory: @escaping (P) -> T) -> ParameterFactory<P,T> {
        ParameterFactory(self, key: key, factory)
    }

    /// Defines a decorator for the container. This decorator will see every dependency resolved by this container.
    public func decorator(_ decorator: ((Any) -> ())?) {
        manager.decorator = decorator
    }

    /// Defines a with function to allow container transformation on assignment.
    @discardableResult
    public func with(_ transform: (Self) -> Void) -> Self {
        transform(self)
        return self
    }
}

// MARK: - ContainerManager

/// ContainerManager encapsulates and manages the registration, resolution, and scope caching mechanisms for a given container.
///
/// Every container requires a ContainerManager.
///
/// ContainerManager also implements several functions tha can be used to reset the container
/// to a pristine state, as well as push/pop methods that can save and restore the current state.
///
/// Those functions are designed primarily for testing.
public class ContainerManager {

    /// Public initializer
    public init() {}

    /// Public variable exposing dependency chain test maximum
    public var dependencyChainTestMax: Int = 10

    /// Public var enabling factory resolution trace statements in debug mode for ALL containers.
    public var trace: Bool {
        get { globalTraceFlag }
        set { globalTraceFlag = newValue }
    }

    /// Public access to logging facility in debug mode for ALL containers.
    public var logger: (String) -> Void {
        get { globalLogger }
        set { globalLogger = newValue }
    }

    /// Internal closure decorates all factory resolutions for this container.
    internal var decorator: ((Any) -> ())?
    internal var autoRegistrationCheck = true
    internal typealias FactoryMap = [String:AnyFactory]
    internal lazy var registrations: FactoryMap = .init(minimumCapacity: 32)
    internal lazy var cache: Scope.Cache = Scope.Cache()
    internal lazy var stack: [(FactoryMap, Scope.Cache.CacheMap, Bool)] = []

}

extension ContainerManager {

    /// Reset options for Factory's and Container's
    public enum ResetOptions {
        /// Resets registration and scope caches
        case all
        /// Performs no reset
        case none
        /// Resets registrations on this container
        case registration
        /// Resets all scope caches on this container
        case scope
    }

    /// Resets the Container to its original state, removing all registrations and clearing all scope caches.
    public func reset(options: ResetOptions = .all) {
        guard options != .none else {
            return
        }
        defer { globalRecursiveLock.unlock() }
        globalRecursiveLock.lock()
        switch options {
        case .registration:
            registrations = [:]
            autoRegistrationCheck = false
        case .scope:
            cache.reset()
        default:
            registrations = [:]
            cache.reset()
            autoRegistrationCheck = false
        }
    }

    /// Clears any cached values associated with a specific scope, leaving the other scope caches intact.
    public func reset(scope: Scope) {
        defer { globalRecursiveLock.unlock() }
        globalRecursiveLock.lock()
        cache.reset(scope: scope)
    }

    /// Test function pushes the current registration and cache states
    public func push() {
        defer { globalRecursiveLock.unlock() }
        globalRecursiveLock.lock()
        stack.append((registrations, cache.cache, autoRegistrationCheck))
    }

    /// Test function pops and restores a previously pushed registration and cache state
    public func pop() {
        defer { globalRecursiveLock.unlock() }
        globalRecursiveLock.lock()
        if let state = stack.popLast() {
            registrations = state.0
            cache.cache = state.1
            autoRegistrationCheck = state.2
        }
    }

}

extension ContainerManager {

    /// Resolves a Factory, returning an instance of the desired type. All roads lead here.
    ///
    /// - Parameter factory: Factory wanting resolution.
    /// - Returns: Instance of the desired type.
    internal func resolve<P,T>(_ registration: FactoryRegistration<P,T>, with parameters: P) -> T {
        defer { globalRecursiveLock.unlock() }
        globalRecursiveLock.lock()

        if autoRegistrationCheck {
            (registration.container as? AutoRegistering)?.autoRegister()
            autoRegistrationCheck = false
        }

        var current: (P) -> T = (registrations[registration.id] as? TypedFactory<P,T>)?.factory ?? registration.factory

        #if DEBUG
        if dependencyChainTestMax > 0 {
            circularDependencyChainCheck(for: String(reflecting: T.self))
        }

        let traceLevel = globalTraceResolutions.count
        var traceNew = false
        if trace {
            let wrapped = current
            current = {
                traceNew = true // detects if new instance created
                return wrapped($0)
            }
            globalTraceResolutions.append("")
        }
        #endif

        globalGraphResolutionDepth += 1
        let instance = registration.scope?.resolve(using: cache, id: registration.id, factory: { current(parameters) }) ?? current(parameters)
        globalGraphResolutionDepth -= 1

        if globalGraphResolutionDepth == 0 {
            Scope.graph.cache.reset()
            #if DEBUG
            globalDependencyChainMessages = []
            #endif
        }

        #if DEBUG
        if !globalDependencyChain.isEmpty {
            globalDependencyChain.removeLast()
        }

        if trace {
            let indent = String(repeating: " ", count: globalGraphResolutionDepth * 4)
            let type = type(of: instance)
            let address = Int(bitPattern: ObjectIdentifier(instance as AnyObject))
            let new = traceNew ? "N" : "C"
            let traced = "\(globalGraphResolutionDepth): \(indent)\(registration.id) = \(type) \(new):\(address)"
            globalTraceResolutions[traceLevel] = traced
            if globalGraphResolutionDepth == 0 {
                globalTraceResolutions.forEach { self.logger($0) }
                globalTraceResolutions = []
            }
        }
        #endif

        registration.decorator?(instance)
        decorator?(instance)

        return instance
    }

    /// Registers a new factory closure capable of producing an object or service of the desired type. This factory overrides the original factory and
    /// the next time this factory is resolved Factory will evaluate the newly registered factory instead.
    /// - Parameters:
    ///   - id: ID of associated Factory.
    ///   - factory: Factory closure called to create a new instance of the service when needed.
    internal func register(id: String, factory: AnyFactory) {
        defer { globalRecursiveLock.unlock() }
        globalRecursiveLock.lock()
        registrations[id] = factory
        cache.removeValue(forKey: id)
    }

    /// Support function resets the behavior for a specific Factory to its original state, removing any associated registrations and clearing
    /// any cached instances from the specified scope.
    /// - Parameters:
    ///   - options: Reset option: .all, .registration, .scope, .none
    ///   - id: ID of item to remove from the appropriate cache.
    internal func reset(options: ResetOptions, for id: String) {
        guard options != .none else { return }
        defer { globalRecursiveLock.unlock() }
        globalRecursiveLock.lock()
        switch options {
        case .registration:
            registrations.removeValue(forKey: id)
        case .scope:
            cache.removeValue(forKey: id)
        default:
            registrations.removeValue(forKey: id)
            cache.removeValue(forKey: id)
        }
    }

    #if DEBUG
    internal func circularDependencyChainCheck(for typeName: String) {
        let typeComponents = typeName.components(separatedBy: CharacterSet(charactersIn: "<>"))
        let typeName = typeComponents.count > 1 ? typeComponents[1] : typeComponents[0]
        let typeIndex = globalDependencyChain.firstIndex(where: { $0 == typeName })
        globalDependencyChain.append(typeName)
        if let index = typeIndex {
            let chain = globalDependencyChain[index...]
            let message = "circular dependency chain - \(chain.joined(separator: " > "))"
            if globalDependencyChainMessages.filter({ $0 == message }).count == dependencyChainTestMax {
                globalDependencyChain = []
                globalDependencyChainMessages = []
                globalGraphResolutionDepth = 0
                globalRecursiveLock = NSRecursiveLock()
                globalTraceResolutions = []
                triggerFatalError(message, #file, #line)
            } else {
                globalDependencyChain = [typeName]
                globalDependencyChainMessages.append(message)
            }
        }
    }
    #endif
}

// MARK: - Scope

/// Scopes are used to define the lifetime of resolved dependencies. Factory provides several scope types,
/// including `Singleton`, `Cached`, `Graph`, and `Shared`.
///
/// When a scope is associated with a Factory the first time the dependency is resolved a reference to that object
/// is cached. The next time that Factory is resolved a reference to the originally cached object will be returned.
///
/// That behavior can vary according to the scope type (e.g. Shared or Graph)
/// ```swift
/// extension Container {
///     var service: Factory<ServiceType> {
///         self { MyService() }.singleton
///     }
/// }
/// ```
/// Scopes work hand in hand with Containers to managed object lifecycles. If the container ever goes our of scope, so
/// will all of its cached references.
///
/// If no scope is associated with a given Factory then the scope is considered to be unique and a new instance
/// of the dependency will be created each and every time that factory is resolved.
public class Scope {

    fileprivate init() {}

    /// Internal function returns cached value if it exists. Otherwise it creates a new instance and caches that value for later reference.
    internal func resolve<T>(using cache: Cache, id: String, factory: () -> T) -> T {
        if let cached: T = unboxed(box: cache.value(forKey: id)) {
            return cached
        }
        let instance = factory()
        if let box = box(instance) {
            cache.set(value: box, forKey: id)
        }
        return instance
    }

    /// Internal function returns unboxed value if it exists
    fileprivate func unboxed<T>(box: AnyBox?) -> T? {
        if let box = box as? StrongBox<T> {
            return box.boxed
        }
        return nil
    }

    /// Internal function correctly boxes value depending upon scope type
    fileprivate func box<T>(_ instance: T) -> AnyBox? {
        if let optional = instance as? OptionalProtocol {
            return optional.hasWrappedValue ? StrongBox<T>(scopeID: scopeID, boxed: instance) : nil
        }
        return StrongBox<T>(scopeID: scopeID, boxed: instance)
    }

    internal let scopeID: UUID = UUID()

}

extension Scope {

    /// A reference to the default cached scope manager.
    public static let cached = Cached()

    /// Defines a cached scope. The same instance will be returned by the factory until the cache is reset.
    public final class Cached: Scope {
        public override init() {
            super.init()
        }
    }

    /// A reference to the default graph scope manager.
    public static let graph = Graph()

    /// Defines the graph scope. A single instance of a given type will be returned during a given resolution cycle.
    ///
    /// This scope is managed and cleared by the main resolution function at the end of each resolution cycle.
    public final class Graph: Scope {
        public override init() {
            super.init()
        }
        internal override func resolve<T>(using cache: Cache, id: String, factory: () -> T) -> T {
            // ignores passed cache
            return super.resolve(using: self.cache, id: id, factory: factory)
        }
        /// Private shared cache
        internal var cache = Cache()
    }

    /// A reference to the default shared scope manager.
    public static let shared = Shared()

    /// Defines a shared (weak) scope. The same instance will be returned by the factory as long as someone maintains a strong reference.
    public final class Shared: Scope {
        public override init() {
            super.init()
        }
        /// Internal function returns cached value if exists
        fileprivate override func unboxed<T>(box: AnyBox?) -> T? {
            if let box = box as? WeakBox, let instance = box.boxed as? T {
                if let optional = instance as? OptionalProtocol {
                    if optional.hasWrappedValue {
                        return instance
                    }
                } else {
                    return instance
                }
            }
            return nil
        }
        /// Override function correctly boxes weak cache value
        fileprivate override func box<T>(_ instance: T) -> AnyBox? {
            if let optional = instance as? OptionalProtocol {
                if let unwrapped = optional.wrappedValue, type(of: unwrapped) is AnyObject.Type {
                    return WeakBox(scopeID: scopeID, boxed: unwrapped as AnyObject)
                }
            } else if type(of: instance as Any) is AnyObject.Type {
                return WeakBox(scopeID: scopeID, boxed: instance as AnyObject)
            }
            return nil
        }
    }

    /// A reference to the default singleton scope manager.
    public static let singleton = Singleton()

    /// Defines the singleton scope. The same instance will always be returned by the factory.
    public final class Singleton: Scope {
        public override init() {
            super.init()
        }
    }

}

extension Scope {

    internal class Cache {
        typealias CacheMap = [String:AnyBox]
        /// Internal support functions
        @inlinable func value(forKey key: String) -> AnyBox? {
            cache[key]
        }
        @inlinable func set(value: AnyBox, forKey key: String)  {
            cache[key] = value
        }
        @inlinable func removeValue(forKey key: String) {
            cache.removeValue(forKey: key)
        }
        internal func reset(scope: Scope) {
            cache = cache.filter { $1.scopeID != scope.scopeID }
        }
        /// Internal function to clear cache if needed
        @inlinable func reset() {
            if !cache.isEmpty {
                cache = [:]
            }
        }
        var cache: CacheMap = .init(minimumCapacity: 32)
        #if DEBUG
        internal var isEmpty: Bool {
            cache.isEmpty
        }
        #endif
   }

}

/// MARK: - Automatic Registrations

/// Adds an registration "hook" to a `Container`.
///
/// Add this protocol to a container to support first-time registration of needed dependencies prior to first resolution
/// of a dependency on that container.
/// ```swift
/// extension Container: AutoRegistering {
///     func autoRegister() {
///         someService.register {
///             CrossModuleService()
///         }
///     }
/// }
///```
/// The `autoRegister` function is called on each instantiated container prior to
/// the first resolution of a Factory on that container.
///
/// > Warning: Calling `container.manager.reset(options: .all)` restores the container to it's initial state
/// and autoRegister will be called again if it exists.
public protocol AutoRegistering {
    /// User provided function that supports first-time registration of needed dependencies prior to first resolution
    /// of a dependency on that container.
    func autoRegister()
}

// MARK: - Property wrappers

#if swift(>=5.1)

/// Convenience property wrapper takes a factory and resolves an instance of the desired type.
///
/// Property wrappers implement an annotation pattern to resolving dependencies, similar to using
/// EnvironmentObject in SwiftUI.
/// ```swift
/// class MyViewModel {
///    @Injected(\.myService) var service
///    @Injected(\MyCustomContainer.myService) var service
/// }
/// ```
/// The provided keypath resolves to a Factory definition on the `shared` container required for each Container type.
/// The short version of the keyPath resolves to the default container, while the expanded version
/// allows you to point an instance on your own customer container type.
///
/// > Note: The @Injected property wrapper will be resolved on **intialization**. In the above example
/// the referenced dependencies will be acquired when the parent class is created.
@propertyWrapper public struct Injected<T> {

    private var reference: BoxedFactoryReference
    private var dependency: T

    /// Initializes the property wrapper. The dependency is resolved on initialization.
    /// - Parameter keyPath: KeyPath to a Factory on the default Container.
    public init(_ keyPath: KeyPath<Container, Factory<T>>) {
        self.reference = FactoryReference<Container, T>(keypath: keyPath)
        self.dependency = Container.shared[keyPath: keyPath]()
    }

    /// Initializes the property wrapper. The dependency is resolved on initialization.
    /// - Parameter keyPath: KeyPath to a Factory on the specified Container.
    public init<C:SharedContainer>(_ keyPath: KeyPath<C, Factory<T>>) {
        self.reference = FactoryReference<C, T>(keypath: keyPath)
        self.dependency = C.shared[keyPath: keyPath]()
    }

    /// Manages the wrapped dependency.
    public var wrappedValue: T {
        get { return dependency }
        mutating set { dependency = newValue }
    }

    /// Unwraps the property wrapper granting access to the resolve/reset function.
    public var projectedValue: Injected<T> {
        get { return self }
        mutating set { self = newValue }
    }

    /// Grants access to the internal Factory.
    public var factory: Factory<T> {
        reference.factory()
    }

    /// Allows the user to force a Factory resolution at their descretion.
    public mutating func resolve(reset options: ContainerManager.ResetOptions = .none) {
        factory.reset(options)
        dependency = factory()
    }
}

/// Convenience property wrapper takes a factory and resolves an instance of the desired type the first time the wrapped value is requested.
///
/// Property wrappers implement an annotation pattern to resolving dependencies, similar to using
/// EnvironmentObject in SwiftUI.
/// ```swift
/// class MyViewModel {
///    @LazyInjected(\.myService) var service
///    @LazyInjected(\MyCustomContainer.myService) var service
/// }
/// ```
/// The provided keypath resolves to a Factory definition on the `shared` container required for each Container type.
/// The short version of the keyPath resolves to the default container, while the expanded version
/// allows you to point an instance on your own customer container type.
///
/// > Note: Lazy injection is resolved the first time the dependency is referenced by the code, and **not** on initilization.
@propertyWrapper public struct LazyInjected<T> {

    private var reference: BoxedFactoryReference
    private var dependency: T!
    private var initialize = true

    /// Initializes the property wrapper. The dependency isn't resolved until the wrapped value is accessed for the first time.
    /// - Parameter keyPath: KeyPath to a Factory on the default Container.
    public init(_ keyPath: KeyPath<Container, Factory<T>>) {
        self.reference = FactoryReference<Container, T>(keypath: keyPath)
    }

    /// Initializes the property wrapper. The dependency isn't resolved until the wrapped value is accessed for the first time.
    /// - Parameter keyPath: KeyPath to a Factory on the specified Container.
    public init<C:SharedContainer>(_ keyPath: KeyPath<C, Factory<T>>) {
        self.reference = FactoryReference<C, T>(keypath: keyPath)
    }

    /// Manages the wrapped dependency, which is resolved when this value is accessed for the first time.
    public var wrappedValue: T {
        mutating get {
            defer { globalRecursiveLock.unlock() }
            globalRecursiveLock.lock()
            if initialize {
                resolve()
            }
            return dependency
        }
        mutating set {
            dependency = newValue
        }
    }

    /// Unwraps the property wrapper granting access to the resolve/reset function.
    public var projectedValue: LazyInjected<T> {
        get { return self }
        mutating set { self = newValue }
    }

    /// Grants access to the internal Factory.
    public var factory: Factory<T> {
        reference.factory()
    }

    /// Allows the user to force a Factory resolution at their descretion.
    public mutating func resolve(reset options: ContainerManager.ResetOptions = .none) {
        factory.reset(options)
        dependency = factory()
        initialize = false
    }
}

/// Convenience property wrapper takes a factory and resolves an instance of the desired type the first time the wrapped value is requested.
///
/// This wrapper maintains a weak reference to the object in question, so it must exist elsewhere.t
/// It's useful for delegate patterns and parent/child relationships.
///
/// Property wrappers implement an annotation pattern to resolving dependencies, similar to using
/// EnvironmentObject in SwiftUI.
///
/// ```swift
/// class MyViewModel {
///    @LazyInjected(\.myService) var service
///    @LazyInjected(\MyCustomContainer.myService) var service
/// }
/// ```
/// The provided keypath resolves to a Factory definition on the `shared` container required for each Container type.
/// The short version of the keyPath resolves to the default container, while the expanded version
/// allows you to point an instance on your own customer container type.
///
/// > Note: Lazy injection is resolved the first time the dependency is referenced by the code, **not** on initilization.
@propertyWrapper public struct WeakLazyInjected<T> {

    private var reference: BoxedFactoryReference
    private weak var dependency: AnyObject?
    private var initialize = true

    /// Initializes the property wrapper. The dependency isn't resolved until the wrapped value is accessed for the first time.
    /// - Parameter keyPath: KeyPath to a Factory on the default Container.
    public init(_ keyPath: KeyPath<Container, Factory<T>>) {
        self.reference = FactoryReference<Container, T>(keypath: keyPath)
    }

    /// Initializes the property wrapper. The dependency isn't resolved until the wrapped value is accessed for the first time.
    /// - Parameter keyPath: KeyPath to a Factory on the specified Container.
    public init<C:SharedContainer>(_ keyPath: KeyPath<C, Factory<T>>) {
        self.reference = FactoryReference<C, T>(keypath: keyPath)
    }

    /// Manages the wrapped dependency, which is resolved when this value is accessed for the first time.
    public var wrappedValue: T? {
        mutating get {
            defer { globalRecursiveLock.unlock() }
            globalRecursiveLock.lock()
            if initialize {
                resolve()
            }
            return dependency as? T
        }
        mutating set {
            dependency = newValue as AnyObject
        }
    }

    /// Unwraps the property wrapper granting access to the resolve/reset function.
    public var projectedValue: WeakLazyInjected<T> {
        get { return self }
        mutating set { self = newValue }
    }

    /// Grants access to the internal Factory.
    public var factory: Factory<T> {
        reference.factory()
    }

    /// Allows the user to force a Factory resolution at their descretion.
    public mutating func resolve(reset options: ContainerManager.ResetOptions = .none) {
        factory.reset(options)
        dependency = factory() as AnyObject
        initialize = false
    }
}

/// Boxed wrapper to provide a Factory when asked
internal protocol BoxedFactoryReference {
    func factory<T>() -> Factory<T>
}

/// Helps resolve a reference to an injected factory's shared container without actually storing a Factory along
/// with its hard, reference-counted pointer to that container.
internal struct FactoryReference<C: SharedContainer, T>: BoxedFactoryReference {
    /// The stored factory keypath on the container
    let keypath: KeyPath<C, Factory<T>>
    /// Resolves the current shared container on the given type and returns the Factory referenced by the keyPath.
    /// Note that types matched going in, so it's safe to explicitly cast it coming back out.
    func factory<T>() -> Factory<T> {
        C.shared[keyPath: keypath] as! Factory<T>
    }
}

#endif

// MARK: - Internal Variables

/// Master recursive lock
private var globalRecursiveLock = NSRecursiveLock()

/// Master graph resolution depth counter
private var globalGraphResolutionDepth = 0

#if DEBUG
/// Internal variables used for debugging
private var globalDependencyChain: [String] = []
private var globalDependencyChainMessages: [String] = []
private var globalTraceFlag: Bool = false
private var globalTraceResolutions: [String] = []
private var globalLogger: (String) -> Void = { print($0) }
#endif

// MARK: - Internal Protocols and Types

/// Shared registration type for Factory and ParameterFactory. Used internally to pass information from Factory to ContainerManager.
public struct FactoryRegistration<P,T> {
    /// Id used to manage registrations and cached values. Usually looks something like "MyApp.Container.service".
    internal var id: String
    /// A strong reference to the container supporting this Factory.
    internal var container: SharedContainer
    /// The originally registered factory closure used to produce an object of the desired type.
    internal var factory: (P) -> T
    /// The scope responsible for managing the lifecycle of any objects created by this Factory.
    internal var scope: Scope?
    /// Decorator will be passed fully constructed instance for further configuration.
    internal var decorator: ((T) -> Void)?
}

// Internal Factory type
internal protocol AnyFactory {
}

internal struct TypedFactory<P,T>: AnyFactory {
    let factory: (P) -> T
}

/// Internal protocol used to evaluate optional types for caching
internal protocol OptionalProtocol {
    var hasWrappedValue: Bool { get }
    var wrappedValue: Any? { get }
}

extension Optional: OptionalProtocol {
    @inlinable internal var hasWrappedValue: Bool {
        wrappedValue != nil
    }
    @inlinable internal var wrappedValue: Any? {
        if case .some(let value) = self {
            return value
        }
        return nil
    }
}

/// Internal box protocol for scope functionality
internal protocol AnyBox {
    var scopeID: UUID { get }
}

/// Strong box for strong references to a type
private struct StrongBox<T>: AnyBox {
    let scopeID: UUID
    let boxed: T
}

/// Weak box for shared scope
private struct WeakBox: AnyBox {
    let scopeID: UUID
    weak var boxed: AnyObject?
}

#if DEBUG
/// Allow unit test interception of any fatal errors that may occur running the circular dependency check
/// Variation of solution: https://stackoverflow.com/questions/32873212/unit-test-fatalerror-in-swift#
internal var triggerFatalError = Swift.fatalError
#endif
