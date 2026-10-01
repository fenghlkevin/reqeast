import Testing
@testable import Reqeast

@Suite("HTTP URL cURL input")
struct HttpUrlInputServiceTests {
    @Test func populatesMultilineCommand() throws {
        let command = """
        curl 'https://example.com/items?page=2' \\
          -H 'Authorization: Bearer token' \\
          -H 'Content-Type: application/json' \\
          -H 'X-Test: value' \\
          --data-raw '{"name":"hello"}'
        """
        let imported = try #require(try HttpUrlInputService.parseCommand(command, replacing: "https://old.test"))
        let data = ImportRequestMapper.map(imported.data)
        #expect(data.method == .post)
        #expect(data.url == "https://example.com/items")
        #expect(data.params.contains { $0.key == "page" && $0.value == "2" })
        #expect(data.headers.contains { $0.key == "X-Test" && $0.value == "value" })
        #expect(data.authToken == "token")
        #expect(data.bodyType == .json)
        #expect(data.bodyContent == "{\"name\":\"hello\"}")
    }

    @Test(arguments: [0, 8, 19])
    func recognizesPasteWithoutSelectingURL(position: Int) throws {
        let old = "https://old.test/api"
        let index = old.index(old.startIndex, offsetBy: position)
        let input = String(old[..<index]) + "curl https://new.test/items" + String(old[index...])
        let result = try #require(try HttpUrlInputService.parseCommand(input, replacing: old))
        #expect(result.data.url == "https://new.test/items")
    }

    @Test(arguments: ["https://example.com/curl", "curl.example.com", "https://example.com?q=curl"])
    func leavesOrdinaryURLsAlone(input: String) throws {
        #expect(try HttpUrlInputService.parseCommand(input, replacing: "https://old.test") == nil)
    }

    @Test func rejectsMalformedCommand() {
        #expect(throws: ImportError.self) {
            try HttpUrlInputService.parseCommand("curl -H", replacing: "https://old.test")
        }
    }

    @Test func preservesCookies() throws {
        let result = try #require(try HttpUrlInputService.parseCommand(
            "curl -b 'session=abc' https://example.com", replacing: ""
        ))
        #expect(result.cookies["session"] == "abc")
    }

    @Test(arguments: ["curl\thttps://example.com", "curl\nhttps://example.com"])
    func detectsWhitespaceSeparatedCommand(input: String) throws {
        #expect(ImportRequestService.detectFormat(input) == .curl)
        #expect(try HttpUrlInputService.parseCommand(input, replacing: "") != nil)
    }
}
