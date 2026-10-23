"""
    connect_profile!(profile::Observable, states::NamedTuple; axes, profile_file = "",
                     priority = -10) -> ObserverFunction

Fill the plot states `states` with every profile that is loaded into `profile`: the listener
that makes a GUI follow its profile. Only the states that are present are filled, so a GUI
with e.g. only a volume and a point data panel passes `(; volume, points)`. Requires a
GeophysicalModelGenerator `ProfileData`.

Every time a profile is loaded, these steps are taken (in this order, each only if its state
is present):

| step | state (field of `states`) | function |
|:-----|:--------------------------|:---------|
| layout of the plot panel | – (always, if there are `axes`) | [`set_profile_layout!`](@ref) |
| topography (axis title: `profile_file`) | `topography` ([`topography_panel_state`](@ref)) | [`load_topography_panel!`](@ref) |
| volume data | `volume` ([`volume_plot_state`](@ref)) | [`load_volume_data!`](@ref) |
| axis limits of a horizontal slice | – (always, if there are `axes`) | [`fit_horizontal_axis!`](@ref) |
| surface data | `surface` ([`surface_plot_state`](@ref)) | [`load_surface_data!`](@ref) |
| point data | `points` ([`point_plot_state`](@ref)) | [`load_point_data!`](@ref) |
| map overview | `topomap` ([`map_plot_state`](@ref)) | [`update_map_line!`](@ref) |
| compared picks are removed | `compare` ([`compare_plot_state`](@ref)) | [`clear_compare_picks!`](@ref) |

Other fields of `states` are ignored. An error in one of the steps is logged and does not stop
the others. Without a `topography` state the topography axis (if any) stays hidden.

# Arguments
- `profile`: `Observable` that holds the profile (see [`load_profile!`](@ref)); `nothing` is
  ignored.
- `states`: `NamedTuple` of the plot states, with any of the fields `volume`
  ([`volume_plot_state`](@ref)), `surface` ([`surface_plot_state`](@ref)), `points`
  ([`point_plot_state`](@ref)), `topography` ([`topography_panel_state`](@ref)), `topomap`
  ([`map_plot_state`](@ref)) and `compare` ([`compare_plot_state`](@ref)); each made with its
  explicit form (no [`picker_layout`](@ref) needed) or from the output of `picker_layout`.

# Keywords
- `axes`: `NamedTuple` with the profile axis `profile` and optionally the topography axis
  `topo_ax`, e.g. the result of [`profile_plot_area!`](@ref) or the `axes` of
  [`picker_layout`](@ref) (required; `nothing`: the layout and the axis limits are left alone).
- `profile_file`: name of the profile file (`String` or `Observable`, read when a profile is
  loaded), the title of the topography axis.
- `priority`: priority of the listener. The default `-10` runs it after the listeners with
  default priority, and before the one of [`picking_state`](@ref) (`-20`).

Returns the listener, which can be removed with `off`.

# Example
```julia
fig = Figure(size = (1200, 900))
area = profile_plot_area!(fig[1, 2])
left = fig[1, 1] = GridLayout()
volume_panel = control_panel!(left[1, 1], "Volume data"; width = 340)
point_panel = control_panel!(left[2, 1], "Point data"; width = 340)
map_panel = control_panel!(left[3, 1], "Map"; width = 340)
map_widgets = map_panel!(map_panel)
states = (; volume = volume_plot_state(area.profile, volume_panel!(volume_panel), area.colorbar),
          points = point_plot_state(area.profile, point_panel, area.colorbar),
          topomap = map_plot_state(map_widgets.map_ax, map_widgets.map_load_button, map_widgets.map_label))
profile = Observable{Any}(nothing)
connect_profile!(profile, states; axes = area)
load_profile!(profile, joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "Profile1.pgmg"))
```
"""
function connect_profile!(profile::Observable, states::NamedTuple; axes,
                          profile_file = "", priority::Integer = -10)
    has(key) = haskey(states, key)
    return on(profile; priority) do p
        p === nothing && return

        # missing or empty data is skipped by the functions; anything unexpected is logged,
        # so one broken part neither stops the others nor the GUI
        steps = Pair{String,Function}[]
        if axes !== nothing
            # without a topography state, the topography axis stays hidden
            push!(steps, "layout" => () -> set_profile_layout!(axes, p; show_topography = has(:topography)))
        end
        has(:topography) && push!(steps, "topography" => () -> load_topography_panel!(states.topography, p, string(to_value(profile_file))))
        has(:volume) && push!(steps, "volume data" => () -> load_volume_data!(states.volume, p))
        axes === nothing || push!(steps, "axis limits" => () -> fit_horizontal_axis!(axes.profile, p))
        has(:surface) && push!(steps, "surface data" => () -> load_surface_data!(states.surface, p))
        has(:points) && push!(steps, "point data" => () -> load_point_data!(states.points, p))
        has(:topomap) && push!(steps, "map overview" => () -> update_map_line!(states.topomap, p))
        # picks shown for comparison belong to the previous profile
        has(:compare) && push!(steps, "compared picks" => () -> clear_compare_picks!(states.compare))
        for (what, plot!) in steps
            try
                plot!()
            catch err
                @error "Could not plot the $what of the profile" exception = (err, catch_backtrace())
            end
        end
    end
