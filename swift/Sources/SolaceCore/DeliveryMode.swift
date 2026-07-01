import CSolace
import Foundation

public enum SolaceDeliveryMode: Sendable {
    case direct
    case persistent
    case nonPersistent

    var cValue: solClient_uint32_t {
        switch self {
        case .direct:
            return solClient_uint32_t(SOLCLIENT_DELIVERY_MODE_DIRECT)
        case .persistent:
            return solClient_uint32_t(SOLCLIENT_DELIVERY_MODE_PERSISTENT)
        case .nonPersistent:
            return solClient_uint32_t(SOLCLIENT_DELIVERY_MODE_NONPERSISTENT)
        }
    }
}
