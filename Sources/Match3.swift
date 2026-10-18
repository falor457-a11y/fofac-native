import SwiftUI

struct Tile: Identifiable {
    let id = UUID()
    var color: Int
    var r: Int
    var c: Int
}

final class Match3VM: ObservableObject {
    let n = 7
    let kinds = 5
    @Published var tiles: [Tile] = []
    @Published var score = 0
    @Published var best = 0
    @Published var selected: UUID? = nil
    @Published var message = ""
    private var busy = false
    let store: Store

    init(store: Store) {
        self.store = store
        best = UserDefaults.standard.integer(forKey: "fofac.m3best")
        newBoard()
    }

    // MARK: поле

    func grid() -> [[Tile?]] {
        var g = Array(repeating: Array<Tile?>(repeating: nil, count: n), count: n)
        for t in tiles where t.r >= 0 && t.r < n && t.c >= 0 && t.c < n { g[t.r][t.c] = t }
        return g
    }

    func newBoard() {
        for _ in 0..<20 {
            var cols = Array(repeating: Array(repeating: 0, count: n), count: n)
            for r in 0..<n {
                for c in 0..<n {
                    var opts = Array(0..<kinds)
                    if c >= 2 && cols[r][c - 1] == cols[r][c - 2] { opts.removeAll { $0 == cols[r][c - 1] } }
                    if r >= 2 && cols[r - 1][c] == cols[r - 2][c] { opts.removeAll { $0 == cols[r - 1][c] } }
                    cols[r][c] = opts.randomElement() ?? 0
                }
            }
            var t: [Tile] = []
            for r in 0..<n {
                for c in 0..<n { t.append(Tile(color: cols[r][c], r: r, c: c)) }
            }
            tiles = t
            if hasMove() { return }
        }
    }

    func findMatches(_ g: [[Tile?]]) -> Set<UUID> {
        var out = Set<UUID>()
        for r in 0..<n {
            var c = 0
            while c < n {
                guard let t = g[r][c] else { c += 1; continue }
                var e = c
                while e + 1 < n, let u = g[r][e + 1], u.color == t.color { e += 1 }
                if e - c >= 2 {
                    for k in c...e { if let x = g[r][k] { out.insert(x.id) } }
                }
                c = e + 1
            }
        }
        for c in 0..<n {
            var r = 0
            while r < n {
                guard let t = g[r][c] else { r += 1; continue }
                var e = r
                while e + 1 < n, let u = g[e + 1][c], u.color == t.color { e += 1 }
                if e - r >= 2 {
                    for k in r...e { if let x = g[k][c] { out.insert(x.id) } }
                }
                r = e + 1
            }
        }
        return out
    }

    private func run3(_ m: [[Int]]) -> Bool {
        for r in 0..<n {
            for c in 0..<n {
                let v = m[r][c]
                if v < 0 { continue }
                if c + 2 < n && m[r][c + 1] == v && m[r][c + 2] == v { return true }
                if r + 2 < n && m[r + 1][c] == v && m[r + 2][c] == v { return true }
            }
        }
        return false
    }

    func hasMove() -> Bool {
        var m = grid().map { row in row.map { $0?.color ?? -1 } }
        for r in 0..<n {
            for c in 0..<n {
                if c + 1 < n {
                    let t = m[r][c]; m[r][c] = m[r][c + 1]; m[r][c + 1] = t
                    let ok = run3(m)
                    let u = m[r][c]; m[r][c] = m[r][c + 1]; m[r][c + 1] = u
                    if ok { return true }
                }
                if r + 1 < n {
                    let t = m[r][c]; m[r][c] = m[r + 1][c]; m[r + 1][c] = t
                    let ok = run3(m)
                    let u = m[r][c]; m[r][c] = m[r + 1][c]; m[r + 1][c] = u
                    if ok { return true }
                }
            }
        }
        return false
    }

    // MARK: управление

    func tap(_ id: UUID) {
        if busy { return }
        if store.moves <= 0 {
            message = "Ходов нет. Выучи карточки, и они появятся."
            return
        }
        message = ""
        guard let cur = selected else { selected = id; return }
        if cur == id { selected = nil; return }
        guard let a = tiles.first(where: { $0.id == cur }), let b = tiles.first(where: { $0.id == id }) else { return }
        if abs(a.r - b.r) + abs(a.c - b.c) == 1 { attempt(cur, id) } else { selected = id }
    }

    func swipe(_ id: UUID, _ d: CGSize) {
        if busy { return }
        guard let a = tiles.first(where: { $0.id == id }) else { return }
        var dr = 0
        var dc = 0
        if abs(d.width) > abs(d.height) { dc = d.width > 0 ? 1 : -1 } else { dr = d.height > 0 ? 1 : -1 }
        guard let b = tiles.first(where: { $0.r == a.r + dr && $0.c == a.c + dc }) else { return }
        if store.moves <= 0 {
            message = "Ходов нет. Выучи карточки, и они появятся."
            return
        }
        message = ""
        attempt(id, b.id)
    }

