import Foundation

extension WorkflowManualContent {
    static let basics: [WorkflowManualArticle] = [
        WorkflowManualArticle(title: "Your First HTTP Request", overview: "", steps: [
            WorkflowManualStep(title: "New Project", body: "Start with a reachable test API. Choose New Project from the welcome screen or the sidebar add menu, enter a name, and create it. Select the project, then add an HTTP request from the add-request menu."),
            WorkflowManualStep(title: "HTTP", body: "Choose GET and enter the complete URL, including http:// or https://. Leave Authentication set to No Auth for a public endpoint. No environment or workflow is required for this first request. The example domain is illustrative; replace it.", screenshot: "editor", example: "GET https://your-test-api.example/health"),
            WorkflowManualStep(title: "Send request", body: "Click the paper-plane Send button. When the request completes, inspect the status and Body below the editor. A successful response is usually 2xx. If no response appears, read the displayed error before changing other settings."),
        ], section: "Quick Start"),
        WorkflowManualArticle(title: "Projects, Folders, and Requests", overview: "", steps: [
            WorkflowManualStep(title: "Folders", body: "Group related APIs in one project. Use the sidebar folder controls to organize projects or requests at their respective level. Give requests names that describe their purpose; changing a name does not change the target URL."),
            WorkflowManualStep(title: "Duplicate", body: "Open a request’s context menu to rename or duplicate it. Duplicate before trying a different body or authentication setup so the original remains available. Use the request filter to locate a request in a large collection."),
            WorkflowManualStep(title: "Delete", body: "Review the selected item before deleting it. Removing a project also removes its requests from the active collection. Export a backup first. Saved HTTP workflows that reference deleted requests must be updated before their next run."),
        ], section: "Everyday Use"),
        WorkflowManualArticle(title: "HTTP Parameters, Headers, and Bodies", overview: "", steps: [
            WorkflowManualStep(title: "Params", body: "Open Params to add query keys and values; enabled rows are sent and unchecked rows are skipped. Use Headers for custom headers. Bulk Edit accepts one key:value per line. Check the prepared URL and headers in Inspect Request before sending.", screenshot: "preview", example: "limit:10\nAccept:application/json"),
            WorkflowManualStep(title: "Body", body: "For a POST request, open Body and choose JSON, enter valid JSON, then send. Raw lets you choose a content type. URL-encoded uses text fields; multipart accepts text or file rows; Binary sends one selected file. Select the type expected by the server.", example: "POST https://your-test-api.example/orders\n{\"product\":\"book\",\"quantity\":1}"),
            WorkflowManualStep(title: "Strict HTTP Mode", body: "Strict HTTP Mode hides and omits bodies for GET, HEAD, and OPTIONS. Change this global default only if your API explicitly requires such a body. A 400 or 415 response often means the body shape or Content-Type differs from the server contract."),
        ], section: "Everyday Use"),
        WorkflowManualArticle(title: "Authentication and Credentials", overview: "", steps: [
            WorkflowManualStep(title: "Bearer Token", body: "Open Auth and select Bearer Token. Enter the token itself, such as {{token}}, without adding a second Bearer prefix. Define token in the active environment or extract it from a login response. A 401 response requires checking expiry, environment, and the prepared Authorization header.", screenshot: "preview"),
            WorkflowManualStep(title: "Basic Authentication", body: "Choose Basic Authentication and enter the username and password required by the API. API Key instead needs a key name, value, and placement in Header or Query Params. Keep secret values in named variables and avoid adding duplicate authentication headers manually."),
        ], section: "Everyday Use"),
        WorkflowManualArticle(title: "Environments and Variable Replacement", overview: "", steps: [
            WorkflowManualStep(title: "Environments", body: "Open the editor environment menu, choose Manage Environments, and add Test and Production separately. Add an enabled baseUrl to each, then activate the intended environment. Put {{baseUrl}} in request URLs. Compare the resolved host in Inspect Request before sending.", example: "Test: baseUrl = https://test-api.example\nProduction: baseUrl = https://api.example\nURL: {{baseUrl}}/orders"),
            WorkflowManualStep(title: "Secret variable", body: "Variable names are case-sensitive. A disabled variable does not participate in replacement. Mark passwords and tokens as secret to hide them in inspection and omit their values from safe exports. Missing-variable errors name the values you must define before sending."),
        ], section: "Everyday Use"),
        WorkflowManualArticle(title: "Reading Responses and History", overview: "", steps: [
            WorkflowManualStep(title: "Body", body: "After sending, open response Body for the content, Headers for server headers, Cookies for returned cookies, and Info for connection details. JSON can be viewed formatted or raw. Enter a jq filter to select fields; clear the filter to restore the full response.", example: ".data\n.data.token\n.items[] | .id"),
            WorkflowManualStep(title: "Request history", body: "Open the clock-shaped request history button to review previous executions. Use status, elapsed time, size, and response Info to separate server errors from connection failures. The code-snippet toolbar exports request code; review generated credentials before copying it to another tool."),
        ], section: "Everyday Use"),
        WorkflowManualArticle(title: "Cookies and Login Sessions", overview: "", steps: [
            WorkflowManualStep(title: "Cookies", body: "Send a login request and inspect Set-Cookie in the response headers and Cookies tab. Matching cookies are stored for later requests when the cookie jar is enabled. Cookie matching depends on domain, path, expiry, and Secure; a token login may instead require Bearer authentication."),
            WorkflowManualStep(title: "Disable cookie jar", body: "In request Settings, Disable cookie jar prevents this request from storing or sending cookies. Keep it off for a cookie-based login flow. Use Inspect Request to confirm the outgoing Cookie header; switch environments carefully because an environment change alone is not a cookie reset."),
        ], section: "Everyday Use"),
        WorkflowManualArticle(title: "Backups and Project Transfer", overview: "", steps: [
            WorkflowManualStep(title: "Export Project", body: "Use the project context menu → Export Project to create a .reqeast file. Credentials and secret environment values are excluded by default; enabling either option writes them as plain text. For all projects, use Settings → Data → Export All Projects. Keep backups in a controlled location."),
            WorkflowManualStep(title: "Import Project...", body: "Choose Import Project from the sidebar add menu or Settings → Data, select the backup, and review the import before confirming. Check requests and environments after import and restore omitted secrets. HTTP Project Files export is a separate format for Git and the CLI, not a complete multi-protocol backup."),
        ], section: "Everyday Use"),
    ]
}
