import SwiftUI

@main
struct FofacApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @StateObject private var store = Store()
    @StateObject private var app = AppState()
    @AppStorage("scheme") private var scheme = 0
    @AppStorage("accent") private var accent = 0

    private var accentColor: Color {
        let all: [Color] = [.blue, Color(red: 0.88, green: 0.27, blue: 0.48), .green, .purple]
        return all[min(max(accent, 0), all.count - 1)]
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Group {
                switch app.tab {
                case 0: GameHome()
                case 2: TensesView()
                case 3: Match3Screen()
                default: CardsView()
                }
            }

            // Узкая полоса у левого края: свайп вправо открывает панель
            if app.tensePath.isEmpty && !app.drawer {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: 22)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10).onChanged { v in
                                if v.translation.width > 28 && !app.drawer { app.open() }
                            }
                        )
                    Spacer(minLength: 0).allowsHitTesting(false)
                }
            }

            if app.drawer {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { app.close() }
                    .gesture(DragGesture().onEnded { v in if v.translation.width < -50 { app.close() } })
                    .transition(.opacity)
                DrawerView()
                    .transition(.move(edge: .leading))
                    .gesture(DragGesture().onEnded { v in if v.translation.width < -50 { app.close() } })
            }
        }
        .environmentObject(store)
        .environmentObject(app)
        .preferredColorScheme(scheme == 1 ? .light : (scheme == 2 ? .dark : nil))
        .accentColor(accentColor)
        .sheet(isPresented: $app.settings) { SettingsView() }
    }
}
