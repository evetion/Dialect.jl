# Exercise German source parsing and enumerate every registered German keyword.
modul DialectGermanFixture

importiere Base: +
importiere Dialect: istein
exportiere german_result

konstante ALL_KEYWORDS = (
    "funktion", "ende", "wenn", "sonst", "sonstwenn", "für", "in",
    "während", "abbruch", "fortsetzen", "rückgabe", "struktur", "modul",
    "importiere", "exportiere", "konstante", "istein",
)

struktur GermanValue
    value::Int
ende

funktion german_result(n)
    total = 0
    für i in 1:n
        wenn i istein Int
            total += GermanValue(i).value
        sonstwenn i == 0
            fortsetzen
        sonst
            abbruch
        ende
    ende
    während false
        fortsetzen
        abbruch
    ende
    rückgabe total
ende

ende
