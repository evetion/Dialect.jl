register_locale(:de, (:deutsch, :german), [
    "funktion" => "function",
    "ende" => "end",
    "wenn" => "if",
    "sonst" => "else",
    "sonstwenn" => "elseif",
    "für" => "for",
    "in" => "in",
    "während" => "while",
    "abbruch" => "break",
    "fortsetzen" => "continue",
    "rückgabe" => "return",
    "struktur" => "struct",
    "modul" => "module",
    "importiere" => "import",
    "exportiere" => "export",
    "konstante" => "const",
    "istein" => "isa",
])

"""
    istein(x, T)

`isa` für den deutschen Dialekt. Nötig, weil `x istein T` zu einem Aufruf von
`istein` wird und nicht zu `isa(x, T)`.
"""
istein(x, T) = x isa T

"Aktiviere deutsche Julia-Schlüsselwörter."
deutsch() = enable(:de)
export deutsch, istein
