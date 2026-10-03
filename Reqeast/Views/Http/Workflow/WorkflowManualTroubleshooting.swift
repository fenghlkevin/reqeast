import Foundation

extension WorkflowManualContent {
    static let troubleshooting: [WorkflowManualArticle] = [
        WorkflowManualArticle(title: "Diagnosing Failed Requests", overview: "", steps: [
            WorkflowManualStep(title: "Request Preview", body: "Start with the prepared URL, active environment, and missing variables. For 401 or 403, check credentials and permissions; for 400 or 415, check body shape and Content-Type. For connection or TLS errors, check host, port, protocol, and the certificate. Read the complete error before changing settings.", screenshot: "preview"),
            WorkflowManualStep(title: "Run Requests", body: "Run a failing workflow request individually first, then check its position, extraction path, and expected response. Data rows are isolated, so a previous row cannot supply the next row’s variables. Before resetting app data, export a backup and record the failing request’s error."),
        ], section: "Troubleshooting"),
    ]
}
