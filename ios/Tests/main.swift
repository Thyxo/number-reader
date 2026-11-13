// Én hurtig test af T9-afkodningen og regnemetoden (køres i GitHub Actions med swiftc, uden simulator).
import Foundation

var fails = 0
func check(_ ok: Bool, _ msg: String) { if !ok { fails += 1; print("FEJL: \(msg)") } }

let data = WordData.load(from: URL(fileURLWithPath: CommandLine.arguments[1]))
check(data.words.count == 25000, "ordbogen mangler (\(data.words.count) ord)")
let idx = T9Index(data: data)
func top(_ w: String) -> String { idx.decode(T9.toDigits(w), max: 3).first?.text ?? "" }

check(T9.toDigits("Kim Larsen") == "546527736", "toDigits")
check(T9.toDigits("Æble") == "2253" && T9.toDigits("Åge") == "243" && T9.toDigits("Søren") == "76736", "Æ/Å = 2, Ø = 6")
for n in ["Kim Larsen", "Mads Mikkelsen", "Taylor Swift", "Mette Frederiksen", "Caroline Wozniacki"] { check(top(n) == n, "kendt: \(n) → \(top(n))") }
check(top("Mette Jensen") == "Mette Jensen", "fornavn + efternavn")
check(idx.decode(T9.toDigits("Kim") + "0" + T9.toDigits("Larsen")).first?.text == "Kim Larsen", "0 = mellemrum")
check(T9Index(data: data, custom: ["Fido"]).decode(T9.toDigits("Fido")).first?.text == "Fido", "egne navne først")

// Udvidet ordbog + kvalificeret gæt
let big = T9Index(data: data, extra: true)
check(big.decode(T9.toDigits("Bjarne Stroustrup")).first?.text == "Bjarne Stroustrup", "udvidet: kendte fra Wikidata")
check(big.decode(T9.toDigits("Kim Larsen")).first?.text == "Kim Larsen", "udvidet: håndplukkede vinder stadig")
check(big.decode(T9.toDigits("Nedfaldsfrugt")).contains { $0.text == "Nedfaldsfrugt" }, "udvidet: Stavekontrolden-ord")
check(big.decode("43555").first?.kind == "guess", "gæt: tal uden match giver et bud")
check(!big.decode("2398574365").isEmpty, "gæt: altid et bud")

let r = Force.solve("3662538786", "140646")
check(r.neg && Force.add(r.a, "140646") == "3662538786", "regnemetode negativ")
check(Force.solve("54652736", "99999999") == ("45347263", false), "regnemetode")
check(Force.fmtDate(Force.parseDate("1946-06-14")!, "yyyymmdd") == "19460614", "datoformat")
check(Force.target(src: "birthday", fmt: "ddmmyyyy", name: "Bedstemor", custom: ["Bedstemor | 3.4.1950"]).y == "03041950", "fødselsdag fra egne navne")

print(fails == 0 ? "Alle tests OK" : "\(fails) fejl")
exit(fails == 0 ? 0 : 1)
