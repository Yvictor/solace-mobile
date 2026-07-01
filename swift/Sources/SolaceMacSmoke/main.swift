import CSolace
import Foundation

func describe(_ code: solClient_returnCode_t) -> String {
    guard let pointer = solClient_returnCodeToString(code) else {
        return "\(code.rawValue)"
    }
    return String(cString: pointer)
}

let initResult = solClient_initialize(SOLCLIENT_LOG_NOTICE, nil)
print("solClient_initialize: \(describe(initResult))")

guard initResult == SOLCLIENT_OK else {
    exit(1)
}

var versionPointer: solClient_version_info_pt?
let versionResult = solClient_version_get(&versionPointer)
print("solClient_version_get: \(describe(versionResult))")

if versionResult == SOLCLIENT_OK, let version = versionPointer?.pointee {
    let versionText = version.version_p.map(String.init(cString:)) ?? "<nil>"
    let dateText = version.dateTime_p.map(String.init(cString:)) ?? "<nil>"
    let variantText = version.variant_p.map(String.init(cString:)) ?? "<nil>"
    print("Solace C SDK version: \(versionText)")
    print("Build date: \(dateText)")
    print("Variant: \(variantText)")
}

let cleanupResult = solClient_cleanup()
print("solClient_cleanup: \(describe(cleanupResult))")

guard versionResult == SOLCLIENT_OK, cleanupResult == SOLCLIENT_OK else {
    exit(1)
}
