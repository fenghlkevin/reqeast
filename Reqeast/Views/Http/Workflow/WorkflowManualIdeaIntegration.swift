import Foundation

extension WorkflowManualContent {
    static let ideaIntegration: [WorkflowManualArticle] = [
        WorkflowManualArticle(title: "IDEA Controller Import", overview:
            "Import Java Spring Controller interfaces from IDEA without starting the backend. The plugin reads declarations and DTO fields, then opens a local export in RHEQ for review. It never sends API requests.", steps: [
            WorkflowManualStep(title: "Install the IDEA plugin", body:
                "In RHEQ Settings, open IDEA Integration and click Export IDEA Plugin. In IDEA Settings → Plugins, use the gear menu → Install Plugin from Disk. Select the ZIP and restart IDEA. The package supports IDEA 2026.2 on macOS with the Java plugin enabled.", screenshot: "idea-install"),
            WorkflowManualStep(title: "Choose what to import", body:
                "Wait for IDEA indexing to finish. Right-click inside a Java Controller method and choose RHEQ → Import Method into RHEQ. Use Import Controller into RHEQ for the current class, or select a module in the Project tree and choose Import Module into RHEQ.", example: "Method → one mapped method\nController → mapped methods in the class\nModule → Java Controllers in the selected module"),
            WorkflowManualStep(title: "Import using the method icon", body:
                "After IDEA indexing finishes, a RHEQ icon appears in the left gutter beside each supported Controller method. Hover over it to see Import this interface into RHEQ, then click the icon. Only that method is exported, regardless of the caret position. Enter the base URL and continue to the RHEQ preview. If the icon is hidden, open IDEA Settings → Editor → General → Gutter Icons and enable RHEQ Interface Import.", screenshot: "idea-gutter"),
            WorkflowManualStep(title: "Enter the API base URL", body:
                "Enter the server address, port, and application context path. This address is independent of the Java package and module name. Review the interface count and warnings, then click Open in RHEQ.", example: "http://localhost:8080/api\nController: /orders\nMethod: /{id}\nResult: http://localhost:8080/api/orders/{{id}}"),
            WorkflowManualStep(title: "Review and confirm the import", body:
                "In the RHEQ preview, choose New Project or an existing local project. Check the base URL, request list, and warnings. Uncheck interfaces you do not need. The + count means new requests; ↻ means matching requests will change. Click Import only after reviewing.", screenshot: "idea-import"),
            WorkflowManualStep(title: "Prepare and send the first request", body:
                "Select an imported request. Replace path variables such as {{id}} with test values, or define them in the active environment. Check query parameters, headers, and the generated body. DTO examples are placeholders. Configure authentication, start your backend, and click Send when ready."),
            WorkflowManualStep(title: "Refresh after changing code", body:
                "Run the same IDEA action again and select the same RHEQ project. Matching interfaces keep request IDs, authentication, test parameter values, and workflow references. Locally edited URLs and bodies are retained. Missing interfaces are not deleted. Renaming a class or method, changing its parameter signature, or moving the project may create new requests; review old requests manually."),
            WorkflowManualStep(title: "Check unsupported mappings", body:
                "This integration supports Java and common Spring web annotations. Kotlin, custom annotation aliases, wildcard or regex paths, and runtime path expressions need manual configuration. Inherited parameter annotations and mapping conditions require review. DTO nesting is limited to 8 levels and 100 fields per type; exports are limited to 2000 interfaces and 5 MB. If no preview opens, check that RHEQ is installed in /Applications and inspect the error in IDEA.")
        ], section: "IDEA Integration")
    ]
}
