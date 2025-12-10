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
        # Recurse into lists of objects (e.g., your "Processes" list)
        for (i, v) in enumerate(node)
             push!(paths, find_vector_paths(v, [current_path; string(i)])...)
        end
    end
    return paths
end

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