import CSolace
import Foundation

final class SolaceEnvironment: @unchecked Sendable {
    static let shared = SolaceEnvironment()

    private let lock = NSLock()
    private var referenceCount = 0

    private init() {}

    func retain() throws {
        lock.lock()
        defer { lock.unlock() }

        if referenceCount == 0 {
            try check("solClient_initialize", solClient_initialize(SOLCLIENT_LOG_NOTICE, nil))
        }
        referenceCount += 1
    }

    func release() {
        lock.lock()
        defer { lock.unlock() }

        guard referenceCount > 0 else {
            return
        }
        referenceCount -= 1
        if referenceCount == 0 {
            _ = solClient_cleanup()
        }
    }
}
