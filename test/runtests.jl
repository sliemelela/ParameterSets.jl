using Test
using ParameterSets

@testset "ParameterSets Logic" begin

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
    sets = generate_sets(mock_config)

    @test length(sets) == 4

    # Check Baseline
    @test sets[1].is_baseline == true
    @test sets[1].config["b"] == 10
    @test sets[1].config["c"]["deep"] == "x"

    # Check Variation 1 (b=20)
    @test sets[2].label == "b"
    @test sets[2].value == 20
    @test sets[2].config["b"] == 20
    # Ensure independent branches (c should still be baseline)
    @test sets[2].config["c"]["deep"] == "x"

    # Check Variation 3 (c.deep="y")
    @test sets[4].label == "c.deep"
    @test sets[4].value == "y"
    @test sets[4].config["c"]["deep"] == "y"

    # Ensure independent branches (b should be baseline)
    @test sets[4].config["b"] == 10

end