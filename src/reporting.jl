using DataFrames
using PrettyTables
using CSV

export generate_sensitivity_tables, save_sensitivity_reports

"""
    export_single_table(df::DataFrame, filename_base::String; formats)

Internal helper that iterates through the requested `formats` (e.g., `[:csv, :latex]`) and dispatches
to the appropriate `save_table_format` method to save the DataFrame to disk.
"""
function export_single_table(df::DataFrame, filename_base::String; formats)
    for fmt in formats
        save_table_format(Val(fmt), df, filename_base)
    end
end

function save_table_format(::Val{:csv}, df, filename_base)
    path = "$filename_base.csv"
    CSV.write(path, df)
    println("  ✓ Saved CSV: $path")
end

function save_table_format(::Val{:markdown}, df, filename_base)
    path = "$filename_base.md"
    open(path, "w") do f
        pretty_table(f, df; backend = :markdown)
    end
    println("  ✓ Saved Markdown: $path")
end

function save_table_format(::Val{:latex}, df, filename_base)
    path = "$filename_base.tex"
    open(path, "w") do f
        # We look for the "Baseline" keyword in the first column to bold the row
        hl_base = LatexHighlighter(
            (data, i, j) -> occursin("Baseline", string(data[i, 1])),
            ["textbf"]
        )

        pretty_table(f, df;
            backend = :latex,
            highlighters = [hl_base]
        )
    end
    println("  ✓ Saved LaTeX: $path")
end

# Fallback for unknown formats
function save_table_format(::Val{Unknown}, df, filename_base) where Unknown
    @warn "Skipping unknown format: :$Unknown. (Did you misspell it?)"
end



"""
    generate_sensitivity_tables(sets::Vector{ParameterSet}, results::Dict{Int, Dict{String, Any}})

Transforms raw simulation results into formatted DataFrames suitable for reporting.

This function groups the results by the parameter being varied (the "label"). For each group,
it creates a DataFrame containing:
1. A **Baseline Row**: Shows the baseline value of the parameter and the metrics for the baseline run.
2. **Variation Rows**: Shows the varied values and their corresponding metrics.
3. **Merged Metrics**: Combines the parameter value and all result metrics into columns.

# Arguments
- `sets`: A list of `ParameterSet` objects (usually returned by `load_sets`).
- `results`: A dictionary mapping the set ID (`Int`) to a dictionary of metrics (`String` => `Any`).
    - Example: `Dict(1 => Dict("NPV" => 100.0, "Risk" => 0.05), 2 => ...)`

# Returns
- `Dict{String, DataFrame}`: A dictionary where keys are the parameter labels (e.g., "Interest_Rate")
   and values are the corresponding DataFrames.
"""
function generate_sensitivity_tables(sets::Vector{ParameterSet}, results::Dict{Int, Dict{String, Any}})

    # Locate the Baseline
    baseline_set = only(filter(s -> s.is_baseline, sets))
    baseline_metrics = results[baseline_set.id]

    # Identify labels
    unique_labels = unique([s.label for s in sets if !s.is_baseline])

    tables = Dict{String, DataFrame}()

    for label in unique_labels
        group_sets = filter(s -> s.label == label, sets)
        sort!(group_sets, by = x -> x.value)

        # Get Baseline Value
        baseline_val = get_value_from_config(baseline_set.config, label)

        # --- Create Dynamic Column Name ---
        col_name = "Variation in $label"

        rows = []

        # Add Baseline Row
        # FIX: Explicitly type as Dict{String, Any} so it accepts numbers later
        base_row_data = Dict{String, Any}(col_name => "$baseline_val (Baseline)")
        merge!(base_row_data, baseline_metrics)
        push!(rows, base_row_data)

        # Add Variation Rows
        for s in group_sets
            if !haskey(results, s.id)
                continue
            end

            # FIX: Explicitly type as Dict{String, Any}
            row_data = Dict{String, Any}(col_name => string(s.value))
            merge!(row_data, results[s.id])
            push!(rows, row_data)
        end

        # Convert to DataFrame
        df = DataFrame(rows)

        # Reorder columns
        metric_keys = sort(collect(keys(baseline_metrics)))
        desired_order = vcat([col_name], metric_keys)

        # Ensure only existing columns are selected
        final_cols = intersect(desired_order, names(df))
        select!(df, final_cols)

        tables[label] = df
    end

    return tables
end

"""
    get_value_from_config(config, label_path::String)

Internal helper to retrieve a specific value from a nested configuration using a dot-notation path.
Handles both Dictionary keys and Vector indices (e.g., "Process.1.volatility").
"""
function get_value_from_config(config, label_path)
    keys = split(label_path, ".")
    val = config
    for k in keys
        if val isa Dict
            val = val[k]
        elseif val isa Vector
            val = val[parse(Int, k)]
        end
    end
    return val
end

"""
    save_sensitivity_reports(sets, results; output_dir=".", formats=[:csv, :markdown, :latex])

High-level function to generate and save sensitivity analysis reports.

It performs the following steps:
1. Calls `generate_sensitivity_tables` to organize the data.
2. Creates the `output_dir` if it doesn't exist.
3. Saves each table in the requested `formats`.

# Arguments
- `sets`: Vector of `ParameterSet` objects.
- `results`: Dictionary mapping set IDs to metrics.

# Example of `results` Structure
The `results` dictionary must map the **Set ID** (`Int`) to a dictionary of **Metrics**
(`String` => `Any`).

```juliadocs
results = Dict(
    # Set ID 1 (Baseline)
    1 => Dict(
        "NPV" => 100.50,
        "Risk_Score" => 0.05
    ),

    # Set ID 2 (Variation 1)
    2 => Dict(
        "NPV" => 98.20,
        "Risk_Score" => 0.04
    ),

    # ... etc
)
```
# Keyword Arguments
- output_dir: Directory where files will be saved (default: current directory).
- formats: Vector of formats to save. Supported: :csv, :markdown, :latex.

# Returns
- Dict{String, DataFrame}: The generated tables, useful if you want to inspect or plot them immediately in your script.
"""
function save_sensitivity_reports(sets::Vector{ParameterSet}, results::Dict{Int, Dict{String, Any}};
                                  output_dir=".", formats=[:csv, :markdown, :latex])

    tables = generate_sensitivity_tables(sets, results)
    mkpath(output_dir)
    println("Generating reports in '$output_dir'...")

    for (label, df) in tables
        safe_label = replace(label, "." => "_")
        filename = joinpath(output_dir, "sensitivity_$(safe_label)")

        export_single_table(df, filename; formats=formats)
        println("  ✓ Saved table for: $label")
    end

    return tables
end