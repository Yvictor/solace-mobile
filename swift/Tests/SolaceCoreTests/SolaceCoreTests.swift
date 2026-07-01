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
