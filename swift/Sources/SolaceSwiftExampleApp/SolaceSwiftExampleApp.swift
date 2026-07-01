import Foundation
import SolaceKit
import SwiftUI

@main
struct SolaceSwiftExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif
    }
}

struct ContentView: View {
    @StateObject private var model = SolaceExampleModel()

    var body: some View {
        NavigationSplitView {
            Form {
                Section("Connection") {
                    TextField("Host", text: $model.host)
                    TextField("VPN", text: $model.vpn)
                    TextField("Username", text: $model.username)
                    SecureField("Password", text: $model.password)
                    Stepper("Compression \(model.compressionLevel)", value: $model.compressionLevel, in: 0...9)
                }

                Section("Direct Subscribe") {
                    TextField("Topic", text: $model.topic)
                }

                Section("Queue Flow") {
                    Toggle("Use queue flow", isOn: $model.useQueueFlow)
                    TextField("Queue", text: $model.queueName)
                }

                Section("Publish") {
                    TextField("Publish topic", text: $model.publishTopic)
                    TextField("Publish text", text: $model.publishText)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Solace")
            .toolbar {
                ToolbarItemGroup {
                    Button(model.isConnected ? "Disconnect" : "Connect") {
                        model.isConnected ? model.disconnect() : model.connect()
                    }
                    .disabled(!model.canConnect)

                    Button("Publish") {
                        model.publish()
                    }
                    .disabled(!model.isConnected || model.publishTopic.isEmpty)
                }
            }
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Circle()
                        .fill(model.statusColor)
                        .frame(width: 10, height: 10)
                    Text(model.status)
                        .font(.headline)
                    Spacer()
                    Button("Clear") {
                        model.clearLog()
                    }
                }
                .padding()

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.lines) { line in
                            Text(line.text)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Messages")
        }
        .frame(minWidth: 920, minHeight: 620)
    }
}

struct LogLine: Identifiable {
    let id = UUID()
    var text: String
}

@MainActor
final class SolaceExampleModel: ObservableObject {
    @Published var host = "210.59.255.161:80"
    @Published var vpn = "sinopac"
    @Published var username = "shioaji"
    @Published var password = ""
    @Published var topic = "TIC/v1/FOP/*/TFE/TXFG6"
    @Published var queueName = ""
    @Published var publishTopic = "api/test"
    @Published var publishText = "solace-mobile swift example"
    @Published var compressionLevel = 3
    @Published var useQueueFlow = false
    @Published var status = "Disconnected"
    @Published var lines: [LogLine] = []

    private var session: SolaceKitSession?
    private var queueFlow: SolaceKitQueueFlow?
    private var receiveTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var flowEventTask: Task<Void, Never>?

    var isConnected: Bool {
        session != nil
    }

    var canConnect: Bool {
        !host.isEmpty && !vpn.isEmpty && !username.isEmpty && !password.isEmpty
    }

    var statusColor: Color {
        isConnected ? .green : .secondary
    }

    func connect() {
        guard canConnect else {
            append("Missing connection input")
            return
        }

        status = "Connecting"
        append("Connecting to \(host), vpn=\(vpn), compression=\(compressionLevel)")

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
                observeSessionEvents(connectedSession)

                if useQueueFlow {
                    try await bindQueueFlow(connectedSession)
                } else {
                    try await connectedSession.subscribe(topic)
                    append("subscribe: Ok \(topic)")
                    observeDirectMessages(connectedSession)
                }
            } catch {
                status = "Failed"
                append("FAILED: \(error)")
                disconnect()
            }
        }
    }

    func publish() {
        guard let session else {
            append("Publish skipped: not connected")
            return
        }

        let topic = publishTopic
        let payload = Data(publishText.utf8)
        Task {
            do {
                try await session.publish(topic: topic, payload: payload)
                append("publish: Ok \(topic), bytes=\(payload.count)")
            } catch {
                append("publish failed: \(error)")
            }
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        eventTask?.cancel()
        eventTask = nil
        flowEventTask?.cancel()
        flowEventTask = nil
        queueFlow?.close()
        queueFlow = nil
        session?.close()
        session = nil
        status = "Disconnected"
        append("disconnect: Ok")
    }

    func clearLog() {
        lines.removeAll(keepingCapacity: true)
    }

    private func bindQueueFlow(_ session: SolaceKitSession) async throws {
        let configuration = QueueFlowConfiguration(queueName: queueName)
        let flow = try await session.createQueueFlow(configuration)
        queueFlow = flow
        append("queue flow bind: Ok \(queueName)")
        observeFlowEvents(flow)
        observeGuaranteedMessages(flow)
    }

    private func observeSessionEvents(_ session: SolaceKitSession) {
        eventTask = Task.detached { [weak self] in
            for await event in session.events {
                await self?.appendFromTask("session event: \(event.name) \(event.detail)")
            }
        }
    }

    private func observeDirectMessages(_ session: SolaceKitSession) {
        receiveTask = Task.detached { [weak self] in
            do {
                for try await message in session.messages {
                    let topic = message.topic ?? "(no topic)"
                    await self?.appendFromTask("direct message: \(topic), bytes=\(message.payload.count)")
                }
            } catch {
                await self?.appendFromTask("direct receive failed: \(error)")
            }
        }
    }

    private func observeFlowEvents(_ flow: SolaceKitQueueFlow) {
        flowEventTask = Task.detached { [weak self] in
            for await event in flow.events {
                await self?.appendFromTask("flow event: \(event.name) \(event.detail)")
            }
        }
    }

    private func observeGuaranteedMessages(_ flow: SolaceKitQueueFlow) {
        receiveTask = Task.detached { [weak self] in
            do {
                for try await message in flow.messages {
                    try message.acknowledge()
                    let topic = message.topic ?? "(no topic)"
                    await self?.appendFromTask("queue message: id=\(message.messageID), topic=\(topic), bytes=\(message.payload.count), ack=Ok")
                }
            } catch {
                await self?.appendFromTask("queue receive failed: \(error)")
            }
        }
    }

    private func append(_ text: String) {
        lines.append(LogLine(text: text))
        if lines.count > 300 {
            lines.removeFirst(lines.count - 300)
        }
    }

    private func appendFromTask(_ text: String) {
        append(text)
    }
}
