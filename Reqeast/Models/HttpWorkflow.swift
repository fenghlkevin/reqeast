import Foundation

struct HttpWorkflow: Codable, Hashable {
    var extractions: [ResponseExtraction] = []
    var assertions: [ResponseAssertion] = []
}

struct ResponseExtraction: Codable, Hashable, Identifiable {
    var id = UUID()
    var pointer = "/token"
    var variable = "token"
    var isSecret = true
    var enabled = true
}

enum ResponseAssertionKind: String, Codable, CaseIterable {
    case status, jsonValue, elapsed

    var localizedName: String {
        switch self {
        case .status: String(localized: "Status code equals")
        case .jsonValue: String(localized: "JSON field equals")
        case .elapsed: String(localized: "Response time below (ms)")
        }
    }
}

struct ResponseAssertion: Codable, Hashable, Identifiable {
    var id = UUID()
    var kind: ResponseAssertionKind = .status
    var pointer = ""
    var expected = "200"
    var enabled = true
}

struct WorkflowCheck: Identifiable {
    let id = UUID()
    let label: String
    let passed: Bool
    let detail: String
}
