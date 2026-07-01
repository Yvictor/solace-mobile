import CSolace
import Foundation

public final class SolaceSession: @unchecked Sendable {
    private var context: solClient_opaqueContext_pt?
    private var session: solClient_opaqueSession_pt?
    private let lock = NSLock()
    private var messageContinuation: AsyncThrowingStream<SolaceMessage, Error>.Continuation?
    private var eventContinuation: AsyncStream<SolaceSessionEvent>.Continuation?

    public let messages: AsyncThrowingStream<SolaceMessage, Error>
    public let events: AsyncStream<SolaceSessionEvent>

    private init() {
        var localMessageContinuation: AsyncThrowingStream<SolaceMessage, Error>.Continuation?
        self.messages = AsyncThrowingStream { continuation in
            localMessageContinuation = continuation
        }
        self.messageContinuation = localMessageContinuation

        var localEventContinuation: AsyncStream<SolaceSessionEvent>.Continuation?
        self.events = AsyncStream { continuation in
            localEventContinuation = continuation
        }
        self.eventContinuation = localEventContinuation
    }

    deinit {
        close()
    }

    public static func connect(_ configuration: SolaceConnectionConfiguration) throws -> SolaceSession {
        try SolaceEnvironment.shared.retain()
        do {
            let instance = SolaceSession()
            try instance.open(configuration)
            return instance
        } catch {
            SolaceEnvironment.shared.release()
            throw error
        }
    }

    public func subscribe(_ topic: String) throws {
        guard let session else {
            throw SolaceError(operation: "subscribe", returnCode: "Not connected", subCode: "", detail: "")
        }
        try check(
            "solClient_session_topicSubscribeExt",
            solClient_session_topicSubscribeExt(
                session,
                solClient_subscribeFlags_t(SOLCLIENT_SUBSCRIBE_FLAGS_WAITFORCONFIRM),
                topic
            )
        )
    }

    public func unsubscribe(_ topic: String) throws {
        guard let session else {
            return
        }
        try check(
            "solClient_session_topicUnsubscribeExt",
            solClient_session_topicUnsubscribeExt(
                session,
                solClient_subscribeFlags_t(SOLCLIENT_SUBSCRIBE_FLAGS_WAITFORCONFIRM),
                topic
            )
        )
    }

    public func createQueueFlow(_ configuration: SolaceQueueFlowConfiguration) throws -> SolaceQueueFlow {
        guard let session else {
            throw SolaceError(operation: "solClient_session_createFlow", returnCode: "Not connected", subCode: "", detail: "")
        }
        return try SolaceQueueFlow(session: session, configuration: configuration)
    }

    public func publish(
        topic: String,
        payload: Data,
        deliveryMode: SolaceDeliveryMode = .direct
    ) throws {
        guard let session else {
            throw SolaceError(operation: "publish", returnCode: "Not connected", subCode: "", detail: "")
        }

        var message: solClient_opaqueMsg_pt?
        try check("solClient_msg_alloc", solClient_msg_alloc(&message))
        defer {
            _ = solClient_msg_free(&message)
        }

        guard let message else {
            throw SolaceError(operation: "solClient_msg_alloc", returnCode: "No message", subCode: "", detail: "")
        }

        try topic.withCString { topicPointer in
            var destination = solClient_destination_t(
                destType: SOLCLIENT_TOPIC_DESTINATION,
                dest: topicPointer
            )
            try check(
                "solClient_msg_setDestination",
                solClient_msg_setDestination(
                    message,
                    &destination,
                    MemoryLayout<solClient_destination_t>.size
                )
            )
        }

        try payload.withUnsafeBytes { bytes in
            let baseAddress = bytes.baseAddress
            try check(
                "solClient_msg_setBinaryAttachment",
                solClient_msg_setBinaryAttachment(
                    message,
                    baseAddress,
                    solClient_uint32_t(payload.count)
                )
            )
        }

        try check(
            "solClient_msg_setDeliveryMode",
            solClient_msg_setDeliveryMode(message, deliveryMode.cValue)
        )

        try check("solClient_session_sendMsg", solClient_session_sendMsg(session, message))
    }

    public func close() {
        lock.lock()
        let currentSession = session
        let currentContext = context
        session = nil
        context = nil
        let currentMessageContinuation = messageContinuation
        messageContinuation = nil
        let currentEventContinuation = eventContinuation
        eventContinuation = nil
        lock.unlock()

        if let currentSession {
            _ = solClient_session_disconnect(currentSession)
            var mutableSession: solClient_opaqueSession_pt? = currentSession
            _ = solClient_session_destroy(&mutableSession)
        }
        if let currentContext {
            var mutableContext: solClient_opaqueContext_pt? = currentContext
            _ = solClient_context_destroy(&mutableContext)
        }

        currentMessageContinuation?.finish()
        currentEventContinuation?.finish()
        SolaceEnvironment.shared.release()
    }

