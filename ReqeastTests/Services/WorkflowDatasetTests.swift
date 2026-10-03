import Foundation
import Testing
@testable import Reqeast

@Suite("Workflow datasets")
struct WorkflowDatasetTests {
    @Test func quotedCSVHandlesCommaNewlineAndBOM() throws {
        let data = Data("\u{feff}name,note\r\n\"a,b\",\"one\n\"\"two\"\"\"\r\n".utf8)
        let dataset = try WorkflowDatasetService.parse(data, isJSON: false)
        #expect(dataset.rows == [["name": "a,b", "note": "one\n\"two\""]])
    }
    @Test func rejectsMalformedAndMismatchedData() {
        for input in ["a,a\nx,y", "a,b\nx", "a\n\"unclosed", "a\n\"x\"bad"] {
            #expect(throws: (any Error).self) { try WorkflowDatasetService.parse(Data(input.utf8), isJSON: false) }
        }
        for input in ["[]", "[{\"a\":null}]", "[{\"a\":[]}]", "[{\"a\":1},{\"b\":2}]"] {
            #expect(throws: (any Error).self) { try WorkflowDatasetService.parse(Data(input.utf8), isJSON: true) }
        }
    }
    @Test func jsonScalarsAndLimits() throws {
        let dataset = try WorkflowDatasetService.parse(Data("[{\"number\":42,\"active\":true,\"text\":\"abc\"}]".utf8), isJSON: true)
        #expect(dataset.rows.first == ["number": "42", "active": "true", "text": "abc"])
        #expect(throws: (any Error).self) { try WorkflowDatasetService.parse(Data(repeating: 32, count: 1_048_577), isJSON: true) }
    }
}
