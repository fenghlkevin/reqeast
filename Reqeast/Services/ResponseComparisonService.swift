import Foundation

nonisolated struct ResponseDifference: Identifiable {
    var id: String { path }
    let path: String
    let before: String?
    let after: String?
}

enum ResponseComparisonService {
    @concurrent
    static func compare(_ baseline: HttpResponseData, _ current: HttpResponseData,
                        ignoring: Set<String>) async throws -> [ResponseDifference] {
        let old = try ResponseJSONService.fields(in: ResponseJSONService.parse(baseline.body))
        let new = try ResponseJSONService.fields(in: ResponseJSONService.parse(current.body))
        var differences: [ResponseDifference] = []
        if baseline.statusCode != current.statusCode {
            differences.append(ResponseDifference(path: "HTTP status", before: String(baseline.statusCode),
                                                  after: String(current.statusCode)))
        }
        for path in Set(old.keys).union(new.keys).sorted() {
            if ignoring.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { continue }
            if old[path] != new[path] {
                differences.append(ResponseDifference(path: path, before: old[path], after: new[path]))
            }
        }
        return differences
    }
}
