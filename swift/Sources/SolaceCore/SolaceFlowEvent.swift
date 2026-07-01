import CSolace
import Foundation

public enum SolaceFlowEventKind: Sendable, Equatable {
    case up
    case down
    case bindFailed
    case sessionDown
    case active
    case inactive
    case reconnecting
    case reconnected
    case other(String)
}

public struct SolaceFlowEvent: Sendable, Equatable {
    public var kind: SolaceFlowEventKind
    public var name: String
    public var detail: String

    public init(kind: SolaceFlowEventKind, name: String, detail: String = "") {
        self.kind = kind
        self.name = name
        self.detail = detail
    }
}

extension SolaceFlowEvent {
    static func copy(from eventInfo: solClient_flow_eventCallbackInfo_pt) -> SolaceFlowEvent {
        let flowEvent = eventInfo.pointee.flowEvent
        let name = solClient_flow_eventToString(flowEvent).map(String.init(cString:)) ?? "\(flowEvent.rawValue)"
        let detail = eventInfo.pointee.info_p.map(String.init(cString:)) ?? ""
        return SolaceFlowEvent(kind: SolaceFlowEventKind(cValue: flowEvent, name: name), name: name, detail: detail)
    }
}

private extension SolaceFlowEventKind {
    init(cValue: solClient_flow_event_t, name: String) {
        switch cValue {
        case SOLCLIENT_FLOW_EVENT_UP_NOTICE:
            self = .up
        case SOLCLIENT_FLOW_EVENT_DOWN_ERROR:
            self = .down
        case SOLCLIENT_FLOW_EVENT_BIND_FAILED_ERROR:
            self = .bindFailed
        case SOLCLIENT_FLOW_EVENT_SESSION_DOWN:
            self = .sessionDown
        case SOLCLIENT_FLOW_EVENT_ACTIVE:
            self = .active
        case SOLCLIENT_FLOW_EVENT_INACTIVE:
            self = .inactive
        case SOLCLIENT_FLOW_EVENT_RECONNECTING:
            self = .reconnecting
        case SOLCLIENT_FLOW_EVENT_RECONNECTED:
            self = .reconnected
        default:
            self = .other(name)
        }
    }
}
