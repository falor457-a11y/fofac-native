import Foundation

struct Quest: Codable, Identifiable {
    var id = UUID()
    let s: String
    let o: [String]
    let c: Int
    let t: String
    let x: String
    let tr: String
    let l: Int
    let w: [String]
    var gen = false
    enum CodingKeys: String, CodingKey { case s, o, c, t, x, tr, l, w }
}

struct ErrQ: Codable, Identifiable {
    var id = UUID()
    let s: String
    let i: Int
    let t: String
    let k: String
    let x: String
    let tr: String
    let l: Int
    enum CodingKeys: String, CodingKey { case s, i, t, k, x, tr, l }
}

struct Tense: Codable, Identifiable, Hashable {
    let id: String
    let n: String
    let ru: String
    let use: String
    let f: [String]
    let mk: String
    let ex: [[String]]
    let tip: String
}

struct TGroup: Codable, Identifiable {
    let g: String
    let sub: String
    let items: [Tense]
    var id: String { g }
}

struct AppData: Codable {
    let q: [Quest]
    let e: [ErrQ]
    let tenses: [TGroup]
    let dict: [String: String]
}

enum DB {
    static let data: AppData = {
        if let u = Bundle.main.url(forResource: "data", withExtension: "json"),
           let d = try? Data(contentsOf: u),
           let a = try? JSONDecoder().decode(AppData.self, from: d) {
            return a
        }
        return AppData(q: [], e: [], tenses: [], dict: [:])
    }()
}

extension Quest {
    func shuffledOpts() -> Quest {
        var idxs = Array(o.indices)
        idxs.shuffle()
        var q = Quest(s: s, o: idxs.map { o[$0] }, c: idxs.firstIndex(of: c) ?? 0, t: t, x: x, tr: tr, l: l,
                      w: idxs.map { w.indices.contains($0) ? w[$0] : "" })
        q.gen = gen
        return q
    }
}

// MARK: - Перевод слова

let irregularMap: [String: String] = [
    "went": "go", "gone": "go", "ate": "eat", "eaten": "eat", "wrote": "write", "written": "write",
    "saw": "see", "seen": "see", "bought": "buy", "took": "take", "taken": "take", "made": "make",
    "drank": "drink", "drunk": "drink", "met": "meet", "spoke": "speak", "spoken": "speak",
    "gave": "give", "given": "give", "was": "be", "were": "be", "am": "be", "is": "be", "are": "be",
    "did": "do", "does": "do", "done": "do", "came": "come", "knew": "know", "thought": "think",
    "found": "find", "got": "get", "told": "tell", "left": "leave", "felt": "feel", "lost": "lose",
    "paid": "pay", "sent": "send", "began": "begin", "brought": "bring", "ran": "run", "sat": "sit",
    "stood": "stand", "understood": "understand", "forgot": "forget", "forgotten": "forget",
    "children": "child", "men": "man", "women": "woman", "people": "person"
]

func lookupWord(_ raw: String) -> String? {
    let d = DB.data.dict
    var x = String(raw.lowercased().filter { $0.isLetter || $0 == "'" || $0 == "’" })
    x = x.replacingOccurrences(of: "’", with: "'")
    if x.hasSuffix("'s") { x = String(x.dropLast(2)) }
    if x.isEmpty { return nil }
    if let r = d[x] { return r }
    if let base = irregularMap[x], let r = d[base] { return r }
    var c: [String] = []
    if x.hasSuffix("ies") { c.append(String(x.dropLast(3)) + "y") }
    if x.hasSuffix("es") { c.append(String(x.dropLast(2))) }
    if x.hasSuffix("s") { c.append(String(x.dropLast(1))) }
    if x.hasSuffix("ied") { c.append(String(x.dropLast(3)) + "y") }
    if x.hasSuffix("ed") {
        c.append(String(x.dropLast(2)))
        c.append(String(x.dropLast(1)))
        if x.count > 4 { c.append(String(x.dropLast(3))) }
    }
    if x.hasSuffix("ing") {
        c.append(String(x.dropLast(3)))
        c.append(String(x.dropLast(3)) + "e")
        if x.count > 5 { c.append(String(x.dropLast(4))) }
    }
    if x.hasSuffix("ly") { c.append(String(x.dropLast(2))) }
    for y in c where y.count > 1 {
        if let r = d[y] { return r }
    }
    return nil
}

