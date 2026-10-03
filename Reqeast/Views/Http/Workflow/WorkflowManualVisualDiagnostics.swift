// Original RHEQ step-by-step workflow and diagnostic manual.
import Foundation

extension WorkflowManualContent {
    static let visualDiagnostics: [WorkflowManualArticle] = [
        WorkflowManualArticle(title: "Workflow Overview", overview:
            "Build a numbered flow and follow each variable back to the response that provides it.", steps: [
            WorkflowManualStep(title: "Environment", body:
                "Create two HTTP requests in one project and select an environment. Configure the login URL, method and body, then send it. Confirm a successful JSON response with a non-null token field. These paths are examples; use your API's actual fields.", example: "POST /login\n{\"data\": {\"token\": \"example-token\"}}\nGET /orders"),
            WorkflowManualStep(title: "Response Variables", body:
                "Send the source request once. Open HTTP Workflows → Variables & Checks → Use Response in Another Request.", example: "① Login\n   /data/token → {{token}}\n       ↓\n② Orders\n   Authorization: Bearer {{token}}"),
            WorkflowManualStep(title: "Create Response Link", body:
                "Choose a JSON field and a target request. RHEQ creates a secret extraction rule and a header reference. Authorization uses Bearer. Other headers use the variable directly.", example: "/data/token\ntoken\nAuthorization: Bearer {{token}}"),
            WorkflowManualStep(title: "Header", body:
                "Set the response field to /data/token, variable name to token, target to Orders, and header to Authorization. Click Create Response Link. This saves rules, not the current token. Run Login again before Orders. Authorization replaces the target's previous automatic authentication; other headers keep it."),
            WorkflowManualStep(title: "Choose & Reorder Requests", body:
                "Open Run Requests, select the requests, and move the source above the target. Save the workflow. The overview lists variable sources and marks missing values."),
            WorkflowManualStep(title: "Save Workflow", body:
                "In Run Requests, expand Choose & Reorder Requests. Check Login and Orders, uncheck unrelated requests, and move Login above Orders with the arrows. Numbers show the actual run order. Enter a workflow name, select its environment, and click Save Workflow.", example: "① POST /login → token\n     ↓\n② GET /orders\n   Authorization: Bearer {{token}}"),
            WorkflowManualStep(title: "Run Selected Requests", body:
                "Run the workflow. The active step shows progress. A failed step shows its error and failed checks. Fix that step before running again."),
            WorkflowManualStep(title: "Missing Variable", body:
                "If a variable is missing, check the selected environment, enabled extraction rule, spelling, and source order. If no response fields appear, send the source first and check that its response is valid JSON under 1 MB. Field paths start with /; nested fields use /data/token. Links create headers; URL and body references must be entered as {{token}} manually.")
        ]),
        WorkflowManualArticle(title: "Diagnostics", overview:
            "Inspect a completed or failed HTTP request without sending it again.", steps: [
            WorkflowManualStep(title: "Sent Request", body:
                "After sending, click Diagnostics above the response, or open HTTP Workflows → Inspect Request. Sent Request records the configuration at send time; Request Preview reflects current edits."),
            WorkflowManualStep(title: "Request Preview", body:
                "Expand Sent Request to review the prepared URL, headers and body from that send. Editing the environment afterward does not change this record. It excludes transport-added headers and later redirects. After restarting RHEQ, send again to recreate the record. Opening Diagnostics or Inspect Request never sends a request."),
            WorkflowManualStep(title: "Timing", body:
                "Connection, TLS handshake, redirects, and server wait are measured together. Separate TCP and TLS timings are unavailable.", example: "DNS → Connect + TLS + Server Wait → Download"),
            WorkflowManualStep(title: "Request Failed", body:
                "For connection errors, check DNS, host, port and VPN. For TLS errors, read the certificate cause. A timeout cannot identify one failed phase. HTTP 4xx or 5xx means a response arrived; check status and body. Redirect and certificate details appear only when the completed response includes them. Total duration includes the response download."),
            WorkflowManualStep(title: "TLS Error", body:
                "Check the certificate hostname, expiry, and trusted issuer. The full TLS error is shown below."),
            WorkflowManualStep(title: "Copy Redacted Diagnostics", body:
                "Copied reports omit bodies, cookies, credentials, and URL query values. Review the report before sharing.")
        ])
    ]
}
