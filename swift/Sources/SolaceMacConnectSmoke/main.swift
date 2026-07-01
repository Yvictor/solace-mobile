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

@main
struct SolaceMacConnectSmoke {
    static func main() async {
        let host = requiredEnv("SOLACE_HOST")
        let vpn = requiredEnv("SOLACE_VPN")
        let username = requiredEnv("SOLACE_USERNAME")
        let password = requiredEnv("SOLACE_PASSWORD")
        let topic = env("SOLACE_TOPIC") ?? "TIC/v1/FOP/*/TFE/TXFG6"
        let publishTopic = env("SOLACE_PUBLISH_TOPIC")
        let publishText = env("SOLACE_PUBLISH_TEXT") ?? "solace-mobile swift smoke"
        let compressionLevel = Int(env("SOLACE_COMPRESSION_LEVEL") ?? "0") ?? 0
        let waitSeconds = UInt64(env("SOLACE_WAIT_SECONDS") ?? "10") ?? 10

        print("host: \(host)")
        print("vpn: \(vpn)")
        print("username: \(username)")
        print("topic: \(topic)")
        print("compression level: \(compressionLevel)")

        do {
            let client = SolaceClient()
            let session = try await client.connect(
                SolaceConfiguration(
                    host: host,
                    vpn: vpn,
                    username: username,
                    password: password,
                    compressionLevel: compressionLevel
                )
            )
            print("connect: Ok")

            let eventReceiver = Task<Int, Never> {
                var count = 0
                for await event in session.events {
                    count += 1
                    print("session event #\(count): \(event.name)")
                    if !event.detail.isEmpty {
                        print("  detail: \(event.detail)")
                    }
                }
                return count
            }

            if let publishTopic {
                try await session.publish(
                    topic: publishTopic,
                    payload: Data(publishText.utf8),
                    deliveryMode: .direct
                )
                print("publish: Ok")
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

            print("waiting \(waitSeconds) seconds for messages...")
            try await Task.sleep(nanoseconds: waitSeconds * 1_000_000_000)

            try await session.unsubscribe(topic)
            print("unsubscribe: Ok")
            session.close()

            let count = try await receiver.value
            let eventCount = await eventReceiver.value
            print("messages received: \(count)")
            print("session events received: \(eventCount)")
        } catch {
            fputs("FAILED: \(error)\n", stderr)
            exit(1)
        }
    }
}
