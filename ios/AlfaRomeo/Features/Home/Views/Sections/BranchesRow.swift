import SwiftUI

/// «На карте» (§9.1): an entry row to branches / ATMs on a map. Opens the branches stub
/// (``HomeRoute.branches``). Hidden on the dashboard in the demo (see HomeView).
struct BranchesRow: View {
    var onTap: () -> Void

    var body: some View {
        GroupedSection {
            Button(action: onTap) {
                ListRow(icon: "map", title: "На карте",
                        subtitle: "Отделения и банкоматы рядом", showsChevron: true)
            }
            .buttonStyle(.row)
        }
        .accessibilityLabel("На карте: отделения и банкоматы")
    }
}