    private func swapPos(_ i: Int, _ j: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            let r = tiles[i].r
            let c = tiles[i].c
            tiles[i].r = tiles[j].r
            tiles[i].c = tiles[j].c
            tiles[j].r = r
            tiles[j].c = c
        }
    }

    private func attempt(_ a: UUID, _ b: UUID) {
        guard let i = tiles.firstIndex(where: { $0.id == a }), let j = tiles.firstIndex(where: { $0.id == b }) else { return }
        busy = true
        selected = nil
        swapPos(i, j)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if self.findMatches(self.grid()).isEmpty {
                self.swapPos(i, j)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { self.busy = false }
            } else {
                self.store.useMove()
                self.resolve(combo: 1)
            }
        }
    }

    private func resolve(combo: Int) {
        let m = findMatches(grid())
        if m.isEmpty {
            busy = false
            if score > best {
                best = score
                UserDefaults.standard.set(best, forKey: "fofac.m3best")
            }
            if !hasMove() {
                message = "Ходов на поле не осталось, перемешали"
                withAnimation(.easeInOut(duration: 0.3)) { newBoard() }
            }
            return
        }
        score += m.count * 10 * combo
        withAnimation(.easeIn(duration: 0.2)) { tiles.removeAll { m.contains($0.id) } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.gravity()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { self.resolve(combo: combo + 1) }
        }
    }

    private func gravity() {
        var t = tiles
        var spawn: [Tile] = []
        var finals: [UUID: Int] = [:]
        for c in 0..<n {
            let idxs = t.indices.filter { t[$0].c == c }.sorted { t[$0].r > t[$1].r }
            var target = n - 1
            for i in idxs {
                t[i].r = target
                target -= 1
            }
            while target >= 0 {
                let nt = Tile(color: Int.random(in: 0..<kinds), r: target - n, c: c)
                finals[nt.id] = target
                spawn.append(nt)
                target -= 1
            }
        }
        let start = tiles + spawn
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) { tiles = start }
        var landed = t
        for var s in spawn {
            s.r = finals[s.id] ?? s.r
            landed.append(s)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            withAnimation(.easeIn(duration: 0.3)) { self.tiles = landed }
        }
    }
}

struct TileView: View {
    let kind: Int
    let selected: Bool
    static let colors: [Color] = [.pink, .orange, .teal, .green, .purple]
    static let symbols: [String] = ["heart.fill", "star.fill", "drop.fill", "leaf.fill", "bolt.fill"]

    var body: some View {
        let c = TileView.colors[kind % TileView.colors.count]
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [c.opacity(0.95), c.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: TileView.symbols[kind % TileView.symbols.count])
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.92))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? Color.white : Color.clear, lineWidth: 3)
        )
        .scaleEffect(selected ? 1.08 : 1)
    }
}

struct Match3Board: View {
    @ObservedObject var store: Store
    @StateObject private var vm: Match3VM

    init(store: Store) {
        _store = ObservedObject(wrappedValue: store)
        _vm = StateObject(wrappedValue: Match3VM(store: store))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                stat("Очки", vm.score)
                Spacer()
                stat("Ходов", store.moves)
                Spacer()
                stat("Рекорд", vm.best)
            }
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let cell = size / CGFloat(vm.n)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemBackground))
                    ForEach(vm.tiles) { t in
                        TileView(kind: t.color, selected: vm.selected == t.id)
                            .frame(width: cell - 5, height: cell - 5)
                            .position(x: (CGFloat(t.c) + 0.5) * cell, y: (CGFloat(t.r) + 0.5) * cell)
                            .onTapGesture { vm.tap(t.id) }
                            .gesture(DragGesture(minimumDistance: 12).onEnded { v in vm.swipe(t.id, v.translation) })
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .aspectRatio(1, contentMode: .fit)
            Text(vm.message.isEmpty ? (store.moves > 0 ? "Нажми на плитку и на соседнюю или смахни её. Три в ряд сгорают." : "Ходов нет. Проходи карточки, за каждый ответ дают ход.") : vm.message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding()
    }

    private func stat(_ t: String, _ v: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(v)").font(.system(size: 24, weight: .bold, design: .serif)).foregroundColor(.accentColor)
            Text(t).font(.caption).foregroundColor(.secondary)
        }
    }
}

/// Раздел из боковой панели
struct Match3Screen: View {
    @EnvironmentObject var store: Store
    var body: some View {
        NavigationStack {
            Match3Board(store: store)
                .navigationTitle("Три в ряд")
                .toolbar { ToolbarItem(placement: .navigationBarLeading) { DrawerButton() } }
        }
    }
}

/// Открывается после повторения карточек
struct Match3Cover: View {
    let store: Store
    let onClose: () -> Void
    var body: some View {
        NavigationStack {
            Match3Board(store: store)
                .navigationTitle("Три в ряд")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Готово") { onClose() } } }
        }
    }
}
