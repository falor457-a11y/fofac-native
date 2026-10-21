import SwiftUI
import UIKit

struct Rock: Identifiable {
    let id = UUID()
    let cardId: String
    let text: String
    let seed: Int
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var age: Double = 0
    var mark: Int = 0   // 0 обычный, 1 верный (выстрел летит), 2 неверный
}

struct Bullet: Identifiable {
    let id = UUID()
    let target: UUID
    var p: Double = 0
}

struct Fx: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let text: String
    let ghost: String
    let good: Bool
    var age: Double = 0
}

final class SpaceVM: ObservableObject {
    @Published var rocks: [Rock] = []
    @Published var bullets: [Bullet] = []
    @Published var fxs: [Fx] = []
    @Published var prompt = ""
    @Published var level = 1
    @Published var points = 0
    @Published var target = 50
    @Published var timeLeft = 60.0
    @Published var streak = 0
    @Published var phase = 0          // 0 «Уровень N», 1 «Цель», 2 игра, 4 время вышло
    @Published var aim: CGPoint? = nil
    @Published var bestLevel = 0
    private var phaseT = 0.0
    private var speed = 1.0
    private var targetCard = ""
    private var lastRemoved = ""
    private var pairs: [String: (rock: String, prompt: String)] = [:]
    let store: Store

    var cardCount: Int { store.cards.count }

    init(store: Store) {
        self.store = store
        bestLevel = UserDefaults.standard.integer(forKey: "fofac.spacebest")
        load()
        begin(level: 1)
    }

    private func load() {
        pairs = [:]
        for c in store.cards {
            let fl = hasLatin(c.f)
            let bl = hasLatin(c.b)
            if bl && !fl {
                pairs[c.id] = (c.b, c.f)
            } else {
                pairs[c.id] = (c.f, c.b)
            }
        }
    }

    func begin(level n: Int) {
        level = n
        speed = pow(1.15, Double(n - 1))
        phase = 0
        phaseT = 0
        points = 0
        streak = 0
        timeLeft = 60
        rocks = []
        bullets = []
        fxs = []
        aim = nil
    }

    func restart() {
        load()
        begin(level: 1)
    }

    private func startPlaying() {
        phase = 2
        let ids = Array(pairs.keys.shuffled().prefix(4))
        let slots = [0.2, 0.4, 0.6, 0.8].shuffled()
        var rs: [Rock] = []
        for (k, id) in ids.enumerated() {
            var r = makeRock(id, fresh: false)
            r.x = slots[k % slots.count]
            r.age = 1
            rs.append(r)
        }
        rocks = rs
        if let t = ids.randomElement() {
            targetCard = t
            prompt = pairs[t]?.prompt ?? ""
        }
    }

    private func makeRock(_ id: String, fresh: Bool) -> Rock {
        let text = pairs[id]?.rock ?? ""
        return Rock(cardId: id, text: text, seed: Int.random(in: 0..<1000),
                    x: Double.random(in: 0.18...0.82),
                    y: fresh ? Double.random(in: 0.14...0.30) : Double.random(in: 0.14...0.5),
                    vx: Double.random(in: -0.02...0.02),
                    vy: Double.random(in: 0.016...0.034))
    }

    func step(dt: Double) {
        switch phase {
        case 0:
            phaseT += dt
            if phaseT > 1.8 { phase = 1; phaseT = 0 }
        case 1:
            phaseT += dt
            if phaseT > 1.5 { startPlaying() }
        case 2:
            play(dt)
        default:
            break
        }
        if !fxs.isEmpty {
            var f = fxs
            for i in f.indices { f[i].age += dt }
            fxs = f.filter { $0.age < 0.9 }
        }
    }

    private func play(_ dt: Double) {
        timeLeft -= dt
        if timeLeft <= 0 {
            timeLeft = 0
            endGame()
            return
        }
        var rs = rocks
        var missed: [UUID] = []
        for i in rs.indices {
            rs[i].age += dt
            rs[i].x += rs[i].vx * dt * speed
            rs[i].y += rs[i].vy * dt * speed
            if rs[i].x < 0.14 { rs[i].x = 0.14; rs[i].vx = abs(rs[i].vx) }
            if rs[i].x > 0.86 { rs[i].x = 0.86; rs[i].vx = -abs(rs[i].vx) }
            if rs[i].y > 0.80 && rs[i].mark == 0 { missed.append(rs[i].id) }
        }
        rocks = rs
        var bs = bullets
        for i in bs.indices { bs[i].p += dt / 0.28 }
        let done = bs.filter { $0.p >= 1 }
        bullets = bs.filter { $0.p < 1 }
        for b in done { resolve(b) }
        for id in missed { miss(id) }
    }

