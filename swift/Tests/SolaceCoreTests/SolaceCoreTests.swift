import SolaceCore
import Testing

@Test func connectionConfigurationDefaults() {
    let configuration = SolaceConnectionConfiguration(
        host: "example.com:55555",
        vpn: "default",
        username: "user",
        password: "secret"
    )

    #expect(configuration.host == "example.com:55555")
    #expect(configuration.vpn == "default")
    #expect(configuration.username == "user")
    #expect(configuration.compressionLevel == 0)
    #expect(configuration.connectTimeoutMilliseconds == 10_000)
    #expect(configuration.reconnectRetries == 0)
    #expect(configuration.reconnectRetryWaitMilliseconds == 3_000)
}

@Test func solaceErrorDescriptionIncludesContext() {
    let error = SolaceError(
        operation: "connect",
        returnCode: "Fail",
        subCode: "Login failure",
        detail: "bad credentials"
    )

    #expect(error.description.contains("connect failed"))
    #expect(error.description.contains("returnCode=Fail"))
    #expect(error.description.contains("subCode=Login failure"))
    #expect(error.description.contains("detail=bad credentials"))
}

@Test func deliveryModeMapsToPublicCases() {
    #expect(SolaceDeliveryMode.direct != SolaceDeliveryMode.persistent)
    #expect(SolaceDeliveryMode.nonPersistent != SolaceDeliveryMode.direct)
}

@Test func sessionEventIsEquatableAndCarriesDetail() {
    let event = SolaceSessionEvent(
        kind: .reconnected,
        name: "Session reconnected",
        detail: "host recovered"
    )

    #expect(event.kind == .reconnected)
    #expect(event.name == "Session reconnected")
    #expect(event.detail == "host recovered")
}

@Test func queueFlowConfigurationDefaultsToClientAck() {
    let configuration = SolaceQueueFlowConfiguration(queueName: "api/test")

    #expect(configuration.queueName == "api/test")
    #expect(configuration.bindTimeoutMilliseconds == 10_000)
    #expect(configuration.windowSize == 255)
    #expect(configuration.maximumUnacknowledgedMessages == -1)
    #expect(configuration.reconnectRetries == -1)
    #expect(configuration.reconnectRetryWaitMilliseconds == 3_000)
    #expect(configuration.startImmediately)
}

@Test func topicEndpointFlowConfigurationKeepsTopic() {
    let configuration = SolaceQueueFlowConfiguration(
        topicEndpointTopic: "api/test",
        topicEndpointName: nil,
        durable: false
    )

    #expect(configuration.queueName == "")
    #expect(configuration.endpoint == .topicEndpoint(name: nil, topic: "api/test", durable: false))
}

@Test func sessionCapabilitiesIsEquatable() {
    let capabilities = SolaceSessionCapabilities(
        publishGuaranteed: true,
        subscribeGuaranteedFlow: false,
        temporaryEndpoint: true,
        compression: true,
        endpointManagement: false
    )

    #expect(capabilities.publishGuaranteed)
    #expect(!capabilities.subscribeGuaranteedFlow)
    #expect(capabilities.temporaryEndpoint)
    #expect(capabilities.compression)
    #expect(!capabilities.endpointManagement)
}

@Test func flowEventIsEquatableAndCarriesDetail() {
    let event = SolaceFlowEvent(
        kind: .active,
        name: "Flow active",
        detail: "queue is active"
    )

    #expect(event.kind == .active)
    #expect(event.name == "Flow active")
    #expect(event.detail == "queue is active")
}
