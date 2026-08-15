# Exercise Dutch source parsing and enumerate every registered Dutch keyword.
kaalmodule DialectDutchBareFixture
vast value = 1
einde

module DialectDutchFixture

gebruik Base
importeer Base: + genaamd optellen

exporteer dutch_result
openbaar DutchValue

vast ALL_KEYWORDS = (
    "kaalmodule", "begin", "breek", "vang", "vast", "verder", "doe",
    "anders", "andersals", "einde", "exporteer", "eindelijk", "voor",
    "functie", "globaal", "als", "importeer", "laat", "lokaal", "macro",
    "module", "openbaar", "quote", "terug", "structuur", "probeer",
    "typegroep", "gebruik", "zolang", "in", "iseen", "waar", "abstract",
    "genaamd", "document", "ganaar", "wijzigbaar", "buitenste",
    "primitief", "type", "variabele", "VERSIE",
)

vast BEGIN_VALUE = begin
    1
einde

abstract type AbstractDutchFixture einde

primitief type DutchBitsFixture 8 einde

structuur DutchValue
    value::Int
einde

wijzigbaar structuur MutableDutchValue
    value::Int
einde

macro een()
    quote
        1
    einde
einde

vast ISA_SYNTAX = quote
    value iseen Int
    voor buitenste i in 1:0
    einde
einde

functie identiteit(x::T) waar T
    terug x
einde

functie dutch_result(n)
    globaal dutch_global = 0
    lokaal total = 0
    mapped = map(1:n) doe x
        x
    einde
    laat limit = length(mapped)
        voor i in 1:limit
            als mapped[i] isa Int
                total = optellen(total, mapped[i])
            andersals false
                total = -1
            anders
                total = 0
            einde
        einde
    einde
    zolang false
        verder
        breek
    einde
    probeer
        total += @een
    vang
        total = -1
    eindelijk
        dutch_global = total
    einde
    terug identiteit(total)
einde

einde
