import SolaceKit
import SwiftUI

@main
struct SolaceMobileIOSApp: App {
    var body: some Scene {
        WindowGroup {
            IosSubscribeView()
        }
    }
}

struct IosSubscribeView: View {
    @StateObject private var model = IosSubscribeModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Runtime") {
                    HStack {
                        Text("SolaceKit")
                        Spacer()
                        Text(model.status)
                            .foregroundStyle(model.isConnected ? .green : .secondary)
                    }
                    Button("Probe Swift Binding") {
                        _ = SolaceClient()
                        model.status = "Swift binding loaded"
                    }
                }

                Section("Quote Status") {
                    HStack {
                        Text("Received")
                        Spacer()
                        Text("\(model.receivedCount)")
                            .foregroundStyle(model.receivedCount > 0 ? .green : .secondary)
                    }
                    Text(model.latestMessage)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(model.receivedCount > 0 ? .primary : .secondary)
                }

                Section("Connection") {
                    TextField("Host", text: $model.host)
                    TextField("VPN", text: $model.vpn)
                    TextField("Username", text: $model.username)
                    SecureField("Password", text: $model.password)
                    Stepper("Compression \(model.compressionLevel)", value: $model.compressionLevel, in: 0...9)
                }

                Section("Subscribe") {
                    TextField("Topic", text: $model.topic)
                    Button(model.isConnected ? "Disconnect" : "Connect & Subscribe") {
                        model.isConnected ? model.disconnect() : model.connectAndSubscribe()
                    }
                    .disabled(!model.isConnected && !model.canConnect)
                }

                Section("Messages") {
                    if model.lines.isEmpty {
                        Text("No messages yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.lines) { line in
                            Text(line.text)
                                .font(.system(.footnote, design: .monospaced))
                        }
                    }
                }
            }
            .navigationTitle("Solace Mobile")
            .toolbar {
                Button("Clear") {
                    model.clearLog()
                }
            }
        }
    }
}

struct IosLogLine: Identifiable {
    let id = UUID()
    var text: String
}

@MainActor
final class IosSubscribeModel: ObservableObject {
    @Published var host = "210.59.255.161:80"
    @Published var vpn = "sinopac"
    @Published var username = "shioaji"
    @Published var password = ""
    @Published var topic = "TIC/v1/FOP/*/TFE/TXFG6"
    @Published var compressionLevel = 3
    @Published var status = "Ready"
    @Published var lines: [IosLogLine] = []
    @Published var receivedCount = 0
    @Published var latestMessage = "No quote received yet"

    private var session: SolaceKitSession?
    private var receiveTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?

    var isConnected: Bool {
        session != nil
    }

    var canConnect: Bool {
        !host.isEmpty && !vpn.isEmpty && !username.isEmpty && !password.isEmpty && !topic.isEmpty
    }

    func connectAndSubscribe() {
        guard canConnect else {
            append("Missing connection input")
            return
        }

        status = "Connecting"
        append("connect: \(host), vpn=\(vpn), compression=\(compressionLevel)")

        Task {
            do {
                let client = SolaceClient()
                let connectedSession = try await client.connect(
                    SolaceConfiguration(
                        host: host,
                        vpn: vpn,
                        username: username,
                        password: password,
                        compressionLevel: compressionLevel
                    )
                )

                session = connectedSession
                status = "Connected"
                append("connect: Ok")

                observeEvents(connectedSession)
                try await connectedSession.subscribe(topic)
                append("subscribe: Ok \(topic)")
                observeMessages(connectedSession)
            } catch {
                status = "Failed"
                append("FAILED: \(error)")
                disconnect()
            }
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        eventTask?.cancel()
        eventTask = nil
        session?.close()
        session = nil
        status = "Disconnected"
        append("disconnect: Ok")
    }

    func clearLog() {
        lines.removeAll(keepingCapacity: true)
        receivedCount = 0
        latestMessage = "No quote received yet"
    }

    private func observeEvents(_ session: SolaceKitSession) {
        eventTask = Task.detached { [weak self] in
            for await event in session.events {
                await self?.appendFromTask("event: \(event.name) \(event.detail)")
            }
        }
    }

    private func observeMessages(_ session: SolaceKitSession) {
        receiveTask = Task.detached { [weak self] in
            do {
                for try await message in session.messages {
                    let topic = message.topic ?? "(no topic)"
                    await self?.recordMessageFromTask(topic: topic, byteCount: message.payload.count)
                }
            } catch {
                await self?.appendFromTask("receive failed: \(error)")
            }
        }
    }

    private func append(_ text: String) {
        lines.insert(IosLogLine(text: text), at: 0)
        if lines.count > 80 {
            lines.removeLast(lines.count - 80)
        }
    }

    private func appendFromTask(_ text: String) {
        append(text)
    }

    private func recordMessageFromTask(topic: String, byteCount: Int) {
        receivedCount += 1
        latestMessage = "\(topic), bytes=\(byteCount)"
        append("message: \(topic), bytes=\(byteCount)")
    }
}
