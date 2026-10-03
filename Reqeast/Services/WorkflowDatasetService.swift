import Foundation

struct WorkflowDataset: Equatable {
    let columns: [String]
    let rows: [[String: String]]
}

enum WorkflowDatasetService {
    static func parse(_ data: Data, isJSON: Bool) throws -> WorkflowDataset {
        guard data.count <= 1_048_576 else { throw failure() }
        let rows: [[String: String]]
        if isJSON {
            guard let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw failure() }
            rows = try objects.map { object in
                try object.mapValues { value in
                    guard !(value is NSNull), !(value is [Any]), !(value is [String: Any]) else { throw failure() }
                    return try ResponseJSONService.text(value)
                }
            }
        } else {
            guard var text = String(data: data, encoding: .utf8) else { throw failure() }
            if text.hasPrefix("\u{feff}") { text.removeFirst() }
            let records = try CSVRecords.parse(text)
            guard let header = records.first, !header.isEmpty, Set(header).count == header.count,
                  header.allSatisfy(validKey) else { throw failure() }
            rows = try records.dropFirst().map { values in
                guard values.count == header.count else { throw failure() }
                return Dictionary(uniqueKeysWithValues: zip(header, values))
            }
        }
        guard !rows.isEmpty, rows.count <= 1000, let first = rows.first,
              !first.isEmpty, first.keys.allSatisfy(validKey),
              rows.allSatisfy({ Set($0.keys) == Set(first.keys) }) else { throw failure() }
        return WorkflowDataset(columns: first.keys.sorted(), rows: rows)
    }

    static func validKey(_ key: String) -> Bool { !key.isEmpty && !key.contains("{") && !key.contains("}") }
    static func failure() -> RequestError {
        ResponseJSONService.failure(String(localized: "Use a CSV header or a JSON array with matching scalar fields. Limit: 1 MB and 1000 rows."))
    }
}
