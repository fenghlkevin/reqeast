// Modified for RHEQ: user-facing product name.
import Foundation

struct WorkflowManualStep {
    let title: String
    let body: String
    var screenshot: String? = nil
    var example: String? = nil
}

struct WorkflowManualArticle {
    let title: String
    let overview: String
    let steps: [WorkflowManualStep]
    var section: String = "HTTP Workflows"
}

enum WorkflowManualContent {
    static let articles = basics + protocols + workflowArticles + visualDiagnostics + ideaIntegration + advanced + troubleshooting

    static func initialChapter(for topic: Int) -> Int {
        let title = switch topic {
        case 1: "Compare Responses"
        case 2: "Workflow Overview"
        case 3: "Diagnostics"
        case 4: "Project Files"
        case 5: "IDEA Controller Import"
        default: "Your First HTTP Request"
        }
        return articles.firstIndex { $0.title == title } ?? 0
    }

    static let workflowArticles: [WorkflowManualArticle] = [
        WorkflowManualArticle(title: "Getting Started", overview:
            "Follow this example with your own API. Screenshots show the macOS app using fictional demo data. On iPhone and iPad, the same actions may appear in menus. Nothing in this manual sends a request automatically.", steps: [
            WorkflowManualStep(title: "Create three HTTP requests", body:
                "Create a project, then use the add-request menu to add three separate HTTP requests. Name them Login, Create order, and Query order. Set their methods and URLs to POST /login, POST /orders, and GET /orders/{{orderId}}. Replace the example host and paths with your API.", screenshot: "editor"),
            WorkflowManualStep(title: "Set up a test environment", body:
                "Open the environment picker and manage environments. Create Test and add baseUrl, username, password, and product. Mark password as secret. Activate Test. Use {{baseUrl}} in the URL and variable references in the request body.", example: "baseUrl = https://api.example.test\nusername = demo\npassword = your-test-password\nproduct = book"),
            WorkflowManualStep(title: "Open HTTP Workflows", body:
                "Select an HTTP request and click the flowchart button in the editor toolbar. The panel contains Variables & Checks, Compare Responses, Run Requests, Inspect Request, and Project Files. You can also open this manual from Settings → User Manual.", screenshot: "rules")
        ]),
        WorkflowManualArticle(title: "Response Variables", overview:
            "The first request produces a value that a later request uses. Guide step numbers describe operations; request execution numbers are shown in Run Requests.", steps: [
            WorkflowManualStep(title: "Send the login request", body:
                "Select Login in the sidebar, activate Test, enter the login body and click Send. Confirm a 2xx response with a token. The example response is below; your response field may differ.", example: "{\"data\":{\"token\":\"demo-token\"}}"),
            WorkflowManualStep(title: "Choose the field and variable", body:
                "Open Variables & Checks. Click Add Response Variable, choose /data/token, name the variable token, and enable Secret variable. Click Save Variables from Current Response. Future successful sends extract enabled rules automatically.", screenshot: "rules"),
            WorkflowManualStep(title: "Reuse it in the next request", body:
                "Select Create order, open Authentication, choose Bearer Token and enter {{token}}. Use the same Test environment. Send it after Login has succeeded. To capture the created order ID, add a rule on Create order from /data/id to orderId, then use {{orderId}} in Query order.", example: "Login → token\nCreate order uses {{token}} → orderId\nQuery order uses {{token}} and {{orderId}}")
        ]),
        WorkflowManualArticle(title: "Saved Workflows", overview:
            "Save a named sequence and its environment. Requests keep their own extraction and check rules; editing a request changes future runs of the workflow.", steps: [
            WorkflowManualStep(title: "Select and order requests", body:
                "Open Run Requests and choose New Workflow. Select All HTTP Requests or a folder. Check Login, Create order, and Query order. Use the up and down arrows to put them in that order. The first checked row is request 1, the next is request 2; unchecked rows are skipped.", screenshot: "runner"),
            WorkflowManualStep(title: "Save the workflow", body:
                "Enter Order test in Workflow Name, choose Test in Environment, and enable Stop on first failure. Click Save Workflow. Saved workflows belong to this project and sync with its project record. Choose one from the Workflow picker to restore its order and settings."),
            WorkflowManualStep(title: "Run and inspect results", body:
                "Click Run Selected Requests. Requests are actually sent one at a time. Each result shows status, time, checks, and errors. A non-2xx response or failed extraction/check counts as failure. Stop Run prevents later sends, but an in-flight request may still finish. Export Run Report saves results as JSON without response bodies or variable values.", screenshot: "results"),
            WorkflowManualStep(title: "Update a saved workflow", body:
                "Select a saved workflow, change the selection or order, and click Save Workflow to replace it. Delete Workflow removes only the saved sequence. If a request or its selected environment was deleted, repair the workflow before running.")
        ]),
        WorkflowManualArticle(title: "Variable Sources", overview:
            "Inspect Request shows the variables referenced by this request and explains where their current values came from.", steps: [
            WorkflowManualStep(title: "Open Inspect Request", body:
                "Select the request that uses {{token}} and open HTTP Workflows → Inspect Request. Under Variable Sources, click {{token}} to expand its details.", screenshot: "inspect"),
            WorkflowManualStep(title: "Read the source details", body:
                "An extracted variable shows the source request, response field, and update time. A manually entered variable says Defined in the environment. Secret values remain hidden unless you enable Show Secret Values."),
            WorkflowManualStep(title: "Fix missing variables", body:
                "Missing Variable means the active environment has no enabled value. Choose the correct environment, add the value there, or run the earlier extraction request first. Send stops before making a network request when required variables are missing.")
        ]),
        WorkflowManualArticle(title: "Request Preview", overview:
            "Preview prepares the request through the same path as Send, so you can check variable replacement and credentials before sending.", steps: [
            WorkflowManualStep(title: "Review the prepared request", body:
                "Open Inspect Request and scroll to Request Preview. Check the method, resolved URL, query parameters, headers, Cookie header, and body. GET, HEAD, and OPTIONS bodies follow the HTTP strict-mode setting.", screenshot: "preview"),
            WorkflowManualStep(title: "Check secrets and attachments", body:
                "Secret environment values and credential headers are hidden by default. Enable Show Secret Values only when needed. File bodies show attachment names and sizes. This preview is before redirects; signed credentials are generated again at send time."),
            WorkflowManualStep(title: "Return to the editor and send", body:
                "If the host, token, or body is wrong, close the panel and fix the environment or request. Reopen the preview to verify, then click Send in the editor. Opening a preview never sends the request.")
        ]),
        WorkflowManualArticle(title: "Test Data", overview:
            "Use a CSV or JSON file to run the whole workflow once per data row. Rows are isolated and do not overwrite the saved environment.", steps: [
            WorkflowManualStep(title: "Prepare the data file", body:
                "CSV column names or JSON object keys are variable names. Every row must have the same fields. JSON values must be strings, numbers, or booleans. CSV supports quoted commas and newlines. Limits are 1 MB and 1000 rows.", example: "username,password,product\ndemo-a,test-a,book\ndemo-b,test-b,pen\n\n[{\"username\":\"demo-a\",\"password\":\"test-a\",\"product\":\"book\"}]"),
            WorkflowManualStep(title: "Import and review the rows", body:
                "Open Run Requests, choose your saved workflow, and click Import CSV or JSON under Test Data. Check Data Rows and the column names. Values are hidden in the panel. Review the source file before running.", screenshot: "data"),
            WorkflowManualStep(title: "Run all rows", body:
                "Click Run Selected Requests. Row values replace environment variables during that row, and response extractions are available to its later requests. Each new row starts from the original environment. Result numbers identify the data row. Stop on first failure stops the remaining rows too.", screenshot: "results"),
            WorkflowManualStep(title: "Return to a normal run", body:
                "Click Clear Test Data before running without data rows. Data files are not embedded in saved workflows or exported project folders. Choose the input file again when reopening the panel.")
        ]),
        WorkflowManualArticle(title: "Project Files", overview:
            "Share HTTP projects through readable JSON files and review their changes with Git. This is an explicit export and import, not a live filesystem sync.", steps: [
            WorkflowManualStep(title: "Export the project folder", body:
                "Open HTTP Workflows → Project Files and click Export Project Folder. Choose a new destination folder. The export contains reqeast.json, requests/<request-id>.json, and .gitignore. Saved workflows and environments are in reqeast.json.", screenshot: "files"),
            WorkflowManualStep(title: "Review before committing", body:
                "Secret variables are exported empty. Inline authentication credentials and recognized sensitive fields become variable references. Review URLs, headers, and bodies for other private data. Attached files and non-HTTP requests are not exported. Fill required secrets locally after importing."),
            WorkflowManualStep(title: "Track changes with Git", body:
                "Add the exported folder to your repository and review the JSON diff. Request filenames and keys remain stable. Export later edits to another folder, compare the files, and replace the tracked copies you intend to update.", example: "git add api-project\ngit diff --cached\ngit commit -m 'Update API workflow'"),
            WorkflowManualStep(title: "Import a project folder", body:
                "Click Import Project Folder and choose a folder containing reqeast.json. A new project is created, with new internal IDs and restored workflow references. Existing projects are kept. Select the imported project in the sidebar and set its secret values before sending.")
        ]),
        WorkflowManualArticle(title: "Command Line", overview:
            "reqeast-cli runs exported HTTP workflows using the Rust networking core. It supports none, Bearer, Basic, and API Key authentication with JSON, raw, URL-encoded, and text multipart bodies. Attached files and signed authentication require the app.", steps: [
            WorkflowManualStep(title: "Build the command-line tool", body:
                "Install the stable Rust toolchain, open a terminal at the RHEQ repository root, and build the release executable. The executable is rust/target/release/reqeast-cli. You can copy it into your preferred tools directory.", example: "cargo build --manifest-path rust/Cargo.toml --bin reqeast-cli --release\nrust/target/release/reqeast-cli --help"),
            WorkflowManualStep(title: "Export and choose a workflow", body:
                "Save Order test in the app and export its project folder. Workflow and environment names must match exactly. Use --environment to choose an environment explicitly; otherwise the saved environment or first exported environment is used.", screenshot: "files", example: "reqeast-cli run ./api-project --workflow 'Order test' --environment 'Test'"),
            WorkflowManualStep(title: "Provide local secrets and data", body:
                "Set secret values with REQEAST_VAR_name environment variables, or pass a local JSON object with --secrets. Environment variables override the secret file. Add --data cases.csv or cases.json for row-based tests. Data-row values override environment values for that row.", example: "export REQEAST_VAR_password='your-test-password'\nreqeast-cli run ./api-project --workflow 'Order test' --data cases.csv --report run-report.json"),
            WorkflowManualStep(title: "Use the result in CI", body:
                "Exit code 0 means every executed request and check passed. Code 1 means a request, extraction, or check failed. Code 2 means invalid input or configuration. --report writes JSON results without response bodies or variable values. Use your CI secret store for credentials and collect the report as an artifact.")
        ]),
        WorkflowManualArticle(title: "Compare Responses", overview:
            "JSON tools support responses up to 1 MB. This comparison checks JSON fields and HTTP status; it does not compare response headers or timing.", steps: [
            WorkflowManualStep(title: "Save a known response", body:
                "Send a request and open Compare Responses. Tap Save Current Response as Baseline. This JSON response stays on this device, including after restarting the app.", screenshot: "comparison"),
            WorkflowManualStep(title: "Send again and compare", body:
                "Close the workflow panel, change the request or environment, and send again. Reopen Compare Responses and tap Compare with Baseline. Red shows the old value; green shows the new value."),
            WorkflowManualStep(title: "Ignore changing fields", body:
                "Enter /timestamp, /requestId in Ignored paths to skip values that change every time. A path also skips nested fields. Arrays are compared by position. Replace the baseline only when you want a new reference.")
        ])
    ]
}
