# The picker window, built headlessly (offscreen rendering with `save`): the three call forms of
# `geometry_picker`, a GUI state round trip, state files of MakiePickerGUI.jl and errors.
# The images are written to a folder in the system temp directory (printed at the end); look at
# them to check that the plots look right.

using AdriaArrayGeometryPicker: AdriaArrayGeometryPicker, geometry_picker, is_vertical, is_state_file,
                                set_pick_points!, set_text!, gui_settings, save_gui_state,
                                set_picks!, current_picks, Picks, points
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

    @testset "picks of another profile" begin
        session = geometry_picker(PROFILE; save = joinpath(OUT, "other_picks.png"))
        warning = session.widgets.pick_warning
        @test warning.text[] == ""

        # same profile: no warning
        own = current_picks(session)
        set_pick_points!(session.picking, PICKS)
        own = current_picks(session)
        @test set_picks!(session, own)
        @test warning.text[] == ""

        # another profile: taken over with a warning below the Picking label
        other = Picks(PICKS; names = (:x, :depth),
                      metadata = Dict{String,Any}("start_lonlat" => (0.0, 0.0), "end_lonlat" => (1.0, 1.0)))
        @test_logs (:warn,) @test !set_picks!(session, other)
        @test pick_xy(session) == PICKS
        @test !isempty(warning.text[])

        # picks of a horizontal slice are not loaded on a vertical profile
        horiz = Picks([(NaN, -10.0)]; names = (:x, :depth), columns = (; lon = [14.0], lat = [44.0]),
                      metadata = Dict{String,Any}("profile_type" => "horizontal", "depth" => -10.0))
        @test_logs (:warn,) @test !set_picks!(session, horiz)
        @test pick_xy(session) == PICKS

        # saving assigns them to the current profile, user and time
        set_text!(session.widgets.pick_name, "ME")
        saved = current_picks(session)
        @test saved.metadata["user"] == "ME"
        @test saved.metadata["start_lonlat"] == session.profile[].start_lonlat
        @test haskey(saved.metadata, "date")
        @test [(q[1], q[2]) for q in points(saved)] == PICKS

        # a new profile clears the warning
        session.profile[] = session.profile[]
        @test warning.text[] == ""

        # no profile: nothing is loaded
        empty = geometry_picker(; save = joinpath(OUT, "other_picks_empty.png"))
        @test_logs (:warn,) @test !set_picks!(empty, other)
        @test isempty(empty.picking.picks[])
        GLMakie.closeall()
    end

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

            # picks of a vertical profile are not loaded; those of another slice get the depth of this one
            slice = AdriaArrayGeometryPicker.slice_depth(session.profile[])
            vert = Picks([(100.0, -50.0)]; names = (:x, :depth), columns = (; lon = [14.0], lat = [44.0]))
            @test_logs (:warn,) @test !set_picks!(session, vert)
            @test isempty(session.picking.picks[])
            set_picks!(session, Picks([(NaN, slice + 10)]; names = (:x, :depth),
                                      columns = (; lon = [14.0], lat = [44.0]),
                                      metadata = Dict{String,Any}("profile_type" => "horizontal", "depth" => slice + 10)))
            @test pick_xy(session) == [(14.0, 44.0)]
            @test last.(points(current_picks(session))) == [slice]
            GLMakie.closeall()
        end
    else
        @info "Skipping the horizontal slice test ($HORIZONTAL not found)"
    end
    @info "Images of the picker window written to $OUT"
end
