module Dialect

using Preferences

const JuliaSyntax = Base.JuliaSyntax

# Alias word => name of the JuliaSyntax keyword kind it should tokenize as.
const LocaleSpec = Vector{Pair{String,String}}

export active_dialect, disable, enable

# Locale code (e.g. `:nl`) => its aliases.
const LOCALE_SPECS = Dict{Symbol,LocaleSpec}()
# Every accepted spelling of a locale (`:nl`, `:dutch`, ...) => its locale code.
const LOCALE_NAMES = Dict{Symbol,Symbol}()

"""
    register_locale(code, names, specs)

Register a locale under `code` (a language code such as `:nl`), plus the
alternative `names` it may be referred to by. `specs` maps alias words to the
JuliaSyntax keyword kinds they should be tokenized as. Called by the files in
`src/locales`.
"""
function register_locale(code::Symbol, names, specs::LocaleSpec)
    haskey(LOCALE_SPECS, code) && throw(ArgumentError("duplicate locale code: $code"))
    LOCALE_SPECS[code] = specs
    for name in (code, names...)
        haskey(LOCALE_NAMES, name) &&
            throw(ArgumentError("duplicate locale name: $name"))
        LOCALE_NAMES[name] = code
    end
end

# Locales are registered by including every file in `src/locales`, sorted so
# that the load order is reproducible.
for file in sort!(readdir(joinpath(@__DIR__, "locales"); join=true))
    endswith(file, ".jl") && include(file)
end

const _active_dialect = Ref{Union{Nothing,Symbol}}(nothing)
# Keywords this package added to JuliaSyntax's global table for the active
# locale, so they can be removed again by `disable`.
const _installed_keywords = Dict{UInt64,JuliaSyntax.Kind}()
const _previous_parser = Ref{Any}(nothing)
const _installed_parser = Ref{Any}(nothing)
# Guards both the global keyword table and the parser hook, which are shared
# process-wide state.
const _parser_lock = ReentrantLock()

"""
    active_dialect()

Return the enabled locale code, `:files`, or `nothing` when Dialect is disabled.
"""
active_dialect() = _active_dialect[]

"""
    _locale(locale)

Resolve a locale name or code such as `"nl"`, `:dutch` or `"nl_NL.UTF-8"` to
its registered locale code. Throws an `ArgumentError` if unknown.
"""
function _locale(locale)
    name = lowercase(String(locale))
    code = get(LOCALE_NAMES, Symbol(name), nothing)
    if isnothing(code)
        # Fall back to the language part of POSIX-style locales, e.g. `nl_NL@euro`.
        language = first(split(name, r"[-_.@]"))
        code = get(LOCALE_NAMES, Symbol(language), nothing)
    end
    isnothing(code) && throw(ArgumentError("unknown dialect: $locale"))
    return code
end

# Aliases naming a kind that this Julia version doesn't know are skipped, so a
# locale may list keywords from newer (or removed) JuliaSyntax versions.
function _aliases(locale::Symbol)
    Pair{String,JuliaSyntax.Kind}[
        word => JuliaSyntax.Kind(target) for (word, target) in LOCALE_SPECS[locale]
        if haskey(JuliaSyntax._kind_str_to_int, target)
    ]
end

"""
    _install_keywords(locale)

Add `locale`'s aliases to JuliaSyntax's global keyword table and return only
the entries that were actually added, for later removal by
[`_restore_keywords`](@ref). All-or-nothing: on failure the partial changes are
rolled back before rethrowing.
"""
function _install_keywords(locale::Symbol)
    keywords = JuliaSyntax.Tokenize._kw_hash
    installed = Dict{UInt64,JuliaSyntax.Kind}()
    try
        for (word, kind) in _aliases(locale)
            # The hash packs 5 bits per character into a UInt64, so longer
            # words are never looked up by the tokenizer.
            length(word) <= JuliaSyntax.Tokenize.MAX_KW_LENGTH ||
                throw(ArgumentError("dialect keyword is too long for JuliaSyntax: $word"))
            hash = JuliaSyntax.Tokenize.simple_hash(word)
            if haskey(keywords, hash)
                # An alias that maps to itself (e.g. Dutch `module`) is a no-op,
                # but a differing kind means we'd shadow real Julia syntax.
                keywords[hash] == kind ||
                    throw(ArgumentError("dialect keyword collides with an existing keyword: $word"))
                continue
            end
            keywords[hash] = kind
            installed[hash] = kind
        end
    catch
        _restore_keywords(installed)
        rethrow()
    end
    return installed
end

# Undo `_install_keywords`, refusing to touch entries someone else changed.
function _restore_keywords(installed)
    keywords = JuliaSyntax.Tokenize._kw_hash
    for (hash, kind) in installed
        get(keywords, hash, nothing) == kind ||
            error("cannot restore keyword table because it was modified after Dialect")
        delete!(keywords, hash)
    end
end

# Run `f` with only `locale`'s aliases installed, then restore the table.
function _with_locale(f, locale::Symbol)
    lock(_parser_lock) do
        installed = _install_keywords(locale)
        try
            return f()
        finally
            _restore_keywords(installed)
        end
    end