    func tap(_ id: UUID) {
        if phase != 2 { return }
        guard let i = rocks.firstIndex(where: { $0.id == id }), rocks[i].mark == 0 else { return }
        rocks[i].mark = (rocks[i].cardId == targetCard) ? 1 : 2
        bullets.append(Bullet(target: id))
        aim = CGPoint(x: rocks[i].x, y: rocks[i].y)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func addFx(_ r: Rock, _ text: String, good: Bool) {
        fxs.append(Fx(x: r.x, y: r.y, text: text, ghost: r.text, good: good))
    }

    private func nextTarget() {
        let ready = rocks.filter { $0.mark == 0 && $0.age >= 0.6 }
        let pool = ready.isEmpty ? rocks.filter { $0.mark == 0 } : ready
        if let r = pool.randomElement() {
            targetCard = r.cardId
            prompt = pairs[r.cardId]?.prompt ?? ""
        }
    }

    private func spawnReplacement() {
        let used = Set(rocks.map { $0.cardId })
        var free = pairs.keys.filter { !used.contains($0) }
        let other = free.filter { $0 != lastRemoved }
        if !other.isEmpty { free = other }
        if let id = free.randomElement() { rocks.append(makeRock(id, fresh: true)) }
    }

    private func resolve(_ b: Bullet) {
        guard let i = rocks.firstIndex(where: { $0.id == b.target }) else { return }
        let r = rocks[i]
        lastRemoved = r.cardId
        if r.mark == 1 {
            let mult = 1.0 + 0.2 * Double(min(streak, 10))
            let gain = Int((5.0 * mult).rounded())
            points += gain
            streak += 1
            addFx(r, "+\(gain)", good: true)
            rocks.remove(at: i)
            nextTarget()
            spawnReplacement()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let voiceOn = (UserDefaults.standard.object(forKey: "voiceOn") as? Bool) ?? true
            if voiceOn { Speaker.shared.say(r.text) }
            if points >= target {
                if level > bestLevel {
                    bestLevel = level
                    UserDefaults.standard.set(bestLevel, forKey: "fofac.spacebest")
                }
                begin(level: level + 1)
            }
        } else {
            points = max(0, points - 2)
            streak = 0
            addFx(r, "−2", good: false)
            rocks.remove(at: i)
            spawnReplacement()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func miss(_ id: UUID) {
        guard let i = rocks.firstIndex(where: { $0.id == id }) else { return }
        let r = rocks[i]
        lastRemoved = r.cardId
        if r.cardId == targetCard {
            points = max(0, points - 2)
            streak = 0
            addFx(r, "−2", good: false)
            rocks.remove(at: i)
            nextTarget()
            spawnReplacement()
        } else {
            rocks.remove(at: i)
            spawnReplacement()
        }
    }

    private func endGame() {
        phase = 4
        if level > bestLevel {
            bestLevel = level
            UserDefaults.standard.set(bestLevel, forKey: "fofac.spacebest")
        }
    }
}

// MARK: - Рисунки

struct AsteroidShape: Shape {
    let seed: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let R = min(rect.width, rect.height) / 2 * 0.94
        let n = 36
        let s = Double(seed)
        for i in 0...n {
            let a = Double(i) / Double(n) * 2.0 * Double.pi
            let wob = 1.0 + 0.045 * sin(a * 5.0 + s) + 0.03 * sin(a * 9.0 + s * 1.7)
            let pt = CGPoint(x: cx + CGFloat(cos(a) * wob) * R, y: cy + CGFloat(sin(a) * wob) * R)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct RockView: View {
    let text: String
    let seed: Int
    let mark: Int

    var body: some View {
        let outline: Color = mark == 1 ? Color(red: 0.35, green: 0.95, blue: 0.7) : (mark == 2 ? Color(red: 1, green: 0.45, blue: 0.45) : Color.white.opacity(0.18))
        return ZStack {
            AsteroidShape(seed: seed)
                .fill(LinearGradient(colors: [Color(red: 0.33, green: 0.35, blue: 0.88), Color(red: 0.16, green: 0.17, blue: 0.55)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            AsteroidShape(seed: seed)
                .stroke(outline, lineWidth: mark == 0 ? 2 : 3)
            Text(text)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(12)
        }
        .frame(width: 92, height: 92)
    }
}

struct TurretView: View {
    let angle: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.7, green: 0.95, blue: 0.85)).frame(width: 10, height: 34).offset(x: -52)
            RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.7, green: 0.95, blue: 0.85)).frame(width: 10, height: 34).offset(x: 52)
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.6)).frame(width: 18, height: 26).offset(y: -50)
            }
            .rotationEffect(.degrees(angle))
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.45, green: 0.95, blue: 0.7), Color(red: 0.1, green: 0.62, blue: 0.45)],
                                     center: .center, startRadius: 4, endRadius: 52))
                .frame(width: 92, height: 92)
            Circle().stroke(Color.white.opacity(0.35), lineWidth: 3).frame(width: 84, height: 84)
            Circle().fill(Color(red: 0.07, green: 0.4, blue: 0.32)).frame(width: 46, height: 46)
            Circle()
                .fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center))
                .frame(width: 24, height: 24)
            Circle().stroke(Color.white.opacity(0.8), lineWidth: 2).frame(width: 24, height: 24)
        }
        .frame(width: 130, height: 130)
    }
}

