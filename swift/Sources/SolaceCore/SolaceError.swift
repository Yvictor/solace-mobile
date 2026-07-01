import CSolace
import Foundation

public struct SolaceError: Error, CustomStringConvertible, Sendable {
    public var operation: String
    public var returnCode: String
    public var subCode: String
    public var detail: String

    public init(operation: String, returnCode: String, subCode: String, detail: String) {
        self.operation = operation
        self.returnCode = returnCode
        self.subCode = subCode
        self.detail = detail
    }

    public var description: String {
        var parts = ["\(operation) failed", "returnCode=\(returnCode)"]
        if !subCode.isEmpty {
            parts.append("subCode=\(subCode)")
        }
        if !detail.isEmpty {
            parts.append("detail=\(detail)")
        }
        return parts.joined(separator: " ")
    }
}

@inline(__always)
func returnCodeString(_ code: solClient_returnCode_t) -> String {
    guard let pointer = solClient_returnCodeToString(code) else {
        return "\(code.rawValue)"
    }
    return String(cString: pointer)
}

func makeSolaceError(_ operation: String, _ code: solClient_returnCode_t) -> SolaceError {
    let errorInfo = solClient_getLastErrorInfo()
    let subCode = errorInfo.map { info -> String in
        guard let pointer = solClient_subCodeToString(info.pointee.subCode) else {
            return "\(info.pointee.subCode.rawValue)"
        }
        return String(cString: pointer)
    } ?? ""
    let detail = errorInfo.map { info in
        withUnsafePointer(to: info.pointee.errorStr) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(SOLCLIENT_ERRORINFO_STR_SIZE)) {
                String(cString: $0)
            }
        }
    } ?? ""
    return SolaceError(
        operation: operation,
        returnCode: returnCodeString(code),
        subCode: subCode,
        detail: detail
    )
}

func check(_ operation: String, _ code: solClient_returnCode_t) throws {
    guard code == SOLCLIENT_OK else {
        throw makeSolaceError(operation, code)
    }
}
