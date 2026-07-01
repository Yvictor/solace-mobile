import CSolace
import Foundation

func requiredEnv(_ name: String) -> String {
    guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
        fputs("missing \(name)\n", stderr)
        exit(2)
    }
    return value
}

let host = requiredEnv("SOLACE_HOST")
let vpn = requiredEnv("SOLACE_VPN")
let username = requiredEnv("SOLACE_USERNAME")
let password = requiredEnv("SOLACE_PASSWORD")
let topic = ProcessInfo.processInfo.environment["SOLACE_TOPIC"] ?? "TIC/v1/FOP/*/TFE/TXFG6"
let compressionLevel = ProcessInfo.processInfo.environment["SOLACE_COMPRESSION_LEVEL"] ?? "0"
let waitSeconds = Int32(ProcessInfo.processInfo.environment["SOLACE_WAIT_SECONDS"] ?? "10") ?? 10

let result = csolace_connect_smoke(
    host,
    vpn,
    username,
    password,
    topic,
    compressionLevel,
    waitSeconds
)

exit(result)
