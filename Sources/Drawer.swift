import SwiftUI

struct DrawerButton: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        Button { app.open() } label: { Image(systemName: "line.3.horizontal") }
    }
}

struct DrawerView: View {
    @EnvironmentObject var app: AppState
    @State private var openTenses = false
    @State private var openGroup: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image("Logo")
                    .resizable()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("fofac").font(.system(size: 24, weight: .bold, design: .serif))
            }
            .padding(.bottom, 14)

            item("Карточки", "rectangle.stack", tab: 1)
            item("Игра", "gamecontroller", tab: 0)
            item("Космос", "moon.stars.fill", tab: 3)

            Button { withAnimation { openTenses.toggle() } } label: {
                row("Времена", "clock", active: app.tab == 2, chevron: openTenses ? "chevron.down" : "chevron.right")
            }
            .buttonStyle(.plain)

            if openTenses {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(DB.data.tenses) { g in
                            Button { withAnimation { openGroup = (openGroup == g.g) ? nil : g.g } } label: {
                                HStack {
                                    Text(g.g).font(.subheadline.weight(.semibold))
                                    Text(g.sub).font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: openGroup == g.g ? "chevron.down" : "chevron.right")
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if openGroup == g.g {
                                ForEach(g.items) { t in
                                    Button {
                                        app.tab = 2
                                        app.tensePath = [t]
                                        app.close()
                                    } label: {
                                        Text(t.n).font(.subheadline)
                                            .padding(.leading, 26)
                                            .padding(.vertical, 7)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 340)
            }

            Spacer()
            Button { app.close(); app.settings = true } label: {
                row("Настройки", "gearshape", active: false, chevron: nil)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 60)
        .padding(.bottom, 24)
        .frame(width: 290, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1) }
    }

    private func row(_ title: String, _ icon: String, active: Bool, chevron: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 26)
            Text(title).font(.body.weight(.semibold))
            Spacer()
            if let c = chevron {
                Image(systemName: c).font(.footnote).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .foregroundColor(active ? .accentColor : .primary)
        .background(active ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
    }

    private func item(_ title: String, _ icon: String, tab: Int) -> some View {
        Button { app.tab = tab; app.close() } label: {
            row(title, icon, active: app.tab == tab, chevron: nil)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("scheme") private var scheme = 0
    @AppStorage("accent") private var accent = 0
    @AppStorage("voiceOn") private var voiceOn = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Оформление") {
                    Picker("Тема", selection: $scheme) {
                        Text("Как в системе").tag(0)
                        Text("Светлая").tag(1)
                        Text("Тёмная").tag(2)
                    }
                    Picker("Цвет", selection: $accent) {
                        Text("Синий").tag(0)
                        Text("Розовый").tag(1)
                        Text("Зелёный").tag(2)
                        Text("Фиолетовый").tag(3)
                    }
                }
                Section("Звук") {
                    Toggle("Американская озвучка", isOn: $voiceOn)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
        }
    }
}
