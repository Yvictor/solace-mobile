import CSolace
import Foundation

public struct SolaceMessage: Sendable {
    public var topic: String?
    public var payload: Data

    public init(topic: String?, payload: Data) {
        self.topic = topic
        self.payload = payload
    }
}

extension SolaceMessage {
    static func copy(from message: solClient_opaqueMsg_pt) -> SolaceMessage {
        var topic: String?
        var destination = solClient_destination_t()
        let destinationResult = solClient_msg_getDestination(
            message,
            &destination,
            MemoryLayout<solClient_destination_t>.size
        )
        if destinationResult == SOLCLIENT_OK, let destinationPointer = destination.dest {
            topic = String(cString: destinationPointer)
        }

        var payloadPointer: UnsafeMutableRawPointer?
        var payloadSize: solClient_uint32_t = 0
        let payloadResult = solClient_msg_getBinaryAttachmentPtr(
            message,
            &payloadPointer,
            &payloadSize
        )

        guard payloadResult == SOLCLIENT_OK, let payloadPointer, payloadSize > 0 else {
            return SolaceMessage(topic: topic, payload: Data())
        }

        return SolaceMessage(
            topic: topic,
            payload: Data(bytes: payloadPointer, count: Int(payloadSize))
        )
    }
}