end

"""
    _with_filename_locale(f, locale)

Run the parse `f` under `locale`, where `locale` comes from the filename and
may be `nothing`. When a global locale is active it is swapped out for the
duration of the parse and restored afterwards.
"""
function _with_filename_locale(f, locale)
    mode = _active_dialect[]
    if mode === :files
        # No global locale, so nothing has to be swapped out.
        isnothing(locale) && return f()
        return _with_locale(f, locale)
    end

    lock(_parser_lock) do
        # The keyword table already holds exactly what this parse needs.
        (isnothing(locale) || locale === mode) && return f()
        _restore_keywords(_installed_keywords)
        empty!(_installed_keywords)
        installed = Dict{UInt64,JuliaSyntax.Kind}()
        try
            installed = _install_keywords(locale)
            return f()
        finally
            _restore_keywords(installed)
            merge!(_installed_keywords, _install_keywords(mode))
        end
    end
end

# Recognize a locale suffix such as `algorithm.nl.jl` or `algorithm.nl_NL.jl`.
function _locale_from_filename(filename::AbstractString)
    m = match(r"\.([A-Za-z]{2})(?:_[A-Za-z]{2})?\.jl$", filename)
    isnothing(m) && return nothing
    get(LOCALE_NAMES, Symbol(lowercase(m[1])), nothing)
end

function _preferred_locale()
    setting = @load_preference("locale")
    isnothing(setting) && return nothing
    setting isa AbstractString || throw(ArgumentError(
        "the Dialect locale preference must be a string"))
    return _locale(setting)
end

# Both arities of JuliaSyntax's core parser hook are forwarded, because Julia
# calls the five-argument form for top-level code and the four-argument form
# for e.g. `Meta.parse`.
function _parser_hook(code, filename::String, lineno::Int, offset::Int, options::Symbol)
    locale = _locale_from_filename(filename)
    parser = _previous_parser[]
    _with_filename_locale(locale) do
        parser(code, filename, lineno, offset, options)
    end
end

function _parser_hook(code, filename, offset, options)
    locale = _locale_from_filename(filename)
    parser = _previous_parser[]
    _with_filename_locale(locale) do
        parser(code, filename, offset, options)
    end
end

@static if VERSION >= v"1.14.0-DEV"
    # Julia 1.14 gives Main a syntax-versioned parser that takes precedence
    # over Core._parse. Extend its dispatcher without replacing that parser.
    function Base.MainInclude.var"#_internal_julia_parse"(
            code, filename::String, lineno::Int, offset::Int, options::Symbol)
        parser = Base.MainInclude.main_parser[]
        isnothing(_active_dialect[]) &&
            return parser(code, filename, lineno, offset, options)
        locale = _locale_from_filename(filename)
        return _with_filename_locale(locale) do
            parser(code, filename, lineno, offset, options)
        end
    end
end

function _install_parser()
    isnothing(_installed_parser[]) ||
        error("Dialect's parser is already installed")
    _previous_parser[] = Core._parse
    # `invokelatest` keeps the hook usable when locales are (re)defined at runtime.
    _installed_parser[] = Base.Fix1(Base.invokelatest, _parser_hook)
    Core._setparser!(_installed_parser[])
end

"""
    enable()
    enable(locale)

With a locale, extend Julia's bundled JuliaSyntax keyword table for the whole
process. Without one, read `[Dialect] locale` from `LocalPreferences.toml`
beside the active project once. If no preference is set, select a locale per
parse from a `.nl.jl`/`.de.jl` filename. Dialect calls `enable()` automatically
when loaded.
"""
function enable(locale)
    lock(_parser_lock) do
        code = _locale(locale)
        mode = _active_dialect[]
        mode === code && return nothing
        # Automatic selection installed the parser hook without any keywords;
        # tear it down so the locale can be installed from a clean state.
        mode === :files && disable()
        isnothing(_active_dialect[]) ||
            throw(ArgumentError("disable the active dialect before enabling another"))
        installed = _install_keywords(code)
        try
            _install_parser()
        catch
            _restore_keywords(installed)
            rethrow()
        end
        merge!(_installed_keywords, installed)
        _active_dialect[] = code
    end
    return nothing
end

function enable()
    lock(_parser_lock) do
        !isnothing(_active_dialect[]) && return nothing
        locale = _preferred_locale()
        !isnothing(locale) && return enable(locale)
        _install_parser()
        _active_dialect[] = :files
    end
    return nothing
end

"""
    disable()

Remove installed aliases and restore the parser used before automatic
selection was enabled.
"""
function disable()
    lock(_parser_lock) do
        mode = _active_dialect[]
        isnothing(mode) && return nothing
        Core._parse === _installed_parser[] ||
            error("cannot disable Dialect because another parser was installed after it")
        Core._setparser!(_previous_parser[])
        _previous_parser[] = nothing
        _installed_parser[] = nothing
        if mode !== :files
            _restore_keywords(_installed_keywords)
            empty!(_installed_keywords)
        end
        _active_dialect[] = nothing
    end
    return nothing
end

function __init__()
    # Loading Dialect opts in to automatic selection; see `enable`.
    enable()
end

end
