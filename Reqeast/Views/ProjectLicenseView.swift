// RHEQ: retain readable upstream license and attribution in the distributed app.
import SwiftUI

struct ProjectLicenseView: View {
    private var license: String {
        guard let url = Bundle.main.url(forResource: "Upstream-LICENSE", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "Apache License 2.0" }
        return text
    }

    var body: some View {
        ScrollView {
            Text(verbatim: license).font(.system(.caption, design: .monospaced))
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding()
        }.navigationTitle("Project License")
    }
}
