using Test
using ParameterSets

@testset "Internal: find_vector_paths" begin
    # Define a simple config to test discovery
    config = Dict{String, Any}(
        "a" => 1,
        "b" => Dict{String, Any}("sensitivity" => [1, 2]),
        "c" => Dict{String, Any}("sensitivity" => [3, 4])
    )

    # Call the internal function
    paths = ParameterSets.find_vector_paths(config)

    # We expect 2 paths found
    @test length(paths) == 2

    # Extract just the path labels (e.g., "b", "c") to verify presence
    # We use a Set to ignore order, since Dict iteration is random
    found_keys = Set(p[1][1] for p in paths)

    @test "b" in found_keys
    @test "c" in found_keys
end

@testset "Internal: generate_sets" begin

    # Mock Data: A dictionary that looks like a loaded YAML
    mock_config = Dict{String, Any}(
        "a" => 1,
        "b" => Dict{String, Any}(
            "sensitivity" => [10, 20, 30]
        ),
        "c" => Dict{String, Any}(
            "deep" => Dict{String, Any}(
                "sensitivity" => ["x", "y"]
            )
        )
    )

    # Generate
    # Baseline: b=10, c.deep="x"
    # Var 1: b=20
    # Var 2: b=30
    # Var 3: c.deep="y"
    sets = ParameterSets.generate_sets(mock_config)

    @test length(sets) == 4

    # Verify Baseline (Guaranteed to be first)
    base = sets[1]
    @test base.is_baseline == true
    @test base.config["b"] == 10
    @test base.config["c"]["deep"] == "x"

    # Verify 'b' variations exist (Order Agnostic)
    # We look for a set where label is "b" and value is 20
    b_var_1 = only(filter(s -> s.label == "b" && s.value == 20, sets))

    @test b_var_1.is_baseline == false
    @test b_var_1.config["b"] == 20
    @test b_var_1.config["c"]["deep"] == "x" # Should keep baseline for other params

    # Verify 'c' variations exist
    # We look for a set where label is "c.deep" and value is "y"
    c_var = only(filter(s -> s.label == "c.deep" && s.value == "y", sets))

    @test c_var.config["c"]["deep"] == "y"
    @test c_var.config["b"] == 10 # Should keep baseline for b

end


@testset "Integration: Loading from YAML" begin

    # 1. Define the YAML content (matches your mock config)
    yaml_content = """
    a: 1
    b:
      sensitivity: [10, 20, 30]
    c:
      deep:
        sensitivity: ["x", "y"]
    """

    # 2. Write it to a temporary file in the test directory
    test_file_path = joinpath(@__DIR__, "test_config.yaml")
    write(test_file_path, yaml_content)

    try
        # 3. Use the PUBLIC API to load it
        sets = load_sets(test_file_path)

        # --- Run Robust Assertions ---

        # A. Totals (1 Baseline + 2 from 'b' + 1 from 'c')
        @test length(sets) == 4

        # B. Baseline (Always Index 1)
        base = sets[1]
        @test base.is_baseline == true
        @test base.config["b"] == 10
        @test base.config["c"]["deep"] == "x"

        # C. Check 'b' Variations (Order Agnostic)
        # Find the set where label is "b" and value is 20
        b_var = only(filter(s -> s.label == "b" && s.value == 20, sets))
        @test b_var.config["b"] == 20
        @test b_var.config["c"]["deep"] == "x" # Other params stay baseline

        # D. Check 'c' Variations
        # Find the set where label is "c.deep" and value is "y"
        c_var = only(filter(s -> s.label == "c.deep" && s.value == "y", sets))
        @test c_var.config["c"]["deep"] == "y"
        @test c_var.config["b"] == 10 # Other params stay baseline

    finally
        # 4. Clean up: Delete the file even if tests fail
        rm(test_file_path, force=true)
    end

end

@testset "Reporting & Sensitivity Tables" begin

    # 1. Setup: Define the mock config
    yaml_content = """
    a: 2
    b:
      sensitivity: [3, 4]
    c:
      sensitivity: [10, 20, 30]
    """

    # Use temporary paths to avoid clutter
    config_path = joinpath(@__DIR__, "test_reporting.yaml")
    output_dir = joinpath(@__DIR__, "test_reports_output")

    write(config_path, yaml_content)

    try
        # 2. Load & Simulate
        sets = load_sets(config_path)
        results = Dict{Int, Dict{String, Any}}()

        for p in sets
            cfg = p.config
            val_a, val_b, val_c = cfg["a"], cfg["b"], cfg["c"]

            # Simple math for verification
            results[p.id] = Dict(
                "Sum" => val_a + val_b + val_c,       # Baseline: 2+3+10 = 15
                "Prod" => val_a * val_b * val_c       # Baseline: 2*3*10 = 60
            )
        end

        # 3. Generate Reports
        tables = save_sensitivity_reports(sets, results;
            output_dir=output_dir,
            formats=[:csv, :markdown, :latex]
        )

        # 4. Assertions on Data Structure

        # --- Check Table 'b' ---
        @test haskey(tables, "b")
        df_b = tables["b"]

        # Structure Checks
        @test size(df_b, 1) == 2  # 1 Baseline + 1 Variation
        @test "Variation in b" in names(df_b)

        # Content Checks (Row 1: Baseline)
        @test df_b[1, "Variation in b"] == "3 (Baseline)"
        @test df_b[1, "Sum"] == 15

        # Content Checks (Row 2: Variation b=4)
        # Expected: a=2, b=4, c=10 -> Sum=16, Prod=80
        @test df_b[2, "Variation in b"] == "4"
        @test df_b[2, "Sum"] == 16
        @test df_b[2, "Prod"] == 80

        # --- Check Table 'c' ---
        @test haskey(tables, "c")
        df_c = tables["c"]

        # Structure Checks
        @test size(df_c, 1) == 3 # 1 Baseline + 2 Variations

        # Find the specific row where c=20
        # Expected: a=2, b=3, c=20 -> Sum=25, Prod=120
        row_c20 = only(filter(row -> row["Variation in c"] == "20", eachrow(df_c)))
        @test row_c20["Sum"] == 25
        @test row_c20["Prod"] == 120

        # 5. Assertions on Files
        # Verify that files were actually created
        @test isfile(joinpath(output_dir, "sensitivity_b.csv"))
        @test isfile(joinpath(output_dir, "sensitivity_b.md"))
        @test isfile(joinpath(output_dir, "sensitivity_b.tex"))
        @test isfile(joinpath(output_dir, "sensitivity_c.csv"))

    finally
        # 6. Cleanup
        rm(config_path, force=true)
        rm(output_dir, recursive=true, force=true)
    end
end