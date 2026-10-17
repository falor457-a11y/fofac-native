import SwiftUI
import AVFoundation

// MARK: - Американская озвучка

final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()
    private lazy var voice: AVSpeechSynthesisVoice? = {
        let us = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        if let best = us.max(by: { $0.quality.rawValue < $1.quality.rawValue }) { return best }
        return AVSpeechSynthesisVoice(language: "en-US")
    }()

    func say(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: t)
        u.voice = voice
        u.rate = 0.46
        synth.speak(u)
    }
}

struct SpeakButton: View {
    let text: String
    var body: some View {
        Button { Speaker.shared.say(text) } label: {
            Image(systemName: "speaker.wave.2.fill")
        }
        .buttonStyle(.plain)
        .foregroundColor(.accentColor)
    }
}

func hasLatin(_ s: String) -> Bool {
    return s.range(of: "[A-Za-z]", options: .regularExpression) != nil
}

// MARK: - Неправильные глаголы

struct IrrVerb {
    let base: String
    let past: String
    let pp: String
    let ru: String
}

let irregularVerbs: [IrrVerb] = {
    let raw = "be:was/were:been:быть;become:became:become:становиться;begin:began:begun:начинать;beat:beat:beaten:бить;bend:bent:bent:гнуть;bet:bet:bet:спорить;bite:bit:bitten:кусать;blow:blew:blown:дуть;break:broke:broken:ломать;bring:brought:brought:приносить;broadcast:broadcast:broadcast:транслировать;build:built:built:строить;burn:burnt/burned:burnt/burned:гореть;buy:bought:bought:покупать;catch:caught:caught:ловить;choose:chose:chosen:выбирать;come:came:come:приходить;cost:cost:cost:стоить;cut:cut:cut:резать;deal:dealt:dealt:иметь дело;dig:dug:dug:копать;do:did:done:делать;draw:drew:drawn:рисовать;drink:drank:drunk:пить;drive:drove:driven:водить машину;eat:ate:eaten:есть;fall:fell:fallen:падать;feed:fed:fed:кормить;feel:felt:felt:чувствовать;fight:fought:fought:драться;find:found:found:находить;fly:flew:flown:летать;forbid:forbade:forbidden:запрещать;forget:forgot:forgotten:забывать;forgive:forgave:forgiven:прощать;freeze:froze:frozen:замерзать;get:got:got:получать;give:gave:given:давать;go:went:gone:идти, ехать;grow:grew:grown:расти;hang:hung:hung:вешать;have:had:had:иметь;hear:heard:heard:слышать;hide:hid:hidden:прятать;hit:hit:hit:ударять;hold:held:held:держать;hurt:hurt:hurt:причинять боль;keep:kept:kept:хранить, держать;know:knew:known:знать;lay:laid:laid:класть;lead:led:led:вести;learn:learnt/learned:learnt/learned:учить, учиться;leave:left:left:уходить, покидать;lend:lent:lent:одалживать;let:let:let:позволять;lie:lay:lain:лежать;light:lit:lit:зажигать;lose:lost:lost:терять;make:made:made:делать;mean:meant:meant:означать;meet:met:met:встречать;mistake:mistook:mistaken:ошибаться;overcome:overcame:overcome:преодолевать;pay:paid:paid:платить;prove:proved:proven:доказывать;put:put:put:класть;quit:quit:quit:бросать;read:read:read:читать;ride:rode:ridden:ездить верхом;ring:rang:rung:звонить;rise:rose:risen:подниматься;run:ran:run:бежать;say:said:said:говорить;see:saw:seen:видеть;seek:sought:sought:искать;sell:sold:sold:продавать;send:sent:sent:отправлять;set:set:set:устанавливать;shake:shook:shaken:трясти;shine:shone:shone:светить;shoot:shot:shot:стрелять;show:showed:shown:показывать;shut:shut:shut:закрывать;sing:sang:sung:петь;sink:sank:sunk:тонуть;sit:sat:sat:сидеть;sleep:slept:slept:спать;slide:slid:slid:скользить;speak:spoke:spoken:говорить;spend:spent:spent:тратить;split:split:split:раскалывать;spread:spread:spread:распространять;stand:stood:stood:стоять;steal:stole:stolen:красть;stick:stuck:stuck:прилипать;strike:struck:struck:ударять;swear:swore:sworn:клясться;swim:swam:swum:плавать;take:took:taken:брать;teach:taught:taught:учить (кого-то);tear:tore:torn:рвать;tell:told:told:рассказывать;think:thought:thought:думать;throw:threw:thrown:бросать;understand:understood:understood:понимать;wake:woke:woken:просыпаться;wear:wore:worn:носить (одежду);win:won:won:выигрывать;write:wrote:written:писать"
    return raw.split(separator: ";").compactMap { p -> IrrVerb? in
        let a = p.split(separator: ":", omittingEmptySubsequences: false).map { String($0) }
        if a.count != 4 { return nil }
        return IrrVerb(base: a[0], past: a[1], pp: a[2], ru: a[3])
    }
}()

func findIrregular(_ word: String) -> IrrVerb? {
    let w = word.lowercased()
    for v in irregularVerbs {
        if v.base == w { return v }
        if v.past.split(separator: "/").map({ String($0) }).contains(w) { return v }
        if v.pp.split(separator: "/").map({ String($0) }).contains(w) { return v }
    }
    return nil
}

func findIrregularIn(_ text: String) -> IrrVerb? {
    let words = text.split(whereSeparator: { !($0.isLetter || $0 == "'") })
    for w in words {
        if let v = findIrregular(String(w)) { return v }
    }
    return nil
}

// MARK: - Состояние приложения и боковая панель

final class AppState: ObservableObject {
    @Published var tab = 0
    @Published var drawer = false
    @Published var settings = false
    @Published var tensePath: [Tense] = []

    func open() { withAnimation(.easeOut(duration: 0.25)) { drawer = true } }
    func close() { withAnimation(.easeOut(duration: 0.25)) { drawer = false } }
}
