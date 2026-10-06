# The picker window, built headlessly (offscreen rendering with `save`): the three call forms of
# `geometry_picker`, a GUI state round trip, state files of MakiePickerGUI.jl and errors.
# The images are written to a folder in the system temp directory (printed at the end); look at
# them to check that the plots look right.

using AdriaArrayGeometryPicker: AdriaArrayGeometryPicker, geometry_picker, is_vertical, is_state_file,
                                set_pick_points!, set_text!, gui_settings, save_gui_state
import GLMakie
using JLD2

const ASSETS = joinpath(pkgdir(AdriaArrayGeometryPicker), "assets")
const PROFILE = joinpath(ASSETS, "Profile1.pgmg")
# the large horizontal slice is not part of this package; tested only if the GeometryPicker
# repository is next to this one
const HORIZONTAL = joinpath(dirname(pkgdir(AdriaArrayGeometryPicker)), "GeometryPicker", "assets",
                            "Profile_horizontal.pgmg")
const OUT = mkpath(joinpath(tempdir(), "AdriaArrayGeometryPicker_test"))

pick_xy(session) = [(p[1], p[2]) for p in session.picking.picks[]]
const PICKS = [(100.0, -50.0), (250.0, -120.0), (400.0, -200.0)]

# the profile, picks, user name and expanded panel of `PICKS` restored from a state
function test_restored(session)
    @test session.profile[] !== nothing
    @test is_vertical(session.profile[])
    @test session.profile_file[] == "Profile1.pgmg"
    @test session.profile_path[] == abspath(PROFILE)
    @test pick_xy(session) == PICKS
    @test session.widgets.pick_name.stored_string[] == "MT"
    @test session.widgets.point_panel_toggle.active[]
    @test !session.widgets.volume_panel_toggle.active[]
end

@testset "picker window" begin
    @testset "no arguments" begin
        png = joinpath(OUT, "empty.png")
        session = geometry_picker(; save = png)
        @test isfile(png)
        @test session.profile[] === nothing
        @test haskey(session, :screen) && haskey(session, :picking) && haskey(session, :volume)
        GLMakie.closeall()
    end

    state = joinpath(OUT, "state")      # ".aagps" is appended
    settings = nothing
    @testset "profile" begin
        png = joinpath(OUT, "profile.png")
        session = geometry_picker(PROFILE; save = png)
        @test isfile(png)
        @test is_vertical(session.profile[])
        @test session.profile_file[] == "Profile1.pgmg"
        @test session.profile_path[] == abspath(PROFILE)
        @test session.volume.heatmap[] !== nothing
        @test session.volume.contour[] !== nothing
        @test !isempty(session.points.labels)         # seismicity
        @test session.topography.controls[] !== nothing
        @test isempty(session.picking.picks[])

        # a state with picks
        set_pick_points!(session.picking, PICKS)
        set_text!(session.widgets.pick_name, "MT")
        session.widgets.point_panel_toggle.active[] = true
        saved = save_gui_state(state, session)
        @test saved == state * ".aagps"
        @test isfile(saved)
        @test is_state_file(saved)
        settings = gui_settings(session)
        GLMakie.closeall()
    end
    state = state * ".aagps"

    @testset "state file" begin
        png = joinpath(OUT, "state.png")
        session = geometry_picker(state; save = png)
        @test isfile(png)
        test_restored(session)
        # restoring the topography controls must not stretch the x-linked axes to the points
        lims = session.axes.profile.finallimits[]
        @test lims.origin[1] >= -1 && lims.origin[1] + lims.widths[1] <= 701
        GLMakie.closeall()
    end

    @testset "MakiePickerGUI state file" begin
        legacy = joinpath(OUT, "mpg_state.jld2")
        jldsave(legacy; format = "MakiePickerGUI state", version = 1, profile_path = abspath(PROFILE),
                settings)
        @test is_state_file(legacy)
        session = geometry_picker(legacy; save = joinpath(OUT, "mpg_state.png"))
        test_restored(session)
        GLMakie.closeall()
    end

    @testset "file detection and errors" begin
        @test !is_state_file(PROFILE)
        @test !is_state_file(joinpath(ASSETS, "AdA_Picker_logo_tr.png"))
        @test !is_state_file(joinpath(OUT, "does_not_exist.aagps"))
        @test_throws ArgumentError geometry_picker(joinpath(OUT, "does_not_exist.pgmg"))
        @test_throws ArgumentError geometry_picker(joinpath(OUT, "does_not_exist.aagps"))
    end

    if isfile(HORIZONTAL)
        @testset "horizontal slice" begin
            png = joinpath(OUT, "horizontal.png")
            session = geometry_picker(HORIZONTAL; save = png)
            @test isfile(png)
            @test !is_vertical(session.profile[])
            GLMakie.closeall()
        end
    else
        @info "Skipping the horizontal slice test ($HORIZONTAL not found)"
    end
    @info "Images of the picker window written to $OUT"
end
