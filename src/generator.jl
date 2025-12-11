"""
    generate_sets(config_data::Dict)

Takes a raw configuration dictionary, finds any sensitivity vectors,
and expands them into a list of `ParameterSet` objects (Baseline + Variations).
"""
function generate_sets(config_data::Dict{String, Any})
    # 1. Identify all parameters that need variation
    vector_paths = find_vector_paths(config_data)

    sets = Vector{ParameterSet}()

    # 2. Create and Store Baseline
    # The baseline uses the FIRST value of every sensitivity vector found.
    baseline_config = deepcopy(config_data)
    for (path, vec) in vector_paths
        set_nested_value!(baseline_config, path, vec[1])
    end

    # ID 1 is always Baseline
    push!(sets, ParameterSet(1, baseline_config, "Baseline", "Base", true))

    # 3. Create Variations (One-at-a-Time)
    id_counter = 2
    for (path, vec) in vector_paths
        group_name = join(path, ".")

        # We iterate through variations, skipping the first (baseline) value
        for val in vec[2:end]
            new_config = deepcopy(baseline_config)
            set_nested_value!(new_config, path, val)

            push!(sets, ParameterSet(id_counter, new_config, group_name, val, false))
            id_counter += 1
        end
    end

    return sets
end

# --- Internal Recursion Helpers ---
"""
    find_vector_paths(node, current_path=String[])

Recursively scans a nested configuration structure (Dictionaries and Vectors) to find parameters
marked for sensitivity analysis.

It looks for specific "leaf" nodes structured as `Dict("sensitivity" => [val1, val2, ...])`.
When found, it stops recursing down that branch and records the path.

# Arguments
- `node`: The current level of the config structure (initially the root `Dict`).
- `current_path`: An accumulator vector of Strings representing the keys/indices traversed so far.

# Returns
- `Vector{Tuple}`: A list of found sensitivity parameters. Each element is a tuple
`(path, values_vector)`, where:
    - `path`: A `Vector{String}` of keys/indices leading to the parameter.
    - `values_vector`: The list of values defined in the "sensitivity" block.
"""
function find_vector_paths(node, current_path=String[])
    paths = []
    if node isa Dict
        # Check for explicit sensitivity flag: { "sensitivity": [1, 2, 3] }
        if haskey(node, "sensitivity") && node["sensitivity"] isa Vector
            push!(paths, (current_path, node["sensitivity"]))
        else
            # Recurse deeper
            for (k, v) in node
                # We enforce String keys for consistency
                push!(paths, find_vector_paths(v, [current_path; string(k)])...)
            end
        end
    elseif node isa Vector
        # Recurse into lists of objects
        for (i, v) in enumerate(node)
             push!(paths, find_vector_paths(v, [current_path; string(i)])...)
        end
    end
    return paths
end


"""
    set_nested_value!(config_dict, path, value)

Navigates a nested configuration structure using a path vector and modifies the target value in-place.

This function is robust to mixed structures of Dictionaries and Vectors.
It automatically detects if a node is a Vector and parses the path key
(which is a String) back into an Integer index.

# Arguments
- `config_dict`: The root configuration dictionary (will be modified).
- `path`: A `Vector{String}` representing the sequence of keys/indices to navigate.
- `value`: The new value to set at the target location.

# Example
If `path` is `["Stock_S", "2", "volatility"]`:
1. Looks up `config_dict["Stock_S"]`.
2. Sees the result is a Vector, so parses "2" -> index `2`.
3. Looks up index 2.
4. Sets the key `"volatility"` to `value`.
"""
function set_nested_value!(config_dict, path, value)
    d = config_dict
    # Navigate to the parent container
    for i in 1:(length(path) - 1)
        key = path[i]

        if d isa Vector
            idx = parse(Int, key)
            d = d[idx]
        else
            d = d[key]
        end
    end

    # Set the value at the target
    last_key = path[end]
    if d isa Vector
        d[parse(Int, last_key)] = value
    else
        d[last_key] = value
    end
end