end

"""
    on_profile_loaded(profile::Observable, profile_file::Observable, axes::NamedTuple,
                      panels::NamedTuple, widgets::NamedTuple)

Create all plot states of the window of [`picker_layout`](@ref) (colorbar and volume data
controls, surface, point and topography data, map overview, compared picks) and fill them with
every profile loaded into `profile` (see [`connect_profile!`](@ref)). Requires a
GeophysicalModelGenerator `ProfileData` and the layout of [`picker_layout`](@ref); for a layout
of your own, create the states you need and call [`connect_profile!`](@ref).

# Arguments
- `profile`: `Observable` that holds the profile (see [`load_profile!`](@ref)).
- `profile_file`: `Observable` with the name of the loaded file (set before `profile` changes),
  used as title of the topography axis.
- `axes`, `panels`, `widgets`: as returned by [`picker_layout`](@ref) (the states are made
  with the `picker_layout` forms of the state functions, e.g.
  `volume_plot_state(axes, panels, widgets)`).

Every time a profile is loaded (listener with priority `-10`), the layout is adapted to the
profile type (vertical cross-section or horizontal slice, see [`set_profile_layout!`](@ref)),
the topography is plotted (with file name and start/end coordinates), the volume data dropdown is
filled and its first field plotted as a heatmap, the axis limits of a horizontal slice are set
(see [`fit_horizontal_axis!`](@ref)), and the surface data, point data, map overview and compared
picks are replaced by those of the new profile. An error in one of these steps is logged and
does not stop the others. See [`load_volume_data!`](@ref), [`load_surface_data!`](@ref),
[`load_point_data!`](@ref), [`load_topography_panel!`](@ref), [`update_map_line!`](@ref) and
[`clear_compare_picks!`](@ref) for the individual steps.

Returns the plot states `(; volume, surface, points, topography, topomap, compare)`, which the
GUI state (see [`gui_settings`](@ref)) is read from.

# Example
```julia
profile = Observable{Any}(nothing)
profile_file = Observable("")
fig, panels, axis, widgets = picker_layout(; profile)
states = on_profile_loaded(profile, profile_file, axis, panels, widgets)
profile_file[] = "Profile1.pgmg"
load_profile!(profile, joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "Profile1.pgmg"))
```
"""
function on_profile_loaded(profile::Observable, profile_file::Observable,
                           axes::NamedTuple, panels::NamedTuple, widgets::NamedTuple)
    states = (; volume = volume_plot_state(axes, panels, widgets),
              surface = surface_plot_state(axes, panels),
              points = point_plot_state(axes, panels),
              topography = topography_panel_state(axes, panels),
              topomap = map_plot_state(axes, widgets),
              compare = compare_plot_state(axes, panels, widgets))
    connect_profile!(profile, states; axes, profile_file)
    return states
end
