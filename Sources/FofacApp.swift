import SwiftUI

@main
struct FofacApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @StateObject private var store = Store()
    var body: some View {
        TabView {
            GameHome().tabItem { Label("Игра", systemImage: "gamecontroller") }
            CardsView().tabItem { Label("Карточки", systemImage: "rectangle.stack") }
            TensesView().tabItem { Label("Времена", systemImage: "clock") }
        }
        .environmentObject(store)
    }
}
