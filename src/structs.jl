export ParameterSet

"""
    ParameterSet

A distinct configuration of parameters generated from a baseline.
"""
struct ParameterSet
    id::Int
    config::Dict{String, Any}   # The full configuration dictionary
    label::String               # What changed? (e.g. "Parameters.Stock_S.b")
    value::Any                  # The specific value of that change (e.g. 6)
    is_baseline::Bool           # Is this the reference set?
end