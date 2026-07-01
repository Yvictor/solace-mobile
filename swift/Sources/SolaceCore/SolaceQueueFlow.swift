import CSolace
import Foundation

public enum SolaceFlowEndpoint: Sendable, Equatable {
    case queue(name: String, durable: Bool = true)
    case topicEndpoint(name: String? = nil, topic: String, durable: Bool = false)
}

public struct SolaceQueueFlowConfiguration: Sendable, Equatable {
    public var endpoint: SolaceFlowEndpoint
    public var bindTimeoutMilliseconds: Int
    public var windowSize: Int
    public var maximumUnacknowledgedMessages: Int
    public var reconnectRetries: Int
    public var reconnectRetryWaitMilliseconds: Int
    public var startImmediately: Bool

    public init(
        queueName: String,
        bindTimeoutMilliseconds: Int = 10_000,
        windowSize: Int = 255,
        maximumUnacknowledgedMessages: Int = -1,
        reconnectRetries: Int = -1,
        reconnectRetryWaitMilliseconds: Int = 3_000,
        startImmediately: Bool = true
    ) {
        self.endpoint = .queue(name: queueName, durable: true)
        self.bindTimeoutMilliseconds = bindTimeoutMilliseconds
        self.windowSize = windowSize
        self.maximumUnacknowledgedMessages = maximumUnacknowledgedMessages
        self.reconnectRetries = reconnectRetries
        self.reconnectRetryWaitMilliseconds = reconnectRetryWaitMilliseconds
        self.startImmediately = startImmediately
    }

    public init(
        topicEndpointTopic: String,
        topicEndpointName: String? = nil,
        durable: Bool = false,
        bindTimeoutMilliseconds: Int = 10_000,
        windowSize: Int = 255,
        maximumUnacknowledgedMessages: Int = -1,
        reconnectRetries: Int = -1,
        reconnectRetryWaitMilliseconds: Int = 3_000,
        startImmediately: Bool = true
    ) {
        self.endpoint = .topicEndpoint(
            name: topicEndpointName,
            topic: topicEndpointTopic,
            durable: durable
        )
        self.bindTimeoutMilliseconds = bindTimeoutMilliseconds
        self.windowSize = windowSize
        self.maximumUnacknowledgedMessages = maximumUnacknowledgedMessages
        self.reconnectRetries = reconnectRetries
        self.reconnectRetryWaitMilliseconds = reconnectRetryWaitMilliseconds
        self.startImmediately = startImmediately
    }

    public var queueName: String {
        switch endpoint {
        case .queue(let name, _):
            return name
        case .topicEndpoint(let name, _, _):
            return name ?? ""
        }
    }
}

public final class SolaceQueueFlow: @unchecked Sendable {
    private var flow: solClient_opaqueFlow_pt?
    private let lock = NSLock()
    private var messageContinuation: AsyncThrowingStream<SolaceGuaranteedMessage, Error>.Continuation?
    private var eventContinuation: AsyncStream<SolaceFlowEvent>.Continuation?

    public let messages: AsyncThrowingStream<SolaceGuaranteedMessage, Error>
    public let events: AsyncStream<SolaceFlowEvent>

    init(session: solClient_opaqueSession_pt, configuration: SolaceQueueFlowConfiguration) throws {
        var localMessageContinuation: AsyncThrowingStream<SolaceGuaranteedMessage, Error>.Continuation?
        self.messages = AsyncThrowingStream { continuation in
            localMessageContinuation = continuation
        }
        self.messageContinuation = localMessageContinuation

        var localEventContinuation: AsyncStream<SolaceFlowEvent>.Continuation?
        self.events = AsyncStream { continuation in
            localEventContinuation = continuation
        }
        self.eventContinuation = localEventContinuation

        var flowInfo = solClient_flow_createFuncInfo_t()
        flowInfo.rxMsgInfo.callback_p = Self.receiveMessageCallback
        flowInfo.rxMsgInfo.user_p = Unmanaged.passUnretained(self).toOpaque()
        flowInfo.eventInfo.callback_p = Self.eventCallback
        flowInfo.eventInfo.user_p = Unmanaged.passUnretained(self).toOpaque()

        try withFlowProperties(configuration) { props in
            try check(
                "solClient_session_createFlow",
                solClient_session_createFlow(
                    props,
                    session,
                    &flow,
                    &flowInfo,
                    MemoryLayout<solClient_flow_createFuncInfo_t>.size
                )
            )
        }
    }

    deinit {
        close()
    }

    public func start() throws {
        guard let currentFlow = currentFlow else {
            throw SolaceError(operation: "solClient_flow_start", returnCode: "Flow closed", subCode: "", detail: "")
        }
        try check("solClient_flow_start", solClient_flow_start(currentFlow))
    }

    public func stop() throws {
        guard let currentFlow = currentFlow else {
            return
        }
        try check("solClient_flow_stop", solClient_flow_stop(currentFlow))
    }

    public func close() {
        lock.lock()
        let currentFlow = flow
        flow = nil
        let currentMessageContinuation = messageContinuation
        messageContinuation = nil
        let currentEventContinuation = eventContinuation
        eventContinuation = nil
        lock.unlock()

        if let currentFlow {
            var mutableFlow: solClient_opaqueFlow_pt? = currentFlow
            _ = solClient_flow_destroy(&mutableFlow)
        }

        currentMessageContinuation?.finish()
        currentEventContinuation?.finish()
    }

