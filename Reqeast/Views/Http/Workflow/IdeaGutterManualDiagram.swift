import SwiftUI

/// Documentation illustration of the plugin's method marker; never a desktop screenshot.
struct IdeaGutterManualDiagram: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Import this interface into RHEQ").font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                codeLine(41, text: "@PostMapping(\"/orders\")", marker: false)
                codeLine(42, text: "public Order create(@RequestBody OrderInput input) {", marker: true)
                codeLine(43, text: "    return service.create(input);", marker: false)
                codeLine(44, text: "}", marker: false)
            }.padding(18).background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 12))
            Text("Click the RHEQ icon beside the method to import only that interface.")
                .font(.callout).foregroundStyle(.secondary)
        }.padding(24).frame(width: 850, alignment: .leading).background(.white)
    }

    private func codeLine(_ number: Int, text: String, marker: Bool) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: String(number)).foregroundStyle(.secondary).frame(width: 26)
            Group {
                if marker { RheqLogoShape().fill(Color(red: 0.09, green: 0.09, blue: 0.1)).padding(2).background(.white, in: .rect(cornerRadius: 3)) }
                else { Color.clear }
            }.frame(width: 22, height: 22)
            Text(verbatim: text).foregroundStyle(.primary)
        }.font(.system(size: 15, design: .monospaced))
    }
}
