# Tests of the functions that don't need a GUI (and thus OpenGL)
using AdriaArrayGeometryPicker, GLMakie, JLD2, Test

const AGP = AdriaArrayGeometryPicker

@testset "Profile data" begin
    P = create_synthetic_profile()
    @test AGP.volume_field_names(P) == [:dVs, :dVp]
    @test AGP.surface_names(P) == [:Moho]
    @test AGP.point_names(P) == [:Seismicity]

    x, y = AGP.profile_grid(P)
    @test size(AGP.volume_slice(P, :dVs)) == (length(x), length(y))
    @test issorted(x) && minimum(y) ≈ -300 && maximum(y) ≈ 0

    x_topo, y_topo = AGP.topography(P)
    @test length(x_topo) == length(y_topo) && eltype(y_topo) <: Real

    @test AGP.finite_extrema([1.0, NaN, -2.0]) == (-2.0, 1.0)
end

@testset "Picks" begin
    P = create_synthetic_profile()
    points = [Point3f(100, -40, 1000), Point3f(300, -80, 1000)]
    pick_data = AGP.pick_table(points, P)
    @test pick_data.x ≈ [100, 300] && pick_data.depth ≈ [-40, -80]
    @test all(pick_data.lat .≈ 45.0) && issorted(pick_data.lon)

    dir = mktempdir()
    fn  = joinpath(dir, "picks.jld2")
    @test AGP.save_picks(fn, pick_data, P; user_name = "test")
    @test !AGP.save_picks(joinpath(dir, "picks.csv"), pick_data, P) # not implemented yet

    data_picks = AGP.load_picks(fn)
    @test data_picks["pick_info"].user_name == "test"
    @test AGP.picks_belong_to_profile(data_picks, P)
    @test AGP.pick_points(data_picks["picks"]) ≈ points
    @test isnothing(AGP.load_picks(joinpath(dir, "picks.txt")))
end
