import Foundation

extension WorkflowManualContent {
    static let protocols: [WorkflowManualArticle] = [
        WorkflowManualArticle(title: "TCP/TLS", overview: "", steps: [
            WorkflowManualStep(title: "Host", body: "Add a TCP request, enter the host without a URL scheme and a numeric port, then click Connect. Wait for the connected state before sending a message. The conversation log displays incoming and outgoing data; Disconnect closes the persistent connection.", example: "Host: localhost\nPort: 9000\nMessage: hello"),
            WorkflowManualStep(title: "TLS", body: "Enable TLS only for a TLS endpoint. In message settings, choose encoding and line ending according to the server protocol. For a line-oriented service choose LF or CRLF; for binary protocols choose Hex. A plain TCP port cannot accept a TLS handshake."),
        ], section: "Protocol Tutorials"),
        WorkflowManualArticle(title: "UDP", overview: "", steps: [
            WorkflowManualStep(title: "Host", body: "Add a UDP request and enter the destination host and port. Choose the message encoding, enter one datagram, and click Send. UDP does not establish a reliable connection, so sending successfully does not prove that the remote service received the message.", example: "Host: localhost\nPort: 9001\nEncoding: UTF-8\nMessage: ping"),
            WorkflowManualStep(title: "Start listening", body: "Click Start listening when you need to receive responses and watch the conversation log. Click Stop listening when finished. If replies are absent, verify the server’s reply destination, firewall, port, and encoding; do not assume UDP retries or ordered delivery."),
        ], section: "Protocol Tutorials"),
        WorkflowManualArticle(title: "WebSocket", overview: "", steps: [
            WorkflowManualStep(title: "Connect", body: "Add a WebSocket request and enter ws:// or wss:// with the complete path. Add headers and required subprotocols before clicking Connect. Wait for the connection to open, then send messages. Incoming messages appear without resending the request.", example: "wss://your-test-api.example/chat\nSubprotocols: your-server-protocol"),
            WorkflowManualStep(title: "Auto Ping", body: "Message settings control encoding and automatic ping. Use the server’s required format; Hex sends binary data. Auto Ping helps keep idle connections active but does not authenticate them. Disconnect when finished; a failed handshake may require correcting the URL, token, or subprotocol."),
        ], section: "Protocol Tutorials"),
        WorkflowManualArticle(title: "SSE", overview: "", steps: [
            WorkflowManualStep(title: "Connect", body: "Add an SSE request with the server’s event-stream URL. Configure headers, including any required Authorization, then connect. SSE receives a stream of server events; it is not a bidirectional message channel like WebSocket. Event IDs, types, and data appear in the event log.", example: "https://your-test-api.example/events\nAuthorization: Bearer {{token}}"),
            WorkflowManualStep(title: "Timeout", body: "Use Connection settings to set the timeout and certificate verification. If the stream ends early, check the server heartbeat, configured timeout, and proxy buffering. A valid event service normally uses Content-Type: text/event-stream. Disconnect explicitly after collecting the events you need."),
        ], section: "Protocol Tutorials"),
        WorkflowManualArticle(title: "gRPC Schema and Unary Calls", overview: "", steps: [
            WorkflowManualStep(title: "Schema", body: "Add a gRPC request with authority host:port and the server’s TLS setting. In Schema, choose Proto bundle and import the .proto library with its dependencies, or choose Server reflection and Discover from server if supported. Select the resulting service and method.", example: "Authority: localhost:50051\nService: example.OrderService\nMethod: GetOrder\nJSON: {\"id\":\"42\"}"),
            WorkflowManualStep(title: "Request Body", body: "For a unary method, use JSON body mode with fields defined by the selected message schema. Add required metadata such as authorization, then click Send. Inspect the gRPC status and decoded response. Without descriptors, Hex mode requires correctly encoded protobuf bytes; arbitrary JSON is not a substitute."),
        ], section: "Protocol Tutorials"),
        WorkflowManualArticle(title: "gRPC Streaming and Deadlines", overview: "", steps: [
            WorkflowManualStep(title: "Send", body: "For server streaming, Send starts one request and the response log receives multiple messages; Stop stream ends listening. For client or bidirectional streaming, Connect first, edit the message body, and Send each message over the open stream."),
            WorkflowManualStep(title: "Half-close", body: "Half-close finishes only the client’s sending side and allows the server to return its final result. Cancel ends the stream. Configure request timeout and deadline in milliseconds; deadline 0 omits the explicit deadline. When a deadline is exceeded, inspect server processing before increasing it."),
        ], section: "Protocol Tutorials"),
    ]
}