    private func open(_ configuration: SolaceConnectionConfiguration) throws {
        try check(
            "solClient_context_create",
            csolace_context_create_with_thread(&context)
        )

        var sessionInfo = solClient_session_createFuncInfo_t()
        sessionInfo.rxMsgInfo.callback_p = Self.receiveMessageCallback
        sessionInfo.rxMsgInfo.user_p = Unmanaged.passUnretained(self).toOpaque()
        sessionInfo.eventInfo.callback_p = Self.eventCallback
        sessionInfo.eventInfo.user_p = Unmanaged.passUnretained(self).toOpaque()

        try withSessionProperties(configuration) { props in
            try check(
                "solClient_session_create",
                solClient_session_create(
                    props,
                    context,
                    &session,
                    &sessionInfo,
                    MemoryLayout<solClient_session_createFuncInfo_t>.size
                )
            )
        }

        guard let session else {
            throw SolaceError(operation: "solClient_session_create", returnCode: "No session", subCode: "", detail: "")
        }
        try check("solClient_session_connect", solClient_session_connect(session))
    }

    private func handleMessage(_ message: solClient_opaqueMsg_pt?) -> solClient_rxMsgCallback_returnCode_t {
        guard let message else {
            return SOLCLIENT_CALLBACK_OK
        }
        let copied = SolaceMessage.copy(from: message)
        lock.lock()
        let currentContinuation = messageContinuation
        lock.unlock()
        currentContinuation?.yield(copied)
        return SOLCLIENT_CALLBACK_OK
    }

    private func handleEvent(_ eventInfo: solClient_session_eventCallbackInfo_pt?) {
        guard let eventInfo else {
            return
        }
        let event = SolaceSessionEvent.copy(from: eventInfo)
        lock.lock()
        let currentEventContinuation = eventContinuation
        lock.unlock()
        currentEventContinuation?.yield(event)

        switch eventInfo.pointee.sessionEvent {
        case SOLCLIENT_SESSION_EVENT_DOWN_ERROR,
             SOLCLIENT_SESSION_EVENT_CONNECT_FAILED_ERROR:
            let error = SolaceError(
                operation: "session event",
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

    private static let receiveMessageCallback: solClient_session_rxMsgCallbackFunc_t = { _, message, user in
        guard let user else {
            return SOLCLIENT_CALLBACK_OK
        }
        return Unmanaged<SolaceSession>
            .fromOpaque(user)
            .takeUnretainedValue()
            .handleMessage(message)
    }

    private static let eventCallback: solClient_session_eventCallbackFunc_t = { _, eventInfo, user in
        guard let user else {
            return
        }
        Unmanaged<SolaceSession>
            .fromOpaque(user)
            .takeUnretainedValue()
            .handleEvent(eventInfo)
    }
}

private func withSessionProperties<T>(
    _ configuration: SolaceConnectionConfiguration,
    _ body: (solClient_propertyArray_pt) throws -> T
) rethrows -> T {
    let values = [
        SOLCLIENT_SESSION_PROP_HOST, configuration.host,
        SOLCLIENT_SESSION_PROP_VPN_NAME, configuration.vpn,
        SOLCLIENT_SESSION_PROP_USERNAME, configuration.username,
        SOLCLIENT_SESSION_PROP_PASSWORD, configuration.password,
        SOLCLIENT_SESSION_PROP_COMPRESSION_LEVEL, "\(configuration.compressionLevel)",
        SOLCLIENT_SESSION_PROP_CONNECT_BLOCKING, SOLCLIENT_PROP_ENABLE_VAL,
        SOLCLIENT_SESSION_PROP_SUBSCRIBE_BLOCKING, SOLCLIENT_PROP_ENABLE_VAL,
        SOLCLIENT_SESSION_PROP_REAPPLY_SUBSCRIPTIONS, SOLCLIENT_PROP_ENABLE_VAL,
        SOLCLIENT_SESSION_PROP_CONNECT_TIMEOUT_MS, "\(configuration.connectTimeoutMilliseconds)",
        SOLCLIENT_SESSION_PROP_RECONNECT_RETRIES, "\(configuration.reconnectRetries)",
        SOLCLIENT_SESSION_PROP_RECONNECT_RETRY_WAIT_MS, "\(configuration.reconnectRetryWaitMilliseconds)"
    ]

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
