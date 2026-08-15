register_locale(:nl, (:dutch, :nederlands), [
    "kaalmodule" => "baremodule",
    "begin" => "begin",
    "breek" => "break",
    "vang" => "catch",
    "vast" => "const",
    "verder" => "continue",
    "doe" => "do",
    "anders" => "else",
    "andersals" => "elseif",
    "einde" => "end",
    "exporteer" => "export",
    "eindelijk" => "finally",
    "voor" => "for",
    "functie" => "function",
    "globaal" => "global",
    "als" => "if",
    "importeer" => "import",
    "laat" => "let",
    "lokaal" => "local",
    "macro" => "macro",
    "module" => "module",
    "openbaar" => "public",
    "quote" => "quote",
    "terug" => "return",
    "structuur" => "struct",
    "probeer" => "try",
    "typegroep" => "typegroup",
    "gebruik" => "using",
    "zolang" => "while",
    "in" => "in",
    "iseen" => "isa",
    "waar" => "where",
    "abstract" => "abstract",
    "genaamd" => "as",
    "document" => "doc",
    "ganaar" => "goto",
    "wijzigbaar" => "mutable",
    "buitenste" => "outer",
    "primitief" => "primitive",
    "type" => "type",
    "variabele" => "var",
    "VERSIE" => "VERSION",
])

"""
    iseen(x, T)

`isa` voor het Nederlandse dialect. Nodig omdat `x iseen T` een aanroep van
`iseen` wordt en niet `isa(x, T)`.
"""
iseen(x, T) = x isa T

"Schakel Nederlandse Julia-sleutelwoorden in."
nederlands() = enable(:nl)
export nederlands, iseen
