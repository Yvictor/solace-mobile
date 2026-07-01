import Foundation
import SolaceCore

public typealias SolaceConfiguration = SolaceConnectionConfiguration
public typealias Message = SolaceMessage
public typealias DeliveryMode = SolaceDeliveryMode

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
