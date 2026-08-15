using Dialect
using JuliaSyntaxHighlighting
using Test

const JS = Base.JuliaSyntax

@testset "Automatic activation" begin
    @test active_dialect() === :files
    disable()
    @test active_dialect() === nothing
end

@testset "Localized entry points" begin
    for (entrypoint, expected) in ((nederlands, :nl), (deutsch, :de))
        try
            entrypoint()
            @test active_dialect() === expected
        finally
            disable()
        end
    end
end

@testset "Dutch keyword aliases" begin
    previous_parser = Core._parse
    aliases = Dialect._aliases(:nl)
    try
        enable(:nl)
        @test active_dialect() === :nl
        for (word, expected) in aliases
            token = first(JS.Tokenize.tokenize(word))
            @test token.kind == expected
        end

        code = """
        functie som(n)
            totaal = 0
            voor i in 1:n
                als i > 0
                    totaal += i
                anders
                    totaal -= i
                einde
            einde
            terug totaal
        einde
        """
        @test Meta.isexpr(Meta.parse(code), :function)
        annotations = Base.annotations(JuliaSyntaxHighlighting.highlight(code))
        @test any(a -> a.region == 1:7 && a.value == :julia_keyword, annotations)
    finally
        disable()
    end
    @test Core._parse === previous_parser
    @test active_dialect() === nothing
end

@testset "Word operator aliases" begin
    # `isa` keeps its source spelling, so the aliases parse as ordinary calls
    # and need a matching function to behave like `isa`.
    @test iseen(1, Int)
    @test !iseen(1, String)
    @test istein(1, Int)
    @test !istein(1, String)
    try
        enable(:nl)
        @test Meta.parse("x iseen Int") == :(iseen(x, Int))
        @test Base.invokelatest(eval, Meta.parse("1 iseen Int"))
    finally
        disable()
    end
end

@testset "Locale detection" begin
    @test Dialect._locale_from_filename("example.nl.jl") === :nl
    @test Dialect._locale_from_filename("example.nl_NL.jl") === :nl
    @test Dialect._locale_from_filename("example.de.jl") === :de
    @test Dialect._locale_from_filename("example.jl") === nothing

    @test Dialect._preferred_locale() === nothing
    try
        Dialect.Preferences.set_preferences!(Dialect, "locale" => "nl"; force=true)
        @test Dialect._preferred_locale() === :nl
    finally
        Dialect.Preferences.set_preferences!(Dialect, "locale" => missing; force=true)
    end
end

@testset "Automatic filename routing" begin
    previous_parser = Core._parse
    keyword_hash = JS.Tokenize.simple_hash("functie")
    @test !haskey(JS.Tokenize._kw_hash, keyword_hash)
    try
        enable()
        enable()
        @test active_dialect() === :files
        for (locale, fixture, mod, result) in (
            (:nl, "all.nl.jl", :DialectDutchFixture, 7),
            (:de, "all.de.jl", :DialectGermanFixture, 6),
        )
            Base.include(Main, joinpath(@__DIR__, "locales", fixture))
            fixture_module = Base.invokelatest(getfield, Main, mod)
            result_function = Base.invokelatest(
                getfield, fixture_module,
                Symbol(locale === :nl ? "dutch_result" : "german_result"))
            @test Base.invokelatest(result_function, 3) == result
            fixture_keywords = Base.invokelatest(getfield, fixture_module, :ALL_KEYWORDS)
            @test Set(fixture_keywords) == Set(first.(Dialect.LOCALE_SPECS[locale]))
            Dialect._with_locale(locale) do
                for (word, expected) in Dialect._aliases(locale)
                    @test first(JS.Tokenize.tokenize(word)).kind == expected
                end
            end
        end
        @test !haskey(JS.Tokenize._kw_hash, keyword_hash)
    finally
        disable()
    end
    @test Core._parse === previous_parser
    @test active_dialect() === nothing
end

@testset "Filename overrides global locale" begin
    previous_parser = Core._parse
    try
        enable(:nl)
        host = Module(:DialectGlobalOverrideTest)
        Base.include(host, joinpath(@__DIR__, "locales", "all.de.jl"))
        fixture_module = Base.invokelatest(getfield, host, :DialectGermanFixture)
        result_function = Base.invokelatest(getfield, fixture_module, :german_result)
        @test Base.invokelatest(result_function, 3) == 6
        @test active_dialect() === :nl
        @test Meta.isexpr(Meta.parse("functie restored() 1 einde"), :function)
        @test first(JS.Tokenize.tokenize("funktion")).kind == JS.K"Identifier"
    finally
        disable()
    end
    @test Core._parse === previous_parser
    @test active_dialect() === nothing
end
