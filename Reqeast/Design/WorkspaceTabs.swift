// RHEQ: compact document-style navigation for request and response panels.
import SwiftUI

struct WorkspaceTabs<Selection: Hashable>: View {
    let items: [(value: Selection, title: String)]
    @Binding var selection: Selection

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    Button { selection = item.value } label: {
                        Text(verbatim: item.title)
                            .font(.subheadline.weight(selection == item.value ? .semibold : .regular))
                            .foregroundStyle(selection == item.value ? .primary : .secondary)
                            .padding(.vertical, 10)
                            .contentShape(.rect)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(BrandTheme.action)
                                    .frame(height: 2).opacity(selection == item.value ? 1 : 0)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == item.value ? .isSelected : [])
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
