import Foundation
import UserNotifications

struct SRSState: Codable {
    var ef: Double = 2.5
    var iv: Int = 0
    var reps: Int = 0
    var lapses: Int = 0
    var ls: Int = 0
    var ag: Int = 0
    var due: Date = Date()
}

struct Card: Codable, Identifiable {
    var id: String = UUID().uuidString
    var f: String
    var b: String
    var t: String = ""
    var st: SRSState?
}

/// Интервальное повторение (то же, что в веб-версии)
func schedule(_ s0: SRSState, _ r: Int) -> SRSState {
    var c = s0
    c.ag = 0
    let now = Date()
    if r == 0 {
        c.ag = 1; c.reps = 0; c.iv = 0; c.ls = 0
        c.lapses += 1
        c.ef = max(1.3, c.ef - 0.2)
        c.due = now.addingTimeInterval(60)
        return c
    }
    if c.reps == 0 {
        if r == 1 {
            c.iv = 0
            c.due = now.addingTimeInterval(600)
            return c
        }
        c.ls = 0
        c.iv = (r == 2) ? 1 : 5
        if r == 3 { c.ef += 0.15 }
        c.reps = 1
        c.due = now.addingTimeInterval(Double(c.iv) * 86400)
        return c
    }
    if r == 1 {
        c.iv = max(c.iv + 1, Int((Double(c.iv) * 1.2).rounded()))
        c.ef = max(1.3, c.ef - 0.15)
    } else if r == 2 {
        c.iv = max(c.iv + 1, Int((Double(c.iv) * c.ef).rounded()))
    } else {
        c.iv = max(c.iv + 2, Int((Double(c.iv) * c.ef * 1.3).rounded()))
        c.ef += 0.15
    }
    c.reps += 1
    c.due = now.addingTimeInterval(Double(c.iv) * 86400)
    return c
}

func fmtInterval(_ s: SRSState?, _ r: Int) -> String {
    let n = schedule(s ?? SRSState(), r)
    if n.iv == 0 {
        let m = max(1, Int((n.due.timeIntervalSinceNow / 60).rounded()))
        return "<\(m) мин."
    }
    let d = n.iv
    if d < 30 { return "\(d) дн." }
    if d < 365 { return "\(Int((Double(d) / 30).rounded())) мес." }
    return String(format: "%.1f г.", Double(d) / 365)
}

func whenText(_ d: Date, now: Date = Date()) -> String {
    if d <= now { return "сейчас" }
    let startToday = Calendar.current.startOfDay(for: now)
    let startTomorrow = startToday.addingTimeInterval(86400)
    if d < startTomorrow {
        let m = max(1, Int((d.timeIntervalSince(now) / 60).rounded()))
        return m < 60 ? "через \(m) мин" : "сегодня"
    }
    let days = Int(floor(d.timeIntervalSince(startToday) / 86400))
    return days == 1 ? "завтра" : "через \(days) д"
}

func ruPlural(_ n: Int, _ a: String, _ b: String, _ c: String) -> String {
    let m10 = n % 10
    let m100 = n % 100
    if m10 == 1 && m100 != 11 { return a }
    if m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20) { return b }
    return c
}

final class Store: ObservableObject {
    @Published var cards: [Card] = [] {
        didSet {
            saveCards()
            planNotifications()
        }
    }
    @Published var best: Int = 0
    @Published var moves: Int = 0
    var earnedToday: Int = 0
    let moveCap = 30
    var newToday: Int = 0
    var dayKey: String = ""
    let limit = 20
    private let d = UserDefaults.standard

    init() {
        if let data = d.data(forKey: "fofac.cards"),
           let c = try? JSONDecoder().decode([Card].self, from: data) {
            cards = c
        }
        best = d.integer(forKey: "fofac.best")
        dayKey = d.string(forKey: "fofac.day") ?? ""
        newToday = d.integer(forKey: "fofac.n")
        earnedToday = d.integer(forKey: "fofac.earned")
        moves = d.integer(forKey: "fofac.moves")
        rollDay()
        planNotifications()
    }

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    func rollDay() {
        let k = todayKey()
        if dayKey != k {
            dayKey = k
            newToday = 0
            earnedToday = 0
            saveDay()
        }
    }