// MARK: - Генератор вопросов по временам

struct Verb {
    let b: String, s: String, g: String, p: String, pp: String, o: String
    let irr: Bool
}

struct Subj {
    let n: String
    let i: Bool
    let t: Bool
}

let verbs: [Verb] = [
    Verb(b: "work", s: "works", g: "working", p: "worked", pp: "worked", o: "at the office", irr: false),
    Verb(b: "play", s: "plays", g: "playing", p: "played", pp: "played", o: "football", irr: false),
    Verb(b: "study", s: "studies", g: "studying", p: "studied", pp: "studied", o: "English", irr: false),
    Verb(b: "finish", s: "finishes", g: "finishing", p: "finished", pp: "finished", o: "the report", irr: false),
    Verb(b: "call", s: "calls", g: "calling", p: "called", pp: "called", o: "the client", irr: false),
    Verb(b: "watch", s: "watches", g: "watching", p: "watched", pp: "watched", o: "a film", irr: false),
    Verb(b: "clean", s: "cleans", g: "cleaning", p: "cleaned", pp: "cleaned", o: "the kitchen", irr: false),
    Verb(b: "open", s: "opens", g: "opening", p: "opened", pp: "opened", o: "the window", irr: false),
    Verb(b: "learn", s: "learns", g: "learning", p: "learned", pp: "learned", o: "new words", irr: false),
    Verb(b: "go", s: "goes", g: "going", p: "went", pp: "gone", o: "to school", irr: true),
    Verb(b: "eat", s: "eats", g: "eating", p: "ate", pp: "eaten", o: "lunch", irr: true),
    Verb(b: "write", s: "writes", g: "writing", p: "wrote", pp: "written", o: "an email", irr: true),
    Verb(b: "buy", s: "buys", g: "buying", p: "bought", pp: "bought", o: "a new phone", irr: true),
    Verb(b: "take", s: "takes", g: "taking", p: "took", pp: "taken", o: "a photo", irr: true),
    Verb(b: "make", s: "makes", g: "making", p: "made", pp: "made", o: "a cake", irr: true),
    Verb(b: "drink", s: "drinks", g: "drinking", p: "drank", pp: "drunk", o: "coffee", irr: true),
    Verb(b: "meet", s: "meets", g: "meeting", p: "met", pp: "met", o: "a new client", irr: true),
    Verb(b: "see", s: "sees", g: "seeing", p: "saw", pp: "seen", o: "the doctor", irr: true),
    Verb(b: "give", s: "gives", g: "giving", p: "gave", pp: "given", o: "a presentation", irr: true),
    Verb(b: "speak", s: "speaks", g: "speaking", p: "spoke", pp: "spoken", o: "English", irr: true)
]

let subjects: [Subj] = [
    Subj(n: "I", i: true, t: false), Subj(n: "You", i: false, t: false), Subj(n: "We", i: false, t: false),
    Subj(n: "They", i: false, t: false), Subj(n: "He", i: false, t: true), Subj(n: "She", i: false, t: true),
    Subj(n: "Anna", i: false, t: true), Subj(n: "Tom", i: false, t: true),
    Subj(n: "My brother", i: false, t: true), Subj(n: "The students", i: false, t: false)
]

let subjectsW: [Subj] = [
    Subj(n: "I", i: true, t: false), Subj(n: "we", i: false, t: false), Subj(n: "they", i: false, t: false),
    Subj(n: "he", i: false, t: true), Subj(n: "she", i: false, t: true)
]

func beNow(_ s: Subj) -> String { return s.i ? "am" : (s.t ? "is" : "are") }
func bePast(_ s: Subj) -> String { return (s.i || s.t) ? "was" : "were" }
func haveForm(_ s: Subj) -> String { return s.t ? "has" : "have" }

