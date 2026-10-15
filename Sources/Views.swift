import SwiftUI
import UIKit

// MARK: - Раскладка «слова в строку»

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        var w: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW && x > 0 {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            w = max(w, x)
        }
        return CGSize(width: w, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

/// Предложение, в котором на каждое слово можно нажать и увидеть перевод
struct WordFlow: View {
    let text: String
    var size: CGFloat = 24
    @Binding var tip: String?

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(text.split(separator: " ").enumerated()), id: \.offset) { _, w in
                Text(String(w))
                    .font(.system(size: size, weight: .semibold, design: .serif))
                    .onTapGesture { show(String(w)) }
            }
        }
    }

    private func show(_ w: String) {
        let clean = String(w.filter { $0.isLetter || $0 == "'" })
        if clean.isEmpty { return }
        let tr = lookupWord(clean) ?? "нет в словаре"
        tip = clean + " — " + tr
        let mine = tip
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if tip == mine { tip = nil }
        }
    }
}

struct TipBubble: View {
    let tip: String?
    var body: some View {
        if let t = tip {
            Text(t)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .padding(.top, 6)
        }
    }
}

struct RuHint: View {
    let text: String
    @State private var shown = false
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .blur(radius: shown ? 0 : 5)
            .onTapGesture { shown.toggle() }
    }
}

func haptic(_ ok: Bool) {
    UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .error)
}

// MARK: - Игра

struct GameHome: View {
    @EnvironmentObject var store: Store
    @State private var mode = 0
    @State private var level = 0
    @State private var playing = false
    @State private var qs: [Quest] = []
    @State private var es: [ErrQ] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Тренажёр грамматики: A2 → B2").foregroundColor(.secondary)
                    Picker("Режим", selection: $mode) {
                        Text("Выбор ответа").tag(0)
                        Text("Найди ошибку").tag(1)
                    }
                    .pickerStyle(.segmented)
                    Picker("Уровень", selection: $level) {
                        Text("A2").tag(1)
                        Text("B1").tag(2)
                        Text("B2").tag(3)
                        Text("Микс").tag(0)
                    }
                    .pickerStyle(.segmented)
                    Text("Рекорд: \(store.best) очков").font(.footnote).foregroundColor(.secondary)
                    Button { start() } label: {
                        Text("Начать игру").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
            }
            .navigationTitle("fofac")
            .fullScreenCover(isPresented: $playing) {
                QuizView(mode: mode, qs: qs, es: es, onClose: { playing = false })
            }
        }
    }

    private func start() {
        if mode == 0 {
            qs = DB.data.q.filter { level == 0 || $0.l == level }.shuffled().prefix(10).map { $0.shuffledOpts() }
            es = []
        } else {
            es = Array(DB.data.e.filter { level == 0 || $0.l == level }.shuffled().prefix(10))
            qs = []
        }
        playing = true
    }
}

struct QuizView: View {
    @EnvironmentObject var store: Store
    let mode: Int
    let qs: [Quest]
    let es: [ErrQ]
    let onClose: () -> Void

    @State private var idx = 0
    @State private var lives = 3
    @State private var score = 0
    @State private var streak = 0
    @State private var picked: Int? = nil
    @State private var finished = false
    @State private var tip: String? = nil

    private var count: Int { mode == 0 ? qs.count : es.count }
    private var isLast: Bool { lives == 0 || idx == count - 1 }

