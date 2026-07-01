import Foundation
import SolaceKit

func loadDotEnv() -> [String: String] {
    let url = URL(fileURLWithPath: ".env")
    guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
        return [:]
    }

    var values: [String: String] = [:]
    for rawLine in contents.split(whereSeparator: \.isNewline) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !line.hasPrefix("#"), let separator = line.firstIndex(of: "=") else {
            continue
        }

        let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
        var value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count >= 2, value.first == "\"", value.last == "\"" {
            value.removeFirst()
            value.removeLast()
        }
        values[key] = value
    }
    return values
}

let dotEnv = loadDotEnv()

func env(_ name: String) -> String? {
    if let value = ProcessInfo.processInfo.environment[name], !value.isEmpty {
        return value
    }
    if let value = dotEnv[name], !value.isEmpty {
        return value
    }
    return nil
}

func requiredEnv(_ name: String) -> String {
    guard let value = env(name) else {
        fputs("missing \(name)\n", stderr)
        exit(2)
    }
    return value
}

func intEnv(_ name: String, default defaultValue: Int) -> Int {
    Int(env(name) ?? "") ?? defaultValue
}

func uint64Env(_ name: String, default defaultValue: UInt64) -> UInt64 {
    UInt64(env(name) ?? "") ?? defaultValue
}

struct ReconnectCounters: Sendable {
    var reconnecting = 0
    var reconnected = 0
    var down = 0
    var other = 0
}

@main
struct SolaceMacReconnectSmoke {
    static func main() async {
        let host = requiredEnv("SOLACE_HOST")
        let vpn = requiredEnv("SOLACE_VPN")
        let username = requiredEnv("SOLACE_USERNAME")
        let password = requiredEnv("SOLACE_PASSWORD")
        let topic = env("SOLACE_TOPIC") ?? "TIC/v1/FOP/*/TFE/TXFG6"
        let compressionLevel = intEnv("SOLACE_COMPRESSION_LEVEL", default: 3)
        let waitSeconds = uint64Env("SOLACE_RECONNECT_WAIT_SECONDS", default: 60)
        let reconnectRetries = intEnv("SOLACE_RECONNECT_RETRIES", default: -1)
        let reconnectRetryWaitMilliseconds = intEnv("SOLACE_RECONNECT_RETRY_WAIT_MS", default: 1_000)
        let expectedReconnects = intEnv("SOLACE_EXPECT_RECONNECTS", default: 0)

        print("host: \(host)")
        print("vpn: \(vpn)")
        print("username: \(username)")
        print("topic: \(topic)")
        print("compression level: \(compressionLevel)")
        print("reconnect retries: \(reconnectRetries)")
        print("reconnect retry wait ms: \(reconnectRetryWaitMilliseconds)")
        print("expected reconnects: \(expectedReconnects)")

        do {
            let client = SolaceClient()
            let session = try await client.connect(
                SolaceConfiguration(
                    host: host,
                    vpn: vpn,
                    username: username,
                    password: password,
                    compressionLevel: compressionLevel,
                    reconnectRetries: reconnectRetries,
                    reconnectRetryWaitMilliseconds: reconnectRetryWaitMilliseconds
                )
            )
            print("connect: Ok")

            let eventReceiver = Task<ReconnectCounters, Never> {
                var counters = ReconnectCounters()
                for await event in session.events {
                    print("session event: \(event.name)")
                    if !event.detail.isEmpty {
                        print("  detail: \(event.detail)")
                    }
                    switch event.kind {
                    case .reconnecting:
                        counters.reconnecting += 1
                    case .reconnected:
                        counters.reconnected += 1
                    case .down:
                        counters.down += 1
                    default:
                        counters.other += 1
                    }
                }
                return counters
            }

            try await session.subscribe(topic)
            print("subscribe: Ok")

            let receiver = Task<Int, Error> {
                var count = 0
                for try await message in session.messages {
                    count += 1
                    print("message received #\(count)")
                    if let topic = message.topic {
                        print("  topic: \(topic)")
                    }
                    print("  payload bytes: \(message.payload.count)")
                }
                return count
            }

            print("waiting \(waitSeconds) seconds; induce a broker/network interruption now if validating reconnect...")
            try await Task.sleep(nanoseconds: waitSeconds * 1_000_000_000)

            try await session.unsubscribe(topic)
            print("unsubscribe: Ok")
            session.close()

            let messages = try await receiver.value
            let counters = await eventReceiver.value
            print("messages received: \(messages)")
            print("reconnecting events: \(counters.reconnecting)")
            print("reconnected events: \(counters.reconnected)")
            print("down events: \(counters.down)")
            print("other session events: \(counters.other)")

            if counters.reconnected < expectedReconnects {
                throw MessagingError(
                    operation: "reconnect smoke",
                    returnCode: "Too few reconnects",
                    subCode: "",
                    detail: "expected at least \(expectedReconnects), observed \(counters.reconnected)"
                )
            }
        } catch {
            fputs("FAILED: \(error)\n", stderr)
            exit(1)
        }
    }
}
