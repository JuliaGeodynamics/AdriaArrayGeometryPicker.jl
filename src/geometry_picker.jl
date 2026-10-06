# The ready-made picker window of the AdriaArray picker: collapsible volume, surface, point,
# topography, compare-picks, map and screenshot panels (only one expanded at a time), picking in
# the profile axis and a dropdown menu with the entries "Load Profile" (a GeophysicalModelGenerator
# profile, .pgmg), "Save State", "Load State", "Save Picks", "Load Picks", "Load Compare Picks",
# "Save Screenshot" and "Close".

# Build the picker window (not displayed yet) and return its session.
function picker_session()
    # create an empty profile Observable
    profile = Observable{Any}(nothing)
    # name and full path of the file the current profile was loaded from
    profile_file = Observable("")
    profile_path = Observable("")
    # build the layout
    fig, panels, axis, widgets = picker_layout(; profile)

    # listen to profile changes and populate panels / update plots
    states = on_profile_loaded(profile, profile_file, axis, panels, widgets)

    # picking in the profile axis (A + click: add, D + click: remove, drag: move)
    picking = picking_state(fig, profile, axis, widgets)

    # everything needed to save and restore the state of the GUI
    session = (; fig, profile, profile_file, profile_path, panels, axes = axis, widgets, picking, states...)

    # add functionality for the dropdown menu (see `menu_selection` for its entries)
    menu_selection(widgets.menu, session)
    return session
end

"""
    is_state_file(path) -> Bool

Whether `path` is a GUI state file (see [`save_gui_state`](@ref); usually `.aagps`): a JLD2 file with a
`"format"` entry `"AdriaArrayGeometryPicker state"` (or `"MakiePickerGUI state"`, written by
MakiePickerGUI.jl). Decided by the content, not by the extension; anything that is not a JLD2
file, or a JLD2 file without such an entry (e.g. a `.pgmg` profile), gives `false`.
"""
function is_state_file(path::AbstractString)
    isfile(path) || return false
    try
        return jldopen(path, "r") do file
            haskey(file, "format") && file["format"] in STATE_FORMATS
        end
    catch
        return false
    end
end

"""
    geometry_picker(; wait = !isinteractive(), save = nothing) -> NamedTuple
    geometry_picker(path::AbstractString; wait = !isinteractive(), save = nothing) -> NamedTuple

Open the AdriaArray geometry picker window.

- Without arguments, the window opens empty; load a profile with "Load Profile" in the menu.
- With `path`, the file is opened right away. It is recognised by its content:
  - a GUI state file (`.aagps`, see [`save_gui_state`](@ref); a JLD2 file whose entry `"format"` is
    `"AdriaArrayGeometryPicker state"`, or `"MakiePickerGUI state"` for files of
    MakiePickerGUI.jl) is restored with [`load_gui_state!`](@ref): the profile it refers to is
    loaded and the settings and picks are applied;
  - every other file is loaded as a GeophysicalModelGenerator profile (`.pgmg`, see
    [`open_profile!`](@ref)).

  An `ArgumentError` is thrown if `path` does not exist.

The window has a dropdown menu ("Load Profile", "Save State", "Load State", "Save Picks",
"Load Picks", "Load Compare Picks", "Save Screenshot", "Close"; see [`menu_selection`](@ref)),
collapsible panels for the volume, surface, point and topography data, compared picks, a map
overview and screenshots, and picking in the profile axis while the "Picking" toggle is on:
**A + click** adds a pick, **D + click** removes one, **click and drag** moves one.

# Keywords
- `wait`: block until the window is closed. The default waits when Julia runs a script or a
  command (`julia -e ...`) and returns right away in the REPL, so the process does not end
  while the window is open.
- `save`: path of a PNG file. If given, the window is rendered offscreen into that file (after
  the file `path` is loaded) instead of being shown, and the function returns without waiting
  (e.g. for documentation images or headless tests).

# Returns
The session, a `NamedTuple` with the figure (`fig`), the `profile` `Observable`,
`profile_file` and `profile_path`, the `panels`, `axes` and `widgets` of
[`picker_layout`](@ref), the picking state `picking` (see [`picking_state`](@ref)), the plot
states (`volume`, `surface`, `points`, `topography`, `topomap`, `compare`) and the GLMakie
`screen`. It is what [`current_picks`](@ref), [`set_picks!`](@ref),
[`save_gui_state`](@ref) and [`load_gui_state!`](@ref) take.

# Examples
```julia
using AdriaArrayGeometryPicker

# 1) an empty window
session = geometry_picker()

# 2) a window with a profile
session = geometry_picker(joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "Profile1.pgmg"))

# 3) a window with a saved state (profile, settings and picks)
session = geometry_picker("my_state.aagps")

# offscreen: render the window with a profile into a PNG file
geometry_picker("profile.pgmg"; save = "picker.png")
```

From the command line (blocks until the window is closed):

    julia --project -e "using AdriaArrayGeometryPicker; geometry_picker(\\"profile.pgmg\\")"
"""
geometry_picker(; kwargs...) = _geometry_picker(nothing; kwargs...)
function geometry_picker(path::AbstractString; kwargs...)
    isfile(path) || throw(ArgumentError("file not found: $path"))
    return _geometry_picker(String(path); kwargs...)
end

function _geometry_picker(path::Union{Nothing,String}; wait::Bool = !isinteractive(),
                          save::Union{Nothing,AbstractString} = nothing)
    session = picker_session()
    fig = session.fig
    # offscreen: render the window into the PNG file `save` (e.g. for the documentation)
    screen = save === nothing ? display(GLMakie.Screen(), fig) :
                                display(GLMakie.Screen(; visible = false), fig)
    session = (; session..., screen)

    if path !== nothing
        if is_state_file(path)
            load_gui_state!(session, path)
        else
            @info "Loading $path ..."
            data = open_profile!(session, path)
            if is_vertical(data)
                @info "Loaded profile from $(round.(data.start_lonlat; digits=2)) to $(round.(data.end_lonlat; digits=2))"
            else
                @info "Loaded horizontal slice at depth $(slice_depth(data))"
            end
        end
    end

    if save !== nothing
        sleep(1.5)      # let the animations (e.g. of toggles) finish
        colorbuffer(screen)
        sleep(0.5)
        Makie.save(save, colorbuffer(screen))
    elseif wait
        # started as a script: keep the process alive until the window is closed
        Base.wait(screen)
    end
    return session
end