    var body: some View {
        NavigationStack {
            Group {
                if finished || count == 0 { resultView } else { questionView }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Выйти") { onClose() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .overlay(alignment: .top) { TipBubble(tip: tip).padding(.top, 50) }
        .animation(.easeInOut(duration: 0.2), value: tip)
    }

    private var questionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Вопрос \(idx + 1)/\(count)").font(.footnote).foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { k in
                            Circle().fill(Color.red.opacity(k < lives ? 1 : 0.2)).frame(width: 10, height: 10)
                        }
                    }
                    Spacer()
                    Text("Очки \(score)" + (streak > 1 ? " · серия \(streak)" : ""))
                        .font(.footnote).foregroundColor(.secondary)
                }
                ProgressView(value: Double(idx), total: Double(max(count, 1)))
                if mode == 0 { mcBody } else { errBody }
            }
            .padding()
        }
    }

    private func tag(_ s: String) -> some View {
        Text(s)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.15))
            .clipShape(Capsule())
    }

    // Выбор ответа
    private var mcBody: some View {
        let q = qs[idx]
        return VStack(alignment: .leading, spacing: 12) {
            tag((q.gen ? "Выбери форму · " : "") + q.t)
            WordFlow(text: q.s.replacingOccurrences(of: "___", with: "_____"), tip: $tip)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            if !q.tr.isEmpty { RuHint(text: q.tr) }
            ForEach(Array(q.o.enumerated()), id: \.offset) { k, opt in
                Button { answerMC(k, q) } label: {
                    Text(opt).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(optTint(k, q.c))
                .disabled(picked != nil)
            }
            if let p = picked { feedbackMC(q, p) }
        }
    }

    private func optTint(_ k: Int, _ c: Int) -> Color {
        guard let p = picked else { return .accentColor }
        if k == c { return .green }
        if k == p { return .red }
        return .gray
    }

    private func answerMC(_ k: Int, _ q: Quest) {
        picked = k
        if k == q.c {
            streak += 1
            score += 10 + min(streak - 1, 5) * 2
            haptic(true)
        } else {
            lives -= 1
            streak = 0
            haptic(false)
        }
    }

    private func feedbackMC(_ q: Quest, _ p: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if p == q.c {
                Text("Верно!").bold().foregroundColor(.green)
            } else {
                let why = (q.w.indices.contains(p) && !q.w[p].isEmpty) ? " — " + q.w[p] : ""
                Text("Неверно: ").bold().foregroundColor(.red) + Text(q.o[p] + why)
            }
            Text("Правильно: ").bold().foregroundColor(.green)
                + Text(q.s.replacingOccurrences(of: "___", with: q.o[q.c]))
            Text(LocalizedStringKey(q.x)).foregroundColor(.secondary)
            nextButton
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // Найди ошибку
    private var errBody: some View {
        let q = es[idx]
        let words = q.s.split(separator: " ").map { String($0) }
        return VStack(alignment: .leading, spacing: 12) {
            tag(q.t)
            Text("Найди ошибку в предложении. Нажми на неправильное слово:")
                .font(.subheadline).foregroundColor(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(Array(words.enumerated()), id: \.offset) { k, w in
                    Button { answerErr(k, q) } label: {
                        Text(w).font(.system(size: 22, weight: .semibold, design: .serif))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                    }
                    .buttonStyle(.bordered)
                    .tint(errTint(k, q.i))
                    .disabled(picked != nil)
                }
            }
            if !q.tr.isEmpty { RuHint(text: q.tr) }
            if let p = picked { feedbackErr(q, p, words) }
        }
    }

    private func errTint(_ k: Int, _ c: Int) -> Color {
        guard let p = picked else { return .accentColor }
        if k == c { return .green }
        if k == p { return .red }
        return .gray
    }

    private func answerErr(_ k: Int, _ q: ErrQ) {
        picked = k
        if k == q.i {
            streak += 1
            score += 10 + min(streak - 1, 5) * 2
            haptic(true)
        } else {
            lives -= 1
            streak = 0
            haptic(false)
        }
    }

    private func feedbackErr(_ q: ErrQ, _ p: Int, _ words: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if p == q.i {
                Text("Верно!").bold().foregroundColor(.green)
            } else {
                Text("Неверно. ").bold().foregroundColor(.red)
                    + Text("Ошибка в слове «\(words.indices.contains(q.i) ? words[q.i] : "")».")
            }
            Text("Правильно: ").bold().foregroundColor(.green) + Text(q.k)
            Text(LocalizedStringKey(q.x)).foregroundColor(.secondary)
            nextButton
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var nextButton: some View {
        Button { next() } label: {
            Text(isLast ? "Результат" : "Дальше →").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func next() {
        if isLast {
            if score > store.best {
                store.best = score
                store.saveBest()
            }
            finished = true
        } else {
            idx += 1
            picked = nil
        }
    }

    private var resultView: some View {
        VStack(spacing: 14) {
            Spacer()
            Text(lives > 0 ? "Раунд пройден" : "Жизни закончились").foregroundColor(.secondary)
            Text("\(score)").font(.system(size: 80, weight: .bold, design: .serif)).foregroundColor(.accentColor)
            Text("Рекорд: \(store.best)").font(.footnote).foregroundColor(.secondary)
            Spacer()
            Button { onClose() } label: { Text("Готово").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }
}

// MARK: - Времена

struct TensesView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(DB.data.tenses) { g in
                    Section(header: Text("\(g.g) — \(g.sub)")) {
                        ForEach(g.items) { t in
                            NavigationLink(destination: TenseDetail(t: t)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.n).font(.headline)
                                    Text(t.ru).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Времена")
        }
    }
}

struct TenseDetail: View {
    let t: Tense
    @State private var playing = false
    @State private var qs: [Quest] = []
    @State private var tip: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                head("Когда использовать")
                Text(LocalizedStringKey(t.use))
                head("Формула")
                ForEach(t.f, id: \.self) { line in
                    Text(LocalizedStringKey(line))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                head("Слова-маркеры")
                Text(t.mk)
                head("Примеры (нажми на слово — увидишь перевод)")
                ForEach(Array(t.ex.enumerated()), id: \.offset) { _, e in
                    VStack(alignment: .leading, spacing: 2) {
                        WordFlow(text: e[0], size: 18, tip: $tip)
                        Text(e.count > 1 ? e[1] : "").font(.subheadline).foregroundColor(.secondary)
                    }
                }
                head("Важно")
                Text(LocalizedStringKey(t.tip))
                Button { start() } label: {
                    Text("Потренировать · 5 вопросов").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle(t.n)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) { TipBubble(tip: tip) }
        .animation(.easeInOut(duration: 0.2), value: tip)
        .fullScreenCover(isPresented: $playing) {
            QuizView(mode: 0, qs: qs, es: [], onClose: { playing = false })
        }
    }

    private func head(_ s: String) -> some View {
        Text(s).font(.footnote.weight(.semibold)).foregroundColor(.secondary).padding(.top, 8)
    }

    private func start() {
        qs = genRound(genKey[t.id] ?? "ps", 5)
        playing = true
    }
}

// MARK: - Карточки

struct CardsView: View {
    @EnvironmentObject var store: Store
    @State private var adding = false
    @State private var reviewing = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    let s = store.stats
                    Text("Всего: \(s.total) · к повторению: \(s.due) · новых сегодня: \(s.fresh) · выучено: \(s.learned)")
                        .font(.footnote).foregroundColor(.secondary)
                    Button("Учить") { reviewing = true }
                        .disabled(s.due + s.fresh == 0)
                }
                Section("Карточки") {
                    ForEach(store.cards) { c in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.f)
                            Text(c.b).font(.caption).foregroundColor(.secondary)
                            if let st = c.st {
                                Text(whenText(st.due)).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { store.cards.remove(atOffsets: $0) }
                }
            }
            .navigationTitle("Карточки")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $adding) { AddCardView() }
            .fullScreenCover(isPresented: $reviewing) {
                ReviewView(store: store, onClose: { reviewing = false })
            }
        }
    }
}

struct AddCardView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var front = ""
    @State private var back = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Лицевая сторона (вопрос)", text: $front, axis: .vertical)
                TextField("Ответ", text: $back, axis: .vertical)
                TextField("Заметка (необязательно)", text: $note, axis: .vertical)
            }
            .navigationTitle("Новая карточка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        store.add(front: front, back: back, note: note)
                        dismiss()
                    }
                    .disabled(front.trimmingCharacters(in: .whitespaces).isEmpty || back.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct ReviewView: View {
    @StateObject private var vm: ReviewVM
    let onClose: () -> Void

    init(store: Store, onClose: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: ReviewVM(store: store))
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            Group {
                if let x = vm.queue.first { cardView(x) } else { endView }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Назад") { onClose() } }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func cardView(_ x: Card) -> some View {
        let nNew = vm.queue.filter { $0.st == nil }.count
        let nRep = vm.queue.count - nNew
        return VStack(spacing: 16) {
            Text("Новых \(nNew) · повторов \(nRep)").font(.footnote).foregroundColor(.secondary)
            VStack(spacing: 18) {
                Text(x.f).font(.system(size: 30, weight: .semibold, design: .serif)).multilineTextAlignment(.center)
                if vm.back {
                    Divider()
                    Text(x.b).font(.title2.weight(.semibold)).foregroundColor(.accentColor).multilineTextAlignment(.center)
                    if !x.t.isEmpty { Text(x.t).font(.subheadline).foregroundColor(.secondary) }
                } else {
                    Text("Нажми на карточку, чтобы увидеть ответ").font(.footnote).foregroundColor(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, minHeight: 280)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .onTapGesture { if !vm.back { vm.back = true } }
            if vm.back {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { r in
                        VStack(spacing: 4) {
                            Text(fmtInterval(x.st, r)).font(.caption2).foregroundColor(.secondary)
                            Button { vm.rate(r) } label: {
                                Text(["Снова", "Трудно", "Хорошо", "Легко"][r]).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint([Color.red, Color.orange, Color.blue, Color.green][r])
                        }
                    }
                }
            } else {
                Button { vm.back = true } label: { Text("Показать ответ").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            Spacer()
        }
        .padding()
    }

    private var endView: some View {
        let st = vm.store.stats
        let nxt = vm.store.cards.compactMap { $0.st }.filter { $0.due > Date() }.map { $0.due }.sorted().first
        return VStack(spacing: 12) {
            Spacer()
            Text(st.due > 0 ? "Пора повторять" : (vm.reviewed > 0 ? "На сегодня всё!" : "Пока нечего повторять"))
                .font(.system(size: 28, weight: .bold, design: .serif))
            Text("Повторено карточек: \(vm.reviewed)").foregroundColor(.secondary)
            if let n = nxt { Text("Следующее повторение: " + whenText(n)).foregroundColor(.secondary) }
            if st.due > 0 {
                Button { vm.start() } label: { Text("Учить (\(st.due))").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            Spacer()
        }
        .padding()
    }
}
