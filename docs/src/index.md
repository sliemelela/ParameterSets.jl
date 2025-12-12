# ParameterSets.jl

*Generate and manage simulation parameter sets from YAML/JSON configurations.*

**ParameterSets.jl** is a tool designed to help you run One-at-a-Time (OAT) sensitivity analyses.
It reads a configuration file (YAML or JSON), detects lists of values, and automatically generates a
 baseline parameter set plus variations for every change defined.

## Installation
The package is not yet in the General Registry, so you can install it via Git:

```julia
using Pkg
Pkg.add(url="https://github.com/sliemelela/ParameterSets.jl")
```

# Quick Start
Create a simple YAML configuration file named config.yaml:
```YAML
# Baseline values
interest_rate: 0.05
inflation: 0.02

# Parameters to vary (Sensitivity Analysis)
initial_capital:
  sensitivity: [1000, 2000, 5000]
```

Then load it in Julia:

```julia
using ParameterSets

# Load the sets (Baseline + 3 Variations)
sets = load_sets("config.yaml")

# Iterate and Simulate
results = Dict{Int, Dict{String, Any}}()

for p in sets
    # Your simulation logic here...
    val = p.config["initial_capital"] * (1 + p.config["interest_rate"])

    # Store results (required for reporting)
    results[p.id] = Dict("FutureValue" => val)
end

# Save Reports (CSV/Markdown/LaTeX)
save_sensitivity_reports(sets, results)
```
