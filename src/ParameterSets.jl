module ParameterSets

using YAML
using JSON
using CSV
using DataFrames
using PrettyTables

include("structs.jl")
include("generator.jl")
include("reporting.jl")

export load_sets, save_sensitivity_reports

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

end