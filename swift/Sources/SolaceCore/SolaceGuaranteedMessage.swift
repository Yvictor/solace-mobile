import CSolace
import Foundation

public struct SolaceGuaranteedMessage: Sendable {
    public var topic: String?
    public var payload: Data
    public var messageID: UInt64

    private let acknowledgeHandler: @Sendable () throws -> Void

    public init(
        topic: String?,
        payload: Data,
        messageID: UInt64,
        acknowledgeHandler: @escaping @Sendable () throws -> Void
    ) {
        self.topic = topic
        self.payload = payload
        self.messageID = messageID
        self.acknowledgeHandler = acknowledgeHandler
    }

    public func acknowledge() throws {
        try acknowledgeHandler()
    }
}

extension SolaceGuaranteedMessage {
    static func copy(from message: solClient_opaqueMsg_pt, flow: SolaceQueueFlow) -> SolaceGuaranteedMessage {
        let copied = SolaceMessage.copy(from: message)
        var messageID: solClient_msgId_t = 0
        _ = solClient_msg_getMsgId(message, &messageID)
        let acknowledgedMessageID = messageID

        return SolaceGuaranteedMessage(
            topic: copied.topic,
            payload: copied.payload,
            messageID: UInt64(acknowledgedMessageID)
        ) { [weak flow] in
            guard let flow else {
                throw SolaceError(operation: "solClient_flow_sendAck", returnCode: "Flow closed", subCode: "", detail: "")
            }
            try flow.acknowledge(messageID: acknowledgedMessageID)
        }
    }
}
