# this is fileIO_utils.jl
# it contains the file dialogs and the actions of the main menu

# The GUI opens the native file dialogs through these Refs, so that the tests can
# replace them by functions that return a fixed filename (there is no user on CI)
const PICK_FILE = Ref{Function}(pick_file)
const SAVE_FILE = Ref{Function}(save_file)

# the dialogs are opened on another thread, so that the GUI does not block
choose_file_to_open() = fetch(Threads.@spawn PICK_FILE[](""))
choose_file_to_save() = fetch(Threads.@spawn SAVE_FILE[](""))

"""
    run_async(f, description)

Runs `f` asynchronously, so that the GUI remains responsive, and prints errors (which
would otherwise be silently swallowed by the task).
"""
function run_async(f, description)
    return @async try
        f()
    catch err
        @error "$description failed" exception = (err, catch_backtrace())
    end
end

"""
    load_profile!(gui, filename)
    load_profile!(gui, profile::ProfileData; name = "")

Loads a profile (from a jld2 file that contains a `Profile`) and creates the plot controls
and the plots for it.
"""
function load_profile!(gui, filename::AbstractString)
    isempty(filename) && return nothing # the dialog was cancelled
    profile = load(filename, "Profile") # we need to make this more foolproof, I don't think we can rely on people calling their profile structure Profile
    println(filename * " loaded")
    return load_profile!(gui, profile; name = basename(filename))
end

function load_profile!(gui, profile::ProfileData; name = "")
    gui.profile      = profile
    gui.profile_file = name

    field_names = volume_field_names(profile)
    surf_names  = surface_names(profile)
    pnt_names   = point_names(profile)
    println("Data extracted for vertical profile plotting")

    # the heatmap data is an Observable, and the range of the color range slider depends on it
    value    = Observable(volume_slice(profile, field_names[1]))
    colrange = lift(v -> LinRange(finite_extrema(v)..., 1000), value)

    # plot controls
    panel         = gui.panels.plot_controls
    field_ctrls   = set_field_controls!(panel[1, 1], field_names, colrange)
    surf_toggles  = set_toggle_panel!(panel[2, 1], "Surface data (Moho etc.)", surf_names)
    point_toggles = set_toggle_panel!(panel[3, 1], "Point data (Seismicity etc.)", pnt_names)
    screenshot_panel = panel[4, 1] = GridLayout(tellheight = false, halign = :left) # screenshot controls, still to be done
    Box(screenshot_panel[1, 1], color = :white, cornerradius = 3)
    println("Data controls initialized")

    # plots
    plot_profile!(gui, value, field_names[1], surf_names, surf_toggles, pnt_names, point_toggles)

    connect_field_controls!(gui, field_ctrls, value, colrange)
    return nothing
end

"""
    load_modifiable_picks!(gui, filename)

Loads picks that can be modified.
"""
function load_modifiable_picks!(gui, filename)
    data_picks = load_picks(filename)
    isnothing(data_picks) && return nothing

    warn_if_other_profile(data_picks, gui.profile)
    gui.picks[] = pick_points(data_picks["picks"])
    println("Picks loaded: ", length(gui.picks[]))
    return nothing
end

"""
    load_fixed_picks!(gui, filename)

Loads picks that cannot be modified, which are shown if "Compare picks" is active.
"""
function load_fixed_picks!(gui, filename)
    data_picks = load_picks(filename)
    isnothing(data_picks) && return nothing

    warn_if_other_profile(data_picks, gui.profile)
    plot_fixed_picks!(gui, data_picks["picks"])
    println("Picks plotted")
    return nothing
end

function warn_if_other_profile(data_picks, profile)
    if picks_belong_to_profile(data_picks, profile)
        println("The loaded picks belong to the current profile. Loading picks...")
    else
        println("Warning: The loaded picks do not belong to the current profile. Proceed with caution")
    end
    return nothing
end

"""
    save_current_picks(gui)

Asks for a filename and saves the current picks. The lat and lon of the picks are
interpolated from the profile start and end points.
"""
function save_current_picks(gui)
    println("saving picks...")
    pick_data = pick_table(gui.picks[], gui.profile)
    user_name = gui.user_name.stored_string[]
    return run_async("Saving the picks") do
        save_picks(choose_file_to_save(), pick_data, gui.profile; user_name = user_name)
    end
end

function save_screenshot(gui)
    return run_async("Saving the screenshot") do
        fn_screen = choose_file_to_save()
        save(fn_screen, gui.fig, px_per_unit = 2)
        println(fn_screen * " saved")
    end
end

# what happens if an entry of the main menu is selected
const MAIN_MENU_ACTIONS = Dict{String, Function}(
    "Load Profile..."                => gui -> run_async(() -> load_profile!(gui, choose_file_to_open()), "Loading the profile"),
    "Load Picks..."                  => gui -> run_async(() -> load_modifiable_picks!(gui, choose_file_to_open()), "Loading the picks"),
    "Load Picks (not modifyable)..." => gui -> run_async(() -> load_fixed_picks!(gui, choose_file_to_open()), "Loading the picks"),
    "Save All..."                    => gui -> nothing, # save a jld2 file with all data attached, similar to a state file in paraview? Still has to be implemented
    "Save Picks..."                  => save_current_picks,
    "Save Screenshot..."             => save_screenshot,
    "Close"                          => gui -> GLMakie.closeall(),
)

"""
    handle_menu_selection!(gui, selection)

Runs the action of the main menu entry `selection` (see `MAIN_MENU_ACTIONS`).
"""
function handle_menu_selection!(gui, selection)
    action = get(MAIN_MENU_ACTIONS, selection, nothing)
    isnothing(action) || action(gui)
    return nothing
end
