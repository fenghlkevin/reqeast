import SwiftUI

struct WorkflowRequestOrderGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Which request is first?", systemImage: "list.number").font(.headline)
            Text("Create separate HTTP requests in the same project: login, create an order, and query the order. Configure token extraction on login, use {{token}} and extract orderId on create order, then use {{orderId}} in the query URL. Use the same environment for all three. These URLs and response fields are examples; use your API's actual values.")
            WorkflowExamplePanel(title: "Execution Order", icon: "arrow.down", lines: [
                "1  POST /login          → token", "↓",
                "2  POST /orders         → orderId", "↓",
                "3  GET /orders/{{orderId}}"
            ])
            Text("For manual sending, select login in the sidebar and tap Send first. After it succeeds and saves token, select create order and tap Send second. For batch sending, open Run Requests, select these requests, and use the up and down arrows to arrange them. The first checked row is request 1, the next checked row is request 2. Unchecked rows are skipped. The numbers beside the rows show the actual execution order.")
            Text("The numbered cards below are guide steps, not request numbers. Selecting a request in the sidebar does not make it run first. Check the batch list order each time you open the workflow panel.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .textSelection(.enabled)
    }
}
