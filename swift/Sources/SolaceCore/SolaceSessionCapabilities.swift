import CSolace
import Foundation

public struct SolaceSessionCapabilities: Sendable, Equatable {
    public var publishGuaranteed: Bool
    public var subscribeGuaranteedFlow: Bool
    public var temporaryEndpoint: Bool
    public var compression: Bool
    public var endpointManagement: Bool

    public init(
        publishGuaranteed: Bool,
        subscribeGuaranteedFlow: Bool,
        temporaryEndpoint: Bool,
        compression: Bool,
        endpointManagement: Bool
    ) {
        self.publishGuaranteed = publishGuaranteed
        self.subscribeGuaranteedFlow = subscribeGuaranteedFlow
        self.temporaryEndpoint = temporaryEndpoint
        self.compression = compression
        self.endpointManagement = endpointManagement
    }
}

extension SolaceSessionCapabilities {
    static func read(from session: solClient_opaqueSession_pt) -> SolaceSessionCapabilities {
        SolaceSessionCapabilities(
            publishGuaranteed: isCapable(session, SOLCLIENT_SESSION_CAPABILITY_PUB_GUARANTEED),
            subscribeGuaranteedFlow: isCapable(session, SOLCLIENT_SESSION_CAPABILITY_SUB_FLOW_GUARANTEED),
            temporaryEndpoint: isCapable(session, SOLCLIENT_SESSION_CAPABILITY_TEMP_ENDPOINT),
            compression: isCapable(session, SOLCLIENT_SESSION_CAPABILITY_COMPRESSION),
            endpointManagement: isCapable(session, SOLCLIENT_SESSION_CAPABILITY_ENDPOINT_MANAGEMENT)
        )
    }

    private static func isCapable(
        _ session: solClient_opaqueSession_pt,
        _ capability: UnsafePointer<CChar>?
    ) -> Bool {
        guard let capability else {
            return false
        }
        return solClient_session_isCapable(session, capability) != 0
    }
}
