# Drives the GUI through its menus, the way a user would. The native file dialogs are
# replaced by functions returning a fixed filename, see `PICK_FILE`/`SAVE_FILE`.
using AdriaArrayGeometryPicker, GLMakie, JLD2, Test

const AGP = AdriaArrayGeometryPicker

# menu callbacks run asynchronously, so we have to wait for them to finish
function wait_until(f; timeout = 300)
    status = timedwait(f, timeout; pollint = 0.1)
    return status == :ok
end

find_blocks(fig, T) = filter(b -> b isa T, fig.content)
find_plots(ax, T)   = filter(p -> p isa T, ax.scene.plots)

function select!(menu, option)
    menu.selection[] = option
    return nothing
end

@testset "GUI" begin
    GLMakie.activate!(visible = false) # don't pop up windows during the tests

    dir          = mktempdir()
    profile_file = save_synthetic_profile(joinpath(dir, "test_profile.jld2"))
    picks_file   = joinpath(dir, "picks.jld2")
    screen_file  = joinpath(dir, "screenshot.png")

    fig = start_AdA_Picker()
    @test fig isa Figure
    gui = AGP.current_gui()
    @test gui.fig === fig

    menus     = find_blocks(fig, Menu)
    main_menu = only(filter(m -> "Load Profile..." in m.options[], menus))

    @testset "Load profile" begin
        AGP.PICK_FILE[] = _ -> profile_file
        select!(main_menu, "Load Profile...")

        # loading is done once the colormap menu (the last control) has its callback
        loaded() = any(m -> :roma in m.options[] && !isempty(GLMakie.Observables.listeners(m.selection)), find_blocks(fig, Menu))
        @test wait_until(loaded)
        @test any(ax -> ax.title[] == "test_profile.jld2", find_blocks(fig, Axis))

        # data axis = the one with the heatmap
        ax = only(filter(ax -> !isempty(find_plots(ax, Heatmap)), find_blocks(fig, Axis)))
        @test ax === gui.ax_profile
        @test length(find_plots(ax, Scatter)) == 2 # picks + seismicity

        # one toggle per surface (only Moho, topography is plotted separately) and point data set
        # (+ the picking and compare toggles)
        @test length(find_blocks(fig, Toggle)) == 2 + 1 + 1

        # the field menu contains the volume data, without the helper fields
        field_menu = only(filter(m -> :dVs in m.options[], find_blocks(fig, Menu)))
        @test field_menu.options[] == [:dVs, :dVp]
    end

    ax = gui.ax_profile
    hm = only(find_plots(ax, Heatmap))

    @testset "Change field and colormap" begin
        field_menu = only(filter(m -> :dVs in m.options[], find_blocks(fig, Menu)))
        dVs_max = maximum(filter(!isnan, hm[3][]))
        select!(field_menu, :dVp)
        @test maximum(filter(!isnan, hm[3][])) ≈ 2 * dVs_max

        cmap_menu = only(filter(m -> :roma in m.options[], find_blocks(fig, Menu)))
        select!(cmap_menu, :roma)
        @test hm.colormap[] == Reverse(:roma)
    end

    @testset "Save and load picks" begin
        textbox = only(filter(t -> t.placeholder[] == "User name", find_blocks(fig, Textbox)))
        textbox.stored_string[] = "CI"

        # add picks, as done by the mouse callbacks
        x_picks     = [100.0, 300.0, 500.0]
        depth_picks = [-40.0, -80.0, -120.0]
        gui.picks[] = [Point3f(x, d, 1000) for (x, d) in zip(x_picks, depth_picks)]

        AGP.SAVE_FILE[] = _ -> picks_file
        select!(main_menu, "Save Picks...")
        @test wait_until(() -> isfile(picks_file))

        saved = wait_until(() -> try
            load(picks_file); true
        catch
            false
        end, timeout = 30)
        @test saved
        data = load(picks_file)
        @test data["picks"].x ≈ x_picks
        @test data["picks"].depth ≈ depth_picks
        # the profile runs along a latitude, so lat is constant and lon increases
        @test all(data["picks"].lat .≈ 45.0)
        @test issorted(data["picks"].lon) && all(11.0 .<= data["picks"].lon .<= 19.0)
        @test data["pick_info"].user_name == "CI"
        @test data["profile_info"].start_lonlat == (11.0, 45.0)
        @test data["profile_info"].end_lonlat   == (19.0, 45.0)

        # picking has to keep working after saving
        push!(gui.picks[], Point3f(600, -150, 1000))
        notify(gui.picks)
        @test length(gui.picks[]) == 4

        # load them back as modifiable picks
        gui.picks[] = Point3f[]
        AGP.PICK_FILE[] = _ -> picks_file
        select!(main_menu, "Load Picks...")
        @test wait_until(() -> length(gui.picks[]) == 3)
        @test [p[1] for p in gui.picks[]] ≈ x_picks
        @test [p[2] for p in gui.picks[]] ≈ depth_picks

        # and as fixed picks for comparison, which adds two lines to the profile
        nlines = length(find_plots(ax, Lines))
        select!(main_menu, "Load Picks (not modifyable)...")
        @test wait_until(() -> length(find_plots(ax, Lines)) == nlines + 2)
    end

    @testset "Save screenshot" begin
        AGP.SAVE_FILE[] = _ -> screen_file
        select!(main_menu, "Save Screenshot...")
        @test wait_until(() -> isfile(screen_file) && filesize(screen_file) > 0)
    end

    GLMakie.closeall()

    @testset "Start with a profile" begin
        fig = start_AdA_Picker(data = profile_file)
        gui = AGP.current_gui()
        @test gui.profile_file == "test_profile.jld2"
        @test length(find_plots(gui.ax_profile, Heatmap)) == 1
        GLMakie.closeall()
    end
end