    func acknowledge(messageID: solClient_msgId_t) throws {
        guard let currentFlow = currentFlow else {
            throw SolaceError(operation: "solClient_flow_sendAck", returnCode: "Flow closed", subCode: "", detail: "")
        }
        try check("solClient_flow_sendAck", solClient_flow_sendAck(currentFlow, messageID))
    }

    private var currentFlow: solClient_opaqueFlow_pt? {
        lock.lock()
        defer { lock.unlock() }
        return flow
    }

    private func handleMessage(_ message: solClient_opaqueMsg_pt?) -> solClient_rxMsgCallback_returnCode_t {
        guard let message else {
            return SOLCLIENT_CALLBACK_OK
        }
        let copied = SolaceGuaranteedMessage.copy(from: message, flow: self)
        lock.lock()
        let currentContinuation = messageContinuation
        lock.unlock()
        currentContinuation?.yield(copied)
        return SOLCLIENT_CALLBACK_OK
    }

    private func handleEvent(_ eventInfo: solClient_flow_eventCallbackInfo_pt?) {
        guard let eventInfo else {
            return
        }
        let event = SolaceFlowEvent.copy(from: eventInfo)
        lock.lock()
        let currentEventContinuation = eventContinuation
        lock.unlock()
        currentEventContinuation?.yield(event)

        switch eventInfo.pointee.flowEvent {
        case SOLCLIENT_FLOW_EVENT_DOWN_ERROR,
             SOLCLIENT_FLOW_EVENT_BIND_FAILED_ERROR:
            let error = SolaceError(
                operation: "flow event",
                returnCode: event.name,
                subCode: "",
                detail: event.detail
            )
            lock.lock()
            let currentContinuation = messageContinuation
            lock.unlock()
            currentContinuation?.finish(throwing: error)
        default:
            break
        }
    }

    private static let receiveMessageCallback: solClient_flow_rxMsgCallbackFunc_t = { _, message, user in
        guard let user else {
            return SOLCLIENT_CALLBACK_OK
        }
        return Unmanaged<SolaceQueueFlow>
            .fromOpaque(user)
            .takeUnretainedValue()
            .handleMessage(message)
    }

    private static let eventCallback: solClient_flow_eventCallbackFunc_t = { _, eventInfo, user in
        guard let user else {
            return
        }
        Unmanaged<SolaceQueueFlow>
            .fromOpaque(user)
            .takeUnretainedValue()
            .handleEvent(eventInfo)
    }
}

private func withFlowProperties<T>(
    _ configuration: SolaceQueueFlowConfiguration,
    _ body: (solClient_propertyArray_pt) throws -> T
) rethrows -> T {
    var values = [
        SOLCLIENT_FLOW_PROP_BIND_BLOCKING, SOLCLIENT_PROP_ENABLE_VAL,
        SOLCLIENT_FLOW_PROP_BIND_TIMEOUT_MS, "\(configuration.bindTimeoutMilliseconds)"
    ]

    switch configuration.endpoint {
    case .queue(let name, let durable):
        values.append(contentsOf: [
            SOLCLIENT_FLOW_PROP_BIND_ENTITY_ID, SOLCLIENT_FLOW_PROP_BIND_ENTITY_QUEUE,
            SOLCLIENT_FLOW_PROP_BIND_ENTITY_DURABLE, durable ? SOLCLIENT_PROP_ENABLE_VAL : SOLCLIENT_PROP_DISABLE_VAL,
            SOLCLIENT_FLOW_PROP_BIND_NAME, name
        ])
    case .topicEndpoint(let name, let topic, let durable):
        values.append(contentsOf: [
            SOLCLIENT_FLOW_PROP_BIND_ENTITY_ID, SOLCLIENT_FLOW_PROP_BIND_ENTITY_TE,
            SOLCLIENT_FLOW_PROP_BIND_ENTITY_DURABLE, durable ? SOLCLIENT_PROP_ENABLE_VAL : SOLCLIENT_PROP_DISABLE_VAL,
            SOLCLIENT_FLOW_PROP_TOPIC, topic
        ])
        if let name {
            values.append(contentsOf: [
                SOLCLIENT_FLOW_PROP_BIND_NAME, name
            ])
        }
    }

    values.append(contentsOf: [
        SOLCLIENT_FLOW_PROP_ACKMODE, SOLCLIENT_FLOW_PROP_ACKMODE_CLIENT,
        SOLCLIENT_FLOW_PROP_WINDOWSIZE, "\(configuration.windowSize)",
        SOLCLIENT_FLOW_PROP_MAX_UNACKED_MESSAGES, "\(configuration.maximumUnacknowledgedMessages)",
        SOLCLIENT_FLOW_PROP_MAX_RECONNECT_TRIES, "\(configuration.reconnectRetries)",
        SOLCLIENT_FLOW_PROP_RECONNECT_RETRY_INTERVAL_MS, "\(configuration.reconnectRetryWaitMilliseconds)",
        SOLCLIENT_FLOW_PROP_START_STATE, configuration.startImmediately ? SOLCLIENT_PROP_ENABLE_VAL : SOLCLIENT_PROP_DISABLE_VAL
    ])

    let cStrings = values.map { strdup($0) }
    defer {
        for pointer in cStrings {
            free(pointer)
        }
    }

    var props = cStrings.map { UnsafePointer<CChar>($0) }
    props.append(nil)
    return try props.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress!)
    }
}
