"""
    compare_plot_state(ax::Axis, panel::GridLayout, colorbar::GridLayout, compare_toggle = nothing) -> NamedTuple
    compare_plot_state(axes, panels, widgets) -> NamedTuple

Create the state for picks shown for comparison (picks of other files, not editable): what
[`add_compare_picks!`](@ref) and [`load_compare_picks!`](@ref) create (a label and a toggle per
file in the panel, a dashed line per file in the profile axis, a legend in the colorbar
layout). Created once, before a profile is loaded; it creates nothing itself.
[`clear_compare_picks!`](@ref) removes the compared picks (called by [`connect_profile!`](@ref)
for the state `compare` whenever a profile is loaded). Meant for a GeophysicalModelGenerator
`ProfileData`.

# Arguments
- `ax`: the profile axis.
- `panel`: the (empty) content layout for the labels and toggles, made by
  [`control_panel!`](@ref).
- `colorbar`: the colorbar layout (see [`profile_plot_area!`](@ref)); the legend goes right of
  the colorbars and the other legends.
- `compare_toggle`: an optional `Toggle` that shows or hides all compared picks at once (a line
  is visible while its own toggle *and* `compare_toggle` are on); `nothing`: each line follows
  only its own toggle.
- `axes`, `panels`, `widgets`: as returned by [`picker_layout`](@ref); `axes.profile`,
  `panels.compare_picks_panel`, `panels.colorbar` and `widgets.compare_toggle` (the "Compare
  Picks" toggle of the pick legend panel) are used.

# Returns
A `NamedTuple` with the fields `ax`, `panel`, `colorbar`, `compare_toggle`, the dashed `lines`
with their `toggles`, `labels`, file `paths`, `other_profile` flags and `picks` (one entry per
shown file), and the `legend` (`Ref`).

# Example
```julia
fig = Figure()
area = profile_plot_area!(fig[1, 2])
panel = control_panel!(fig[1, 1], "Compare picks"; collapsible = true, width = 340)
compare_toggle = Toggle(fig[2, 1]; active = true)
compare = compare_plot_state(area.profile, panel, area.colorbar, compare_toggle)
add_compare_picks!(compare, Picks([(100.0, -50.0), (300.0, -80.0)]), "example picks")
```
"""
compare_plot_state(ax::Axis, panel::GridLayout, colorbar::GridLayout, compare_toggle = nothing) =
    (; ax, panel, colorbar, compare_toggle, blocks = Any[], plots = Any[], lines = Any[],
       toggles = Any[], labels = String[], paths = String[], other_profile = Bool[], picks = Picks[],
       legend = Ref{Any}(nothing))
compare_plot_state(axes, panels, widgets) =
    compare_plot_state(axes.profile, panels.compare_picks_panel, panels.colorbar, widgets.compare_toggle)

# background of the labels of picks that belong to another profile
const OTHER_PROFILE_COLOR = RGBAf(0.9, 0.1, 0.1, 0.45)

"""
    clear_compare_picks!(state)

Remove all picks shown for comparison (their lines, toggles, labels and the legend). Called
when another profile is loaded, since the picks belong to the previous one (see
[`connect_profile!`](@ref)). Needs no profile.

# Arguments
- `state`: the compare state of [`compare_plot_state`](@ref).

Returns `state`.
"""
function clear_compare_picks!(state)
    foreach(p -> delete!(state.ax, p), state.plots)
    foreach(delete!, state.blocks)
    state.legend[] = place_legend!(state.colorbar, :compare, nothing)
    foreach(empty!, (state.blocks, state.plots, state.lines, state.toggles, state.labels, state.paths,
                     state.other_profile, state.picks))
    fit_panel!(state.panel)
    return state
end

