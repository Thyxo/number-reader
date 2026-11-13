// Indstillinger – samme nøgler og standardværdier som DEFAULTS i src/app.js. Gemmes i UserDefaults.
import Foundation

struct Settings: Codable, Equatable {
    var mode = "pad"           // pad | calc
    var peekText = true        // svag tekst (fanerne / over home-baren / mellem ikonerne)
    var peekLevel = 2          // 1 næsten usynlig · 2 svag · 3 tydelig
    var peekAlts = 0           // antal alternativer i peek-teksten
    var screenColor = "black"  // peek-skærm: black | white
    var screenHold = "2"       // "2" = 2 sek. · "tap" = til der trykkes
    var screenAlts = true      // alternativer på peek-skærmen
    var autoScan = false       // start kameraet når appen åbner
    var confirm = 2            // samme tal læst så mange gange
    var minLen = 3
    var timeout = 30
    var region = "center"      // center | full
    var viewfinder = false
    var dCelebs = true
    var dNames = true
    var dWords = true
    var custom = ""
    var tones = true
    var typedPeek = true       // tal tastet på blokken dekodes også
    var showScanned = true     // vis det scannede tal i nummerfeltet
    var vAdjust = 0
    var peekWhere = "tabs"     // numerisk blok: tabs = navnet i fanernes tekst · line = over home-baren
    var tab3Peek = true        // fødselsdag / mål (y) i 3. fane
    var force = false          // regnemetoden y − x = a
    var forceSrc = "birthday"  // birthday | today | clock | fixed
    var forceFmt = "ddmmyy"
    var clockAdd = 2
    var forceFixed = ""
    var debug = true           // gem de sidste billeder til debug-visningen
    var dExtra = true          // udvidet ordbog: 7.000 kendte, 6.000 navne, 190.000 ord
    var guess = true           // kvalificeret gæt, når intet passer
    var volumeScan = true      // volumen op = start scanning · volumen ned = stop

    init() {}

    // Manglende nøgler (fx efter en opdatering) får standardværdien
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? def }
        mode = v(.mode, d.mode); peekText = v(.peekText, d.peekText); peekLevel = v(.peekLevel, d.peekLevel)
        peekAlts = v(.peekAlts, d.peekAlts); screenColor = v(.screenColor, d.screenColor); screenHold = v(.screenHold, d.screenHold)
        screenAlts = v(.screenAlts, d.screenAlts); autoScan = v(.autoScan, d.autoScan); confirm = v(.confirm, d.confirm)
        minLen = v(.minLen, d.minLen); timeout = v(.timeout, d.timeout); region = v(.region, d.region)
        viewfinder = v(.viewfinder, d.viewfinder); dCelebs = v(.dCelebs, d.dCelebs); dNames = v(.dNames, d.dNames)
        dWords = v(.dWords, d.dWords); custom = v(.custom, d.custom); tones = v(.tones, d.tones)
        typedPeek = v(.typedPeek, d.typedPeek); showScanned = v(.showScanned, d.showScanned); vAdjust = v(.vAdjust, d.vAdjust)
        peekWhere = v(.peekWhere, d.peekWhere); tab3Peek = v(.tab3Peek, d.tab3Peek); force = v(.force, d.force)
        forceSrc = v(.forceSrc, d.forceSrc); forceFmt = v(.forceFmt, d.forceFmt); clockAdd = v(.clockAdd, d.clockAdd)
        forceFixed = v(.forceFixed, d.forceFixed); debug = v(.debug, d.debug)
        dExtra = v(.dExtra, d.dExtra); guess = v(.guess, d.guess); volumeScan = v(.volumeScan, d.volumeScan)
    }

    static let key = "nr.settings.v1"

    static func load() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Settings.key) }
    }

    /// Egne navne, én pr. linje ("Navn | 14.06.1946")
    var customLines: [String] {
        custom.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
