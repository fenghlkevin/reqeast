// Modified for RHEQ: user-facing product name.
import Foundation

extension WorkflowManualContent {
    static let advanced: [WorkflowManualArticle] = [
        WorkflowManualArticle(title: "Importing API Specifications", overview: "", steps: [
            WorkflowManualStep(title: "Import Spec...", body: "From the project sidebar add menu choose Import Spec. Select File, URL, or Paste and provide OpenAPI, Postman, or another supported format. Continue to the preview, choose a new or existing project, and inspect the generated request counts before importing."),
            WorkflowManualStep(title: "Advanced", body: "Expand Advanced to choose folder strategy, request naming, preferred body type, and whether to generate example values, optional parameters, auth scaffolding, and server environments. Decide whether to link the source. HAR credentials can become placeholders; fill these values locally after import."),
        ], section: "Advanced Configuration"),
        WorkflowManualArticle(title: "Linked Specifications and Git Access", overview: "", steps: [
            WorkflowManualStep(title: "Check for updates", body: "Open the linked-spec icon in the request-list toolbar and choose Check for updates. Review added, changed, and removed operations before applying the selected changes. Background spec check only notifies; it never applies changes automatically. A one-time file import has no live source to refresh."),
            WorkflowManualStep(title: "Trusted Git Hosts", body: "For private Git sources, configure the host, organization/user, and provider token in Settings. GitHub device login is available there. Add enterprise or self-hosted hosts to Trusted Git Hosts only when they are your intended source. Provider tokens are stored in Keychain; they are separate from API request authentication."),
        ], section: "Advanced Configuration"),
        WorkflowManualArticle(title: "Advanced Authentication", overview: "", steps: [
            WorkflowManualStep(title: "Authentication", body: "Choose JWT Bearer, AWS Signature, Hawk, or Akamai EdgeGrid to match the server. Fill the credentials and signing fields supplied by its API documentation. Inspect the prepared request before sending. Signatures are regenerated when sending."),
            WorkflowManualStep(title: "OAuth 2.0", body: "OAuth 2.0 currently requires an access token obtained separately. Enter it manually; configuring authorization and token URLs does not perform automatic login. Digest, OAuth 1.0, and NTLM are marked as coming soon and cannot be used yet."),
        ], section: "Advanced Configuration"),
        WorkflowManualArticle(title: "HTTP Network Settings", overview: "", steps: [
            WorkflowManualStep(title: "Settings", body: "Open the selected HTTP request’s Settings. Choose automatic HTTP version or HTTP/1 or HTTP/2, set its timeout, and configure redirect limits. Keep certificate verification enabled for normal use. A longer timeout does not fix an invalid host or port."),
            WorkflowManualStep(title: "Headers", body: "Review redirect options for preserving the original method, forwarding Authorization to another host, and Referer handling. Enable URL encoding when needed and disable the cookie jar only for requests that must not reuse login cookies. Inspect the final URL and headers before testing."),
        ], section: "Advanced Configuration"),
        WorkflowManualArticle(title: "App Defaults and iCloud", overview: "", steps: [
            WorkflowManualStep(title: "Appearance", body: "Open Settings → Appearance and choose Follow System, Light, or Dark. The choice is saved and applies to the workspace and Settings. Follow System switches with your device appearance."),
            WorkflowManualStep(title: "Settings", body: "In Settings, configure HTTP defaults, editor indentation, response filtering, and history limits. Review each existing request’s own settings separately. iCloud needs an eligible signed app and an Apple account; local ad hoc builds may disable CloudKit. Sync does not keep live socket connections running."),
        ], section: "Advanced Configuration"),
        WorkflowManualArticle(title: "Shortcuts and MCP", overview: "", steps: [
            WorkflowManualStep(title: "Shortcuts", body: "In Apple Shortcuts, find RHEQ’s actions for HTTP, TCP, UDP, WebSocket, SSE, and gRPC. Configure the action’s fields, run a small test, and inspect its output before adding it to a larger automation. These actions are separate from saved HTTP workflows."),
            WorkflowManualStep(title: "MCP", body: "On macOS, enable MCP export in Settings and follow its Setup Guide to configure your client. MCP reads exported request and response data. Review bodies and custom fields for private content: an AI client may send what it reads to its provider. Disable export when no longer needed."),
        ], section: "Advanced Configuration"),
    ]
}