    func saveDay() {
        d.set(dayKey, forKey: "fofac.day")
        d.set(newToday, forKey: "fofac.n")
        d.set(earnedToday, forKey: "fofac.earned")
    }

    func saveBest() { d.set(best, forKey: "fofac.best") }

    /// Ход для игры «три в ряд» за правильный ответ (не больше 30 в день)
    @discardableResult
    func earnMove() -> Bool {
        rollDay()
        if earnedToday >= moveCap { return false }
        earnedToday += 1
        moves += 1
        d.set(moves, forKey: "fofac.moves")
        saveDay()
        return true
    }

    func useMove() {
        if moves > 0 {
            moves -= 1
            d.set(moves, forKey: "fofac.moves")
        }
    }

    private func saveCards() {
        if let data = try? JSONEncoder().encode(cards) {
            d.set(data, forKey: "fofac.cards")
        }
    }

    var stats: (due: Int, fresh: Int, total: Int, learned: Int) { return statsAt(Date()) }

    func statsAt(_ now: Date) -> (due: Int, fresh: Int, total: Int, learned: Int) {
        rollDay()
        var due = 0
        var nw = 0
        var learned = 0
        for c in cards {
            if let s = c.st {
                if s.due <= now { due += 1 }
                if s.iv >= 21 { learned += 1 }
            } else {
                nw += 1
            }
        }
        return (due, min(nw, max(0, limit - newToday)), cards.count, learned)
    }

    func add(front: String, back: String, note: String) {
        cards.append(Card(f: front, b: back, t: note))
    }

    /// Уведомление приходит ровно тогда, когда карточка снова должна повториться
    func planNotifications() {
        let states = cards.compactMap { $0.st }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            guard ok else { return }
            center.removeAllPendingNotificationRequests()
            let now = Date()
            let times = states
                .filter { $0.ag == 0 && $0.due > now.addingTimeInterval(5) }
                .map { $0.due }
                .sorted()
            var groups: [Date] = []
            for t in times {
                if let last = groups.last, t.timeIntervalSince(last) < 30 { continue }
                groups.append(t)
            }
            for (i, t) in groups.prefix(60).enumerated() {
                let n = states.filter { $0.due <= t.addingTimeInterval(30) }.count
                let content = UNMutableNotificationContent()
                content.title = "fofac"
                content.body = "Пора повторять: \(n) " + ruPlural(n, "карточка", "карточки", "карточек")
                content.sound = .default
                let interval = max(1, t.timeIntervalSince(Date()))
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                center.add(UNNotificationRequest(identifier: "due\(i)", content: content, trigger: trigger))
            }
        }
    }
}

final class ReviewVM: ObservableObject {
    @Published var queue: [Card] = []
    @Published var back = false
    @Published var reviewed = 0
    let store: Store

    init(store: Store) {
        self.store = store
        start()
    }

    func start() {
        store.rollDay()
        let now = Date()
        let due = store.cards
            .filter { $0.st != nil && $0.st!.due <= now }
            .sorted { $0.st!.due < $1.st!.due }
        let nw = Array(store.cards.filter { $0.st == nil }.prefix(max(0, store.limit - store.newToday)))
        queue = due + nw
        back = false
        reviewed = 0
    }

    func rate(_ r: Int) {
        guard !queue.isEmpty else { return }
        var x = queue.removeFirst()
        let isNew = (x.st == nil)
        x.st = schedule(x.st ?? SRSState(), r)
        if isNew {
            store.newToday += 1
            store.saveDay()
        }
        if let i = store.cards.firstIndex(where: { $0.id == x.id }) {
            store.cards[i] = x
        }
        reviewed += 1
        if r > 0 { store.earnMove() }
        if r == 0 { queue.insert(x, at: min(3, queue.count)) }
        back = false
    }
}