"""
    add_compare_picks!(state, picks::Picks, label; other_profile = false, horizontal = false) -> line plot

Show `picks` (not editable) as a dashed coloured line on top of a solid white one in the profile
axis, with a toggle and `label` in the panel of the state and an entry in the comparison
legend (the last legend of the colorbar layout; greyed out by Makie while the line is hidden).
The line is visible while its toggle and the `compare_toggle` of the state (if any) are on. With
`horizontal = true` (horizontal slice) the picks are drawn at their longitude / latitude. With
`other_profile = true` (picks of another profile) the label in the panel gets a red background.
`state` is created by [`compare_plot_state`](@ref).

# Arguments
- `state`: the compare state.
- `picks`: the [`Picks`](@ref) to show (the first two coordinates are drawn).
- `label`: text of the label and the legend entry.

# Keywords
- `other_profile`: mark the picks as belonging to another profile.
- `horizontal`: the picks are made on a horizontal slice (drawn at lon / lat).

Returns the dashed line plot. Needs no profile data itself; the coordinates of `picks` must be
those of the profile axis (see [`current_picks`](@ref) for the columns of picks made on a
profile).
"""
function add_compare_picks!(state, p::Picks, label::AbstractString; other_profile::Bool = false,
                            horizontal::Bool = false)
    i = length(state.lines) + 1
    xy = compare_xy(p, horizontal)
    x, y = first.(xy), last.(xy)

    if other_profile
        push!(state.blocks, Box(state.panel[i, 1]; color = OTHER_PROFILE_COLOR, strokewidth = 0,
                                cornerradius = 3))
    end
    push!(state.blocks, Label(state.panel[i, 1], label; fontsize = 14, halign = :left,
                              padding = (3, 3, 1, 1)))
    toggle = Toggle(state.panel[i, 2]; active = true)
    push!(state.blocks, toggle)
    visible = state.compare_toggle === nothing ? toggle.active :
              lift(&, toggle.active, state.compare_toggle.active)

    # below the editable picks (z = PICK_Z), above surface lines and points
    halo = lines!(state.ax, x, y; color = :white, linewidth = 4, visible)
    line = lines!(state.ax, x, y; color = Makie.wong_colors()[mod1(i + 4, 7)], linewidth = 2.5,
                  linestyle = :dash, visible)
    translate!(halo, 0, 0, 20)
    translate!(line, 0, 0, 21)
    push!(state.plots, halo, line)
    push!(state.lines, line)
    push!(state.toggles, toggle)
    push!(state.labels, label)
    push!(state.other_profile, other_profile)
    push!(state.picks, p)

    rowgap!(state.panel, 2)
    fit_panel!(state.panel)
    state.legend[] = place_legend!(state.colorbar, :compare) do gp
        Legend(gp, state.lines, state.labels, "Compare picks"; valign = :top, framevisible = false)
    end
    return line
end


# picks as drawn: (x, depth), or (lon, lat) on a horizontal slice
compare_xy(p::Picks, horizontal::Bool) =
    horizontal ? horizontal_xy(p) : [(Float64(q[1]), Float64(q[2])) for q in points(p)]

"""
    load_compare_picks!(session, path) -> Bool

Load the pick file `path` (see [`load_picks`](@ref)) and show its picks for comparison (see
[`add_compare_picks!`](@ref)), labelled with the file name (and the user, if stored). Picks of
another profile (see [`picks_match_profile`](@ref)) are shown as well, as they may still be
useful, but their label in the panel gets a red background. Switches the `compare_toggle` of
the compare state (if it has one) on, so that the new line is visible.

# Arguments
- `session`: a `NamedTuple` (or any object with these properties) with the fields `profile`
  (the `Observable` that holds the profile) and `compare` (the state of
  [`compare_plot_state`](@ref)), e.g. `(; profile, compare)`; the session of the picker (see
  [`menu_selection`](@ref)) has both.
- `path`: a pick file (see [`load_picks`](@ref)).

Returns `true` if the picks were added; `false` (and warns) if no profile is loaded or the file
is already shown. Requires a GeophysicalModelGenerator `ProfileData`.
"""
function load_compare_picks!(session, path::AbstractString)
    if session.profile[] === nothing
        @warn "Load a profile before loading picks"
        return false
    end
    p = load_picks(path)
    other_profile = !picks_match_profile(session.profile[], p; warn = false)
    other_profile && @warn "The picks in $path belong to another profile; shown, marked in red"
    state = session.compare
    if abspath(path) in state.paths
        @warn "$path is already shown for comparison"
        return false
    end
    user = string(get(p.metadata, "user", ""))
    label = isempty(user) ? basename(path) : "$(basename(path)) ($user)"
    add_compare_picks!(state, p, label; other_profile, horizontal = !is_vertical(session.profile[]))
    push!(state.paths, abspath(path))
    state.compare_toggle === nothing || (state.compare_toggle.active[] = true)
    @info "Loaded $(length(p)) picks from $path for comparison"
    return true
end
