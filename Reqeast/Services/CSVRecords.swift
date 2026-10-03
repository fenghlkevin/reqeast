import Foundation

/// RFC 4180 fields, including quoted commas, doubled quotes and embedded newlines.
enum CSVRecords {
    static func parse(_ text: String) throws -> [[String]] {
        var records: [[String]] = [], record: [String] = [], field = ""
        var quoted = false, closed = false, started = false
        let chars = Array(text)
        var index = 0
        func finishField() { record.append(field); field = ""; closed = false; started = false }
        func finishRecord() { finishField(); records.append(record); record = [] }
        while index < chars.count {
            let char = chars[index]
            if quoted {
                if char == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" { field.append("\""); index += 1 }
                    else { quoted = false; closed = true }
                } else { field.append(char) }
            } else if char == "," { finishField() }
            else if char == "\r\n" || char == "\n" || char == "\r" { finishRecord() }
            else if char == "\"" && !started && field.isEmpty && !closed { quoted = true; started = true }
            else {
                guard !closed && char != "\"" else { throw WorkflowDatasetService.failure() }
                field.append(char); started = true
            }
            index += 1
        }
        guard !quoted else { throw WorkflowDatasetService.failure() }
        if started || closed || !field.isEmpty || !record.isEmpty { finishRecord() }
        return records
    }
}
