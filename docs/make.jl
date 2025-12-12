using ParameterSets
using Documenter

DocMeta.setdocmeta!(ParameterSets, :DocTestSetup, :(using ParameterSets); recursive=true)

makedocs(;
    modules=[ParameterSets],
    authors="Sliem el Ela <sliemelela@gmail.com>",
    sitename="ParameterSets.jl",
    format=Documenter.HTML(;
        canonical="https://sliemelela.github.io/ParameterSets.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(;
    repo="github.com/sliemelela/ParameterSets.jl",
    devbranch="main",
)