func goodForm(_ k: String, _ s: Subj, _ v: Verb) -> String {
    switch k {
    case "ps": return s.t ? v.s : v.b
    case "pc": return beNow(s) + " " + v.g
    case "pp": return haveForm(s) + " " + v.pp
    case "ppc": return haveForm(s) + " been " + v.g
    case "as": return v.p
    case "ac": return bePast(s) + " " + v.g
    case "ap": return "had " + v.pp
    case "apc": return "had been " + v.g
    case "fs": return "will " + v.b
    case "fc": return "will be " + v.g
    case "fp": return "will have " + v.pp
    case "fpc": return "will have been " + v.g
    case "w1": return "would " + v.b
    case "w2": return "would be " + v.g
    case "w3": return "would have " + v.pp
    default: return "would have been " + v.g
    }
}

func badForm(_ k: String, _ s: Subj, _ v: Verb) -> String {
    switch k {
    case "ps": return s.t ? v.b : v.s
    case "pc":
        let others = ["am", "is", "are"].filter { $0 != beNow(s) }
        return (others.randomElement() ?? "are") + " " + v.g
    case "pp": return (s.t ? "have " : "has ") + v.pp
    case "ppc": return (s.t ? "have" : "has") + " been " + v.g
    case "as": return v.irr ? v.b + "ed" : v.b
    case "ac": return ((s.i || s.t) ? "were " : "was ") + v.g
    case "ap": return haveForm(s) + " " + v.pp
    case "apc": return "had been " + v.b
    case "fs": return "will " + v.g
    case "fc": return "will " + v.g
    case "fp": return "will " + v.pp
    case "fpc": return "will have been " + v.b
    case "w1": return "would " + v.s
    case "w2": return "would " + v.g
    case "w3": return "would " + v.pp
    default: return "would have been " + v.b
    }
}

let nearKey: [String: String] = [
    "ps": "pc", "pc": "ps", "pp": "as", "ppc": "pc", "as": "pp", "ac": "as", "ap": "as", "apc": "ap",
    "fs": "ps", "fc": "fs", "fp": "fs", "fpc": "fp", "w1": "fs", "w2": "w1", "w3": "w1", "w4": "w3"
]

struct TInfo {
    let name: String
    let formula: String
    let why: String
}

let tenseInfo: [String: TInfo] = [
    "ps": TInfo(name: "Present Simple", formula: "V (с he/she/it — V-s)", why: "с he/she/it нужно -s, с I/you/we/they — без -s"),
    "pc": TInfo(name: "Present Continuous", formula: "am/is/are + V-ing", why: "am — с I, is — с he/she, are — с you/we/they"),
    "pp": TInfo(name: "Present Perfect", formula: "have/has + V3", why: "have — с I/you/we/they, has — с he/she"),
    "ppc": TInfo(name: "Present Perfect Continuous", formula: "have/has been + V-ing", why: "have — с I/you/we/they, has — с he/she"),
    "as": TInfo(name: "Past Simple", formula: "V2 (-ed или неправильная форма)", why: "нужна вторая форма глагола (V2)"),
    "ac": TInfo(name: "Past Continuous", formula: "was/were + V-ing", why: "was — с I/he/she, were — с you/we/they"),
    "ap": TInfo(name: "Past Perfect", formula: "had + V3", why: "в Past Perfect всегда had, а не have/has"),
    "apc": TInfo(name: "Past Perfect Continuous", formula: "had been + V-ing", why: "после had been нужен глагол с -ing"),
    "fs": TInfo(name: "Future Simple", formula: "will + V", why: "после will глагол без -ing и без -s"),
    "fc": TInfo(name: "Future Continuous", formula: "will be + V-ing", why: "после will нужно be + -ing"),
    "fp": TInfo(name: "Future Perfect", formula: "will have + V3", why: "после will нужно have + V3"),
    "fpc": TInfo(name: "Future Perfect Continuous", formula: "will have been + V-ing", why: "после will have been нужен глагол с -ing"),
    "w1": TInfo(name: "Future Simple in the Past", formula: "would + V", why: "после would глагол без -s"),
    "w2": TInfo(name: "Future Continuous in the Past", formula: "would be + V-ing", why: "после would нужно be + -ing"),
    "w3": TInfo(name: "Future Perfect in the Past", formula: "would have + V3", why: "после would нужно have + V3"),
    "w4": TInfo(name: "Future Perfect Continuous in the Past", formula: "would have been + V-ing", why: "после would have been нужен глагол с -ing")
]

