import SwiftUI

struct HttpUrlInputField: View, RequestDataBindable {
    let store: ProjectStore
    let request: Request
    var isReadOnly: Bool
    var onSubmit: () -> Void

    @State private var importError: RequestError?

    var body: some View {
        TextField("Enter URL or paste cURL", text: urlBinding)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .onSubmit(onSubmit)
            .devTextInput()
            .disabled(isReadOnly)
            .accessibilityIdentifier("http-request-url-field")
            .alert("Import Request", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                if let importError {
                    Text(importError.message).textSelection(.enabled)
                }
            }
    }

    private var currentRequest: Request {
        store.requests.first { $0.id == request.id } ?? request
    }

    private var urlBinding: Binding<String> {
        Binding(
            get: { readData().url },
            set: { input in
                guard !isReadOnly else { return }
                do {
                    if let result = try HttpUrlInputService.parseCommand(input, replacing: readData().url) {
                        var updated = currentRequest
                        updated.httpData = ImportRequestMapper.map(result.data)
                        updated.updatedAt = Date()
                        store.updateRequest(updated)
                        if !result.cookies.isEmpty {
                            CookieStore.shared.addCookiesFromImport(result.cookies, url: result.data.url)
                        }
                    } else {
                        updateData { $0.url = input }
                    }
                    importError = nil
                } catch {
                    importError = .from(message: error.localizedDescription, kind: .invalidConfig)
                }
            }
        )
    }

    func readData() -> HttpRequestData {
        currentRequest.httpData ?? HttpRequestData()
    }

    func writeData(_ data: HttpRequestData, to request: inout Request) {
        request.httpData = data
    }
}