// MARK: - Экран игры

struct SpaceBoard: View {
    @StateObject private var vm: SpaceVM
    let onClose: () -> Void
    @AppStorage("voiceOn") private var voiceOn = true
    @State private var last = Date()
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let stars: [CGPoint] = (0..<45).map { _ in CGPoint(x: Double.random(in: 0...1), y: Double.random(in: 0...1)) }

    init(store: Store, onClose: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: SpaceVM(store: store))
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.03, blue: 0.14), Color(red: 0.08, green: 0.08, blue: 0.30)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                if vm.cardCount < 4 {
                    Spacer()
                    Text("Чтобы играть, добавь в «Карточки» хотя бы 4 слова.")
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else {
                    GeometryReader { geo in field(geo.size) }
                }
            }
        }
        .statusBarHidden(true)
        .onReceive(timer) { now in
            let dt = min(now.timeIntervalSince(last), 0.05)
            last = now
            vm.step(dt: dt)
        }
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            Image("Logo")
                .resizable()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Spacer()
            Button { voiceOn.toggle() } label: {
                Image(systemName: voiceOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            Button { onClose() } label: { Image(systemName: "xmark") }
        }
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.white.opacity(0.85))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.07))
    }

    private func field(_ s: CGSize) -> some View {
        let W = s.width
        let H = s.height
        let turret = CGPoint(x: W / 2, y: H - 62)
        var ang = 0.0
        if let a = vm.aim {
            ang = atan2(a.x * Double(W) - Double(turret.x), -(a.y * Double(H) - Double(turret.y))) * 180.0 / Double.pi
        }
        return ZStack(alignment: .topLeading) {
            ForEach(0..<stars.count, id: \.self) { i in
                Circle().fill(Color.blue.opacity(0.5)).frame(width: 3, height: 3)
                    .position(x: stars[i].x * W, y: stars[i].y * H)
            }
            promptBar(W)
            Text("\(Int(ceil(vm.timeLeft)))")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white.opacity(0.12))
                .position(x: W / 2, y: 70)
            ForEach(vm.rocks) { r in
                RockView(text: r.text, seed: r.seed, mark: r.mark)
                    .opacity(min(1.0, r.age / 0.6))
                    .position(x: r.x * W, y: r.y * H)
                    .onTapGesture { vm.tap(r.id) }
            }
            ForEach(vm.bullets) { b in bulletView(b, W, H, turret) }
            ForEach(vm.fxs) { f in fxView(f, W, H) }
            TurretView(angle: ang).position(x: turret.x, y: turret.y)
            hud(W, H)
            phaseOverlay(W, H)
        }
        .frame(width: W, height: H)
    }

    private func promptBar(_ W: CGFloat) -> some View {
        VStack(spacing: 8) {
            Text(vm.prompt)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .shadow(color: Color.white.opacity(0.35), radius: 8)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 14)
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.15)).frame(height: 3)
                Rectangle().fill(Color(red: 0.6, green: 0.62, blue: 1.0))
                    .frame(width: W * CGFloat(min(1.0, Double(vm.points) / Double(max(vm.target, 1)))), height: 3)
            }
        }
        .frame(width: W)
    }

    private func bulletView(_ b: Bullet, _ W: CGFloat, _ H: CGFloat, _ turret: CGPoint) -> some View {
        guard let r = vm.rocks.first(where: { $0.id == b.target }) else { return AnyView(EmptyView()) }
        let tx = CGFloat(r.x) * W
        let ty = CGFloat(r.y) * H
        let p = CGFloat(min(1.0, b.p))
        let x = turret.x + (tx - turret.x) * p
        let y = turret.y + (ty - turret.y) * p
        let ang = atan2(Double(tx - turret.x), -Double(ty - turret.y)) * 180.0 / Double.pi
        return AnyView(
            Capsule()
                .fill(LinearGradient(colors: [.white, Color(white: 0.7)], startPoint: .top, endPoint: .bottom))
                .frame(width: 9, height: 20)
                .rotationEffect(.degrees(ang))
                .position(x: x, y: y)
        )
    }

    private func fxView(_ f: Fx, _ W: CGFloat, _ H: CGFloat) -> some View {
        let k = CGFloat(f.age / 0.9)
        return ZStack {
            RockView(text: f.ghost, seed: 1, mark: 0).opacity(max(0.0, 0.4 - Double(k) * 0.5))
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [2, 5]))
                .foregroundColor(Color.blue.opacity(max(0.0, 0.9 * (1.0 - Double(k)))))
                .frame(width: 90, height: 90)
                .scaleEffect(0.7 + k * 1.6)
            Text(f.text)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(f.good ? Color(red: 1, green: 0.95, blue: 0.45) : Color(red: 1, green: 0.5, blue: 0.5))
                .opacity(max(0.0, 1.0 - Double(k)))
                .offset(y: -k * 34)
        }
        .position(x: CGFloat(f.x) * W, y: CGFloat(f.y) * H)
        .allowsHitTesting(false)
    }

    private func hud(_ W: CGFloat, _ H: CGFloat) -> some View {
        let yellow = Color(red: 1, green: 0.92, blue: 0.3)
        let purple = Color(red: 0.75, green: 0.5, blue: 1.0)
        let mult = 1.0 + 0.2 * Double(min(vm.streak, 10))
        return ZStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(vm.level)").font(.system(size: 13, weight: .bold)).foregroundColor(yellow)
                    Spacer()
                    Text("\(vm.points)/\(vm.target)").font(.system(size: 13, weight: .bold)).foregroundColor(yellow)
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15)).frame(height: 7)
                    Capsule().fill(yellow).frame(width: 108 * CGFloat(min(1.0, Double(vm.points) / Double(max(vm.target, 1)))), height: 7)
                }
            }
            .frame(width: 108)
            .position(x: 16 + 54, y: H - 30)
            VStack(alignment: .trailing, spacing: 4) {
                Text(vm.streak > 0 ? "Серия ×" + String(format: "%.1f", mult) : "Серия")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(purple.opacity(vm.streak > 0 ? 1 : 0.6))
                HStack(spacing: 2) {
                    ForEach(0..<10, id: \.self) { i in
                        Rectangle().fill(i < vm.streak ? purple : purple.opacity(0.25)).frame(width: 10, height: 6)
                    }
                }
            }
            .position(x: W - 16 - 59, y: H - 30)
        }
    }

    private func phaseOverlay(_ W: CGFloat, _ H: CGFloat) -> some View {
        let glow = Color(red: 1, green: 0.95, blue: 0.35)
        return ZStack {
            if vm.phase == 0 {
                Text("Уровень \(vm.level)")
                    .font(.system(size: 34, weight: .bold)).foregroundColor(glow)
                    .shadow(color: glow.opacity(0.8), radius: 12)
                    .position(x: W / 2, y: H * 0.42)
            }
            if vm.phase == 1 {
                Text("Цель: \(vm.target) очков")
                    .font(.system(size: 34, weight: .bold)).foregroundColor(glow)
                    .shadow(color: glow.opacity(0.8), radius: 12)
                    .position(x: W / 2, y: H * 0.42)
            }
            if vm.phase == 4 {
                VStack(spacing: 12) {
                    Text("Время вышло").font(.system(size: 26, weight: .bold, design: .serif))
                    Text("Уровень \(vm.level) · очков \(vm.points)").foregroundColor(.secondary)
                    Text("Лучший уровень: \(vm.bestLevel)").font(.footnote).foregroundColor(.secondary)
                    Button { vm.restart() } label: { Text("Ещё раз").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Button { onClose() } label: { Text("Выйти").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                }
                .padding(24)
                .frame(maxWidth: 300)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .position(x: W / 2, y: H * 0.45)
            }
        }
    }
}

/// Раздел из боковой панели
struct SpaceScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var app: AppState
    var body: some View {
        SpaceBoard(store: store, onClose: { app.tab = 1 })
    }
}

/// Открывается после повторения карточек
struct SpaceCover: View {
    let store: Store
    let onClose: () -> Void
    var body: some View {
        SpaceBoard(store: store, onClose: onClose)
    }
}