let markers: [String: [String]] = [
    "ps": ["every day", "every morning", "on Mondays", "every weekend", "twice a week"],
    "pc": ["now", "right now", "at the moment", "today"],
    "pp": ["already", "this week", "recently", "since 2020"],
    "ppc": ["for two hours", "since morning", "all day", "for a long time"],
    "as": ["yesterday", "last week", "two days ago", "in 2019", "last night"],
    "ac": ["at 8 o'clock yesterday", "all evening yesterday", "at that moment"],
    "ap": ["before the meeting started", "by 5 o'clock yesterday", "before I arrived"],
    "apc": ["for an hour before I arrived", "for two hours before the meeting", "all day before it rained"],
    "fs": ["tomorrow", "next week", "soon", "next year"],
    "fc": ["at 8 o'clock tomorrow", "this time tomorrow", "all day tomorrow"],
    "fp": ["by Friday", "by next year", "by 2030"],
    "fpc": ["for two hours by 5 pm", "for ten years by 2030", "for a year by June"],
    "w1": ["the next day", "the following week", "the next year"],
    "w2": ["at 8 the next morning", "this time the next day", "all the next day"],
    "w3": ["by Friday", "by the end of the week", "by the next year"],
    "w4": ["for two hours by 5 pm", "for ten years by the next year", "for a year by June"]
]

let genKey: [String: String] = [
    "ps": "ps", "pc": "pc", "pp": "pp", "pcn": "ppc", "a1": "as", "a2": "ac", "a3": "ap", "a4": "apc",
    "f1": "fs", "f2": "fc", "f3": "fp", "f4": "fpc", "w1": "w1", "w2": "w2", "w3": "w3", "w4": "w4"
]

func genQuest(_ k: String) -> Quest? {
    let w = k.hasPrefix("w")
    for _ in 0..<30 {
        guard let v = verbs.randomElement(),
              let m = markers[k]?.randomElement(),
              let sub = (w ? subjectsW : subjects).randomElement(),
              let near = nearKey[k],
              let info = tenseInfo[k],
              let ninfo = tenseInfo[near] else { return nil }
        let c = goodForm(k, sub, v)
        let d1 = badForm(k, sub, v)
        let d2 = goodForm(near, sub, v)
        if Set([c, d1, d2]).count < 3 { continue }
        let mains = ["Tom", "Anna", "My boss", "The teacher"]
        let start = w ? (mains.randomElement() ?? "Tom") + " said that " + sub.n + " " : sub.n + " "
        let sent = start + "___ " + v.o + " " + m + "."
        var arr: [(String, String)] = [(c, ""), (d1, info.why), (d2, d2 + " — это " + ninfo.name + ", а здесь нужен " + info.name)]
        arr.shuffle()
        let ci = arr.firstIndex(where: { $0.0 == c }) ?? 0
        var q = Quest(s: sent, o: arr.map { $0.0 }, c: ci, t: info.name, x: info.name + ": " + info.formula,
                      tr: "", l: 1, w: arr.map { $0.1 })
        q.gen = true
        return q
    }
    return nil
}

func genRound(_ k: String, _ n: Int) -> [Quest] {
    var out: [Quest] = []
    var seen = Set<String>()
    var tries = 0
    while out.count < n && tries < 80 {
        tries += 1
        if let q = genQuest(k), !seen.contains(q.s) {
            seen.insert(q.s)
            out.append(q)
        }
    }
    return out
}
