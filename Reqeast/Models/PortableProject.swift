import Foundation

struct PortableProject: Codable {
    var format = 1
    var name: String
    var requestIds: [UUID]
    var workflows: [SavedHttpWorkflow]
    var environments: [PortableEnvironment]
}

struct PortableEnvironment: Codable {
    var id: UUID
    var name: String
    var variables: [EnvironmentVariable]
}

struct PortableRequest: Codable {
    let id: UUID
    let name: String
    var httpData: HttpRequestData
}
