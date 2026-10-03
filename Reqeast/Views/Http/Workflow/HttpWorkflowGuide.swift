// Modified for RHEQ: visual workflows and HTTP diagnostics.
import SwiftUI

struct HttpWorkflowGuide: View {
    let initialTopic: Int
    @Environment(\.dismiss) private var dismiss
    @State private var chapter = 0
    @State private var search = ""
    private let articles = WorkflowManualContent.articles
    private var matching: [Int] {
        articles.indices.filter { index in
            let article = articles[index]
            let text = ([article.title, article.overview, article.section]
                + article.steps.flatMap { [$0.title, $0.body] }).map(localized).joined(separator: " ")
                + article.steps.compactMap(\.example).joined(separator: " ")
            return search.isEmpty || text.localizedCaseInsensitiveContains(search)
        }
    }
    private var sections: [String] {
        articles.reduce(into: []) { if !$0.contains($1.section) { $0.append($1.section) } }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("User Manual", systemImage: "book.closed").font(.title2.bold())
                Spacer()
            }.padding()
            Divider()
            HStack {
                TextField("Search Chapters", text: $search).devTextInput()
                Picker("Chapter", selection: $chapter) {
                    ForEach(sections, id: \.self) { section in
                        Section {
                            ForEach(matching.filter { articles[$0].section == section }, id: \.self) { index in
                                Text(verbatim: localized(articles[index].title)).tag(index)
                            }
                        } header: { Text(verbatim: localized(section)) }
                    }
                }.tint(.primary).accessibilityIdentifier("manual-chapter-picker")
            }.padding()
            Group {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        let article = articles[chapter]
                        Text(verbatim: localized(article.section)).font(.caption).foregroundStyle(.secondary)
                        Text(verbatim: localized(article.title)).font(.largeTitle.bold())
                        if !article.overview.isEmpty {
                            Text(verbatim: localized(article.overview)).font(.body).textSelection(.enabled)
                        }
                        ForEach(article.steps.indices, id: \.self) { index in
                            let step = article.steps[index]
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    Text(verbatim: String(index + 1)).font(.headline.monospacedDigit())
                                        .frame(width: 30, height: 30).glassEffect()
                                    Text(verbatim: localized(step.title)).font(.title3.bold())
                                }
                                Text(verbatim: localized(step.body)).textSelection(.enabled)
                                if let example = step.example {
                                    Text(verbatim: example).font(.callout.monospaced()).textSelection(.enabled)
                                        .padding().frame(maxWidth: .infinity, alignment: .leading).glassEffect()
                                }
                                if let screenshot = step.screenshot { WorkflowManualImage(name: screenshot) }
                            }
                            Divider()
                        }
                    }.padding(24).frame(maxWidth: 1000, alignment: .leading)
                }.id(chapter)
            }
            Divider()
            HStack {
                Button("Close") { dismiss() }.buttonStyle(.glass).keyboardShortcut(.cancelAction)
                Spacer()
                if chapter > 0 { Button("Previous Chapter") { search = ""; chapter -= 1 }.buttonStyle(.glass) }
                if chapter < articles.count - 1 { Button("Next Chapter") { search = ""; chapter += 1 }.buttonStyle(.glass) }
            }.padding()
        }
        #if os(macOS)
        .frame(width: 1000, height: 850)
        #endif
        .onAppear { chapter = WorkflowManualContent.initialChapter(for: initialTopic) }
        .onChange(of: search) { if !matching.contains(chapter), let first = matching.first { chapter = first } }
    }

    private func localized(_ key: String) -> String { String(localized: String.LocalizationValue(key)) }
}

struct WorkflowManualImage: View {
    let name: String
    @State private var enlarged = false
    private var asset: String {
        let locale = Locale.preferredLanguages.first ?? "en"
        let language = locale.hasPrefix("zh-Hant") ? "zh-Hant" : locale.hasPrefix("zh") ? "zh-Hans" :
            locale.hasPrefix("pt") ? "pt-BR" : String(locale.prefix(2))
        let supported = ["en", "zh-Hans", "zh-Hant", "ja", "fr", "pt-BR", "es", "ko", "de"]
        return "manual-\(supported.contains(language) ? language : "en")-\(name)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { enlarged = true } label: {
                Image(asset).resizable().scaledToFit().clipShape(.rect(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityLabel(Text("Enlarge Screenshot"))
            Text(name == "idea-gutter" ? String(localized: "Illustration of the method import icon. Click to enlarge.") : name.hasPrefix("idea-") ? String(localized: "Rendered app view with fictional data. Click to enlarge.") : String(localized: "Actual app screenshot with fictional demo data. Click to enlarge.")).font(.caption).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $enlarged) {
            VStack {
                ScrollView([.horizontal, .vertical]) { Image(asset) }
                Button("Close") { enlarged = false }.buttonStyle(.glass).keyboardShortcut(.cancelAction)
            }.padding()
            #if os(macOS)
            .frame(width: 1100, height: 850)
            #endif
        }
    }
}
