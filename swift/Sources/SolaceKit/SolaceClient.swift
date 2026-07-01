import Foundation
import SolaceCore

public typealias SolaceConfiguration = SolaceConnectionConfiguration
public typealias Message = SolaceMessage
public typealias DeliveryMode = SolaceDeliveryMode
public typealias MessagingError = SolaceError
public typealias SessionCapabilities = SolaceSessionCapabilities
public typealias SessionEvent = SolaceSessionEvent
public typealias SessionEventKind = SolaceSessionEventKind
public typealias QueueFlowConfiguration = SolaceQueueFlowConfiguration
public typealias QueueFlowEvent = SolaceFlowEvent
public typealias QueueFlowEventKind = SolaceFlowEventKind
public typealias GuaranteedMessage = SolaceGuaranteedMessage

public final class SolaceClient: Sendable {
    public init() {}

    public func connect(_ configuration: SolaceConnectionConfiguration) async throws -> SolaceKitSession {
        try await Task.detached {
            let coreSession = try SolaceSession.connect(configuration)
            return SolaceKitSession(coreSession: coreSession)
        }.value
    }
}

public final class SolaceKitSession: @unchecked Sendable {
    private let coreSession: SolaceSession

    public var messages: AsyncThrowingStream<SolaceMessage, Error> {
        coreSession.messages
    }

    public var events: AsyncStream<SolaceSessionEvent> {
        coreSession.events
    }

    public func readCapabilities() async throws -> SessionCapabilities {
        try await Task.detached { [coreSession] in
            try coreSession.readCapabilities()
        }.value
    }

    init(coreSession: SolaceSession) {
        self.coreSession = coreSession
    }

    public func subscribe(_ topic: String) async throws {
        try await Task.detached { [coreSession] in
            try coreSession.subscribe(topic)
        }.value
    }

    public func unsubscribe(_ topic: String) async throws {
        try await Task.detached { [coreSession] in
            try coreSession.unsubscribe(topic)
        }.value
    }

    public func createQueueFlow(_ configuration: QueueFlowConfiguration) async throws -> SolaceKitQueueFlow {
        try await Task.detached { [coreSession] in
            let flow = try coreSession.createQueueFlow(configuration)
            return SolaceKitQueueFlow(coreFlow: flow)
        }.value
    }

    public func publish(
        topic: String,
        payload: Data,
        deliveryMode: DeliveryMode = .direct
    ) async throws {
        try await Task.detached { [coreSession] in
            try coreSession.publish(topic: topic, payload: payload, deliveryMode: deliveryMode)
        }.value
    }

    public func close() {
        coreSession.close()
    }
}

public final class SolaceKitQueueFlow: @unchecked Sendable {
    private let coreFlow: SolaceQueueFlow

    public var messages: AsyncThrowingStream<SolaceGuaranteedMessage, Error> {
        coreFlow.messages
    }

    public var events: AsyncStream<SolaceFlowEvent> {
        coreFlow.events
    }

    init(coreFlow: SolaceQueueFlow) {
        self.coreFlow = coreFlow
    }

    public func start() async throws {
        try await Task.detached { [coreFlow] in
            try coreFlow.start()
        }.value
    }

    public func stop() async throws {
        try await Task.detached { [coreFlow] in
            try coreFlow.stop()
        }.value
    }

    public func close() {
        coreFlow.close()
    }
}
