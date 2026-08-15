# Dialect

[![Build Status](https://github.com/evetion/Dialect.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/evetion/Dialect.jl/actions/workflows/CI.yml?query=branch%3Amain)

Inspired by [Felienne Hermans](https://github.com/Felienne) and her multi-lingual programming language [Hedy](https://www.hedy.org/).

Why does one need to learn English to program?
Dialect adds localized aliases for Julia keywords for fun and educational purposes.
Standard Julia spellings remain valid. Currently implements Nederlands and Deutsch.
Contributions are welcome!


```julia
using Dialect
nederlands()

functie som(n)
    totaal = 0
    voor i in 1:n
        totaal += i
    einde
    terug totaal
einde
```

`deutsch()` enables German aliases. The equivalent language-code calls are
`enable(:nl)` and `enable(:de)`; locale names such as `enable("nl_NL.UTF-8")`
work too. `active_dialect()` returns the active locale code, and `disable()`
removes the aliases and restores the original parser.

Dialect requires Julia 1.13 or newer, because it installs a parser through
`Core._setparser!`.

## Automatic selection

Loading Dialect opts in to automatic selection:

```julia
using Dialect
```

At load time, it checks for `LocalPreferences.toml`.

```toml
[Dialect]
locale = "nl"
```

Preferences are loaded through
[Preferences.jl](https://github.com/JuliaPackaging/Preferences.jl), so they can
also be inherited from environments higher in the load path. They can be set
programmatically before restarting Julia:

```julia
using Dialect, Preferences
set_preferences!(Dialect, "locale" => "nl")
```

The preference is read once and enables that locale for the process. A locale
suffix on a filename takes precedence for that file, whether or not a global
locale is configured:

```julia
include("algorithm.nl.jl")
include("algorithm.de.jl")
```

Filename-based parsing temporarily changes Julia's global keyword table under
a lock, then restores the configured global locale. Explicit `nederlands()`,
`deutsch()`, or a local preference determines the default for the REPL and
files without a locale suffix, and also lets REPL syntax highlighting see the
localized keywords.

## Limitations

Dialect currently extends the private `Base.JuliaSyntax.Tokenize._kw_hash`
table and installs a parser through the private `Core._setparser!` API. These
internals may change between Julia versions. Explicitly enabled aliases also
modify a process-global keyword table; filename-based parsing serializes its
temporary changes with a lock.

JuliaSyntax's keyword hash was designed for ASCII keywords of at most ten
characters. Non-ASCII aliases can appear to work, but the hash does not
distinguish different non-ASCII characters in the same position. For example,
enabling German makes `für` a `for` token, but also incorrectly makes `får`,
`főr`, and `fЖr` `for` tokens. Unicode aliases are therefore not safe with the
current approach, even though the German locale currently ships a few (`für`,
`während`, `rückgabe`).

Not every entry in JuliaSyntax's keyword list is a structural keyword. In
particular, `isa` is a word operator whose source spelling is retained during
conversion to an expression: `x iseen T` becomes a call to `iseen`, not
`isa(x, T)`. Dialect therefore exports `iseen(x, T)` and `istein(x, T)`, which
simply forward to `isa`, so the aliases behave as expected.

Aliases naming a keyword kind that the running Julia version does not know are
silently skipped, which keeps locale files portable across versions. In Julia
1.13 this drops the Dutch `typegroep`, `ganaar`, and `VERSIE`.

Conversion to `Expr` also discards localized spellings for structural
keywords: a function written with `functie` displays as `function`. The
original spelling remains available only in source-backed JuliaSyntax trees.


## Related
[LocalizedLiterals.jl](https://github.com/henrik-wolf/LocalisedLiterals.jl) provides string literals (`fr"Hello World"`) that are used to automatically translate via Google Translate.
