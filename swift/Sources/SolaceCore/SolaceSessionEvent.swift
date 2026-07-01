import CSolace
import Foundation

public enum SolaceSessionEventKind: Sendable, Equatable {
    case up
    case down
    case reconnecting
    case reconnected
    case acknowledgement
    case rejectedMessage
    case subscriptionOk
    case subscriptionError
    case assuredDeliveryDown
    case republishUnackedMessages
    case other(String)
}

public struct SolaceSessionEvent: Sendable, Equatable {
    public var kind: SolaceSessionEventKind
    public var name: String
    public var detail: String

    public init(kind: SolaceSessionEventKind, name: String, detail: String) {
        self.kind = kind
        self.name = name
        self.detail = detail
    }
}

extension SolaceSessionEvent {
    static func copy(from eventInfo: solClient_session_eventCallbackInfo_pt) -> SolaceSessionEvent {
        let event = eventInfo.pointee.sessionEvent
        let name = solClient_session_eventToString(event).map(String.init(cString:)) ?? "Unknown"
        let detail = eventInfo.pointee.info_p.map(String.init(cString:)) ?? ""

        return SolaceSessionEvent(
            kind: kind(for: event, name: name),
            name: name,
            detail: detail
        )
    }

    private static func kind(
        for event: solClient_session_event_t,
        name: String
    ) -> SolaceSessionEventKind {
        switch event {
        case SOLCLIENT_SESSION_EVENT_UP_NOTICE:
            return .up
        case SOLCLIENT_SESSION_EVENT_DOWN_ERROR:
            return .down
        case SOLCLIENT_SESSION_EVENT_RECONNECTING_NOTICE:
            return .reconnecting
        case SOLCLIENT_SESSION_EVENT_RECONNECTED_NOTICE:
            return .reconnected
        case SOLCLIENT_SESSION_EVENT_ACKNOWLEDGEMENT:
            return .acknowledgement
        case SOLCLIENT_SESSION_EVENT_REJECTED_MSG_ERROR:
            return .rejectedMessage
        case SOLCLIENT_SESSION_EVENT_SUBSCRIPTION_OK:
            return .subscriptionOk
        case SOLCLIENT_SESSION_EVENT_SUBSCRIPTION_ERROR:
            return .subscriptionError
        case SOLCLIENT_SESSION_EVENT_ASSURED_DELIVERY_DOWN:
            return .assuredDeliveryDown
        case SOLCLIENT_SESSION_EVENT_REPUBLISH_UNACKED_MESSAGES:
            return .republishUnackedMessages
        default:
            return .other(name)
        }
    }
}
