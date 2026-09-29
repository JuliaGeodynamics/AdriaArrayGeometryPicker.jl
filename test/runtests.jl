using AdriaArrayGeometryPicker
using GLMakie
using Test

include("synthetic_profile.jl")

# The GUI tests need OpenGL. By default they only run if a GLMakie window can be created,
# which is not the case on most headless machines. Set ADA_GUI_TESTS=true to enforce them
# (e.g. on CI with a virtual display) or ADA_GUI_TESTS=false to skip them.
function opengl_available()
    try
        screen = GLMakie.Screen(visible = false)
        close(screen)
        return true
    catch err
        @warn "Cannot create an OpenGL context" exception = err
        return false
    end
end

const GUI_TESTS = let setting = lowercase(get(ENV, "ADA_GUI_TESTS", "auto"))
    setting == "auto" ? opengl_available() : parse(Bool, setting)
end

@testset "AdriaArrayGeometryPicker.jl" begin
    @testset "Package" begin
        @test isdefined(AdriaArrayGeometryPicker, :start_AdA_Picker)
        @test :start_AdA_Picker in names(AdriaArrayGeometryPicker)
        @test isfile(joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "AdA_Picker_logo_tr.png"))
    end

    @testset "Synthetic profile" begin
        # checks that the profile has the structure the GUI relies on
        dir = mktempdir()
        fn  = save_synthetic_profile(joinpath(dir, "profile.jld2"))
        P   = load(fn, "Profile")
        @test P.vertical
        @test P.start_lonlat == START_LONLAT && P.end_lonlat == END_LONLAT
        @test keys(P.VolData.fields)[end-1:end] == (:FlatCrossSection, :x_profile)
        @test haskey(P.SurfData, :Topography) && haskey(P.SurfData.Topography.fields, :x_profile)
        @test haskey(P.PointData.Seismicity.fields, :depth_proj)
    end

    @testset "Controls" begin
        fig  = Figure()
        menu = AdriaArrayGeometryPicker.set_fileIO_menu!(fig, fig[1, 1])
        @test menu isa Menu
        @test ["Load Profile...", "Load Picks...", "Save Picks...", "Save Screenshot..."] ⊆ menu.options[]
    end

    include("test_data.jl")

    if GUI_TESTS
        include("test_gui.jl")
    else
        @warn "Skipping GUI tests (no OpenGL available)"
        @test_skip "GUI"
    end
end
