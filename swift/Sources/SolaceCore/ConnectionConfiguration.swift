import Foundation

public struct SolaceConnectionConfiguration: Sendable {
    public var host: String
    public var vpn: String
    public var username: String
    public var password: String
    public var compressionLevel: Int
    public var connectTimeoutMilliseconds: Int
    public var reconnectRetries: Int
    public var reconnectRetryWaitMilliseconds: Int

    public init(
        host: String,
        vpn: String,
        username: String,
        password: String,
        compressionLevel: Int = 0,
        connectTimeoutMilliseconds: Int = 10_000,
        reconnectRetries: Int = 0,
        reconnectRetryWaitMilliseconds: Int = 3_000
    ) {
        self.host = host
        self.vpn = vpn
        self.username = username
        self.password = password
        self.compressionLevel = compressionLevel
        self.connectTimeoutMilliseconds = connectTimeoutMilliseconds
        self.reconnectRetries = reconnectRetries
        self.reconnectRetryWaitMilliseconds = reconnectRetryWaitMilliseconds
    }
}
