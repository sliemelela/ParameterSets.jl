module ParameterSets

using YAML
using JSON
using DataFrames

include("structs.jl")
include("generator.jl")

export load_sets, sets_to_dataframe

"""
    load_sets(path::String)

Reads a configuration file (.yaml or .json), parses it into a Dictionary,
and generates a list of `ParameterSet` objects.
"""
function load_sets(path::String)
    if !isfile(path)
        error("File not found: $path")
    end

    raw_config = Dict{String, Any}()

    # Dispatch based on extension
    if endswith(path, ".yaml") || endswith(path, ".yml")
        # dicttype=Dict{String,Any} ensures keys are Strings, not Symbols/Any
        raw_config = YAML.load_file(path; dicttype=Dict{String, Any})

    elseif endswith(path, ".json")
        raw_config = JSON.parsefile(path; dicttype=Dict{String, Any})

    else
        error("Unsupported file format: $(path). Please use .yaml or .json")
    end

    return generate_sets(raw_config)
end

"""
    sets_to_dataframe(sets::Vector{ParameterSet})

Returns a DataFrame summarizing the generated sets (ID, Label, Value).
Useful for inspecting your experiment design before running it.
"""
function sets_to_dataframe(sets::Vector{ParameterSet})
    return DataFrame(
        ID = [s.id for s in sets],
        Label = [s.label for s in sets],
        Value = [s.value for s in sets],
        Type = [s.is_baseline ? "Baseline" : "Variation" for s in sets]
    )
end

end