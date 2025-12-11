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

using Test
using ParameterSets

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