"""
    topography_panel_state(ax::Axis, panel::GridLayout; topo_ax = nothing) -> NamedTuple
    topography_panel_state(axes, panels) -> NamedTuple

State of the topography panel: what [`load_topography_panel!`](@ref) created for the current
profile (widgets in the panel, plots in the profile axis or the topography axis). Created once,
before a profile is loaded; it creates nothing itself. Meant for a GeophysicalModelGenerator
`ProfileData`.

# Arguments
- `ax`: the profile axis (the topography of a horizontal slice is plotted on top of it).
- `panel`: the (empty) content layout for the widgets, made by [`control_panel!`](@ref).
- `axes`, `panels`: as returned by [`picker_layout`](@ref); `axes.profile`, `axes.topo_ax`
  (optional) and `panels.topography_data_panel` are used.

# Keywords
- `topo_ax`: the axis above the profile axis in which the topography of a vertical profile is
  plotted (see [`profile_plot_area!`](@ref)); without it, the topography of vertical profiles
  is not shown (horizontal slices do not need it).

# Returns
A `NamedTuple` with the fields `axes` (`(; profile, topo_ax)`), `panel`, the widgets (`blocks`)
and plots (`plots`) of the current profile and `controls`, a `Ref` to the widgets of the panel
that can be set programmatically (filled by [`load_topography_panel!`](@ref)):

- vertical profile: `(; menu, show, fill)`: data set dropdown (`nothing` if there is only one
  data set), the `Toggle` that shows the topography axis and the `Checkbox` for the fill,
- horizontal slice: `(; menu, mode, opacity, levels)`: data set dropdown (or `nothing`), the
  display mode `Menu` ("Heatmap", "Contours", "Off"), the opacity `Slider` of the heatmap and
  the `Textbox` of the contour levels,
- `nothing` without topography data (or a vertical profile without `topo_ax`).

# Example
```julia
fig = Figure()
area = profile_plot_area!(fig[1, 2])
panel = control_panel!(fig[1, 1], "Topography"; width = 340)
topography = topography_panel_state(area.profile, panel; topo_ax = area.topo_ax)
profile = Observable{Any}(nothing)
connect_profile!(profile, (; topography); axes = area)
load_profile!(profile, joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "Profile1.pgmg"))
# vertical profile: (; menu, show, fill); switch the fill below the topography line off
topography.controls[].fill.checked[] = false
# on a horizontal slice it is (; menu, mode, opacity, levels), e.g.
# select_label!(topography.controls[].mode, "Contours")
```
"""
topography_panel_state(ax::Axis, panel::GridLayout; topo_ax = nothing) =
    (; axes = (; profile = ax, topo_ax), panel, blocks = Any[], plots = Any[],
       controls = Ref{Any}(nothing))
topography_panel_state(axes, panels) =
    topography_panel_state(axes.profile, panels.topography_data_panel; topo_ax = get(axes, :topo_ax, nothing))

# entries of `TopoData` that hold data, as a vector of `key => GeoData`
function topography_sets(profile)
    topo = profile.TopoData
    topo === nothing && return Pair{Symbol,Any}[]
    return Pair{Symbol,Any}[k => g for (k, g) in pairs(topo) if !isempty(g.depth.val) && !all(isnan, g.depth.val)]
end

# grid of a topography set with at most ~1000 points per direction (the data can be huge),
# as `(lon, lat, elevation)`
function topography_grid(geo)
    sx, sy = cld(size(geo.depth.val, 1), 1000), cld(size(geo.depth.val, 2), 1000)
    return (Vector{Float64}(geo.lon.val[1:sx:end, 1, 1]), Vector{Float64}(geo.lat.val[1, 1:sy:end, 1]),
            Float64.(geo.depth.val[1:sx:end, 1:sy:end, 1]))
end

"""
    load_topography_panel!(state, profile, name)

Replace the content of the topography panel and the topography plot by those of `profile`
(`profile.TopoData`; `name`, the file name, is the title of the topography axis). `state` is
created by [`topography_panel_state`](@ref). Requires a GeophysicalModelGenerator `ProfileData`;
the result depends on the profile type:

- **vertical profile**: the topography is plotted in the topography axis above the profile
  (see [`plot_topography!`](@ref)). The panel has a dropdown for the data set (if there are
  several), a toggle that shows or hides the axis (the profile axis then takes its space) and a
  checkbox for the grey / blue fill below the line.
- **horizontal slice**: the topography is plotted on top of the volume data, as a heatmap
  (`oleron` colormap, centred around zero, with a slider for the opacity) or as contour lines
  (levels typed in a text field, default: one line at 0), or not at all. The panel has a
  dropdown for the data set (if there are several) and these controls.

Without topography data the panel only says so and the topography axis is hidden; the same
for a vertical profile if the state has no topography axis. The widgets of the panel are
available in `state.controls[]` (see [`topography_panel_state`](@ref)), so they can be set
programmatically, e.g. with [`select_label!`](@ref) and [`set_text!`](@ref). Called by
[`connect_profile!`](@ref) for the state `topography`.

# Arguments
- `state`: the topography state of [`topography_panel_state`](@ref).
- `profile`: the loaded profile.
- `name`: title of the topography axis (usually the file name).

Returns `nothing`.
"""
function load_topography_panel!(state, profile, name)
    ax, topo_ax = state.axes.profile, state.axes.topo_ax
    foreach(p -> delete!(ax, p), state.plots)
    foreach(delete!, state.blocks)
    foreach(empty!, (state.plots, state.blocks))
    state.controls[] = nothing
    topo_ax === nothing || empty!(topo_ax)
    vertical = is_vertical(profile)
    sets = topography_sets(profile)
    panel = state.panel

    if isempty(sets) || (vertical && topo_ax === nothing)
        text = isempty(sets) ? "No topography data" : "No topography axis"
        push!(state.blocks, Label(panel[1, 1], text; fontsize = 14, halign = :left))
        set_profile_layout!(state.axes, profile; show_topography = false)
        fit_panel!(panel)
        return
    end

    labels(sets) = String[string(first(s)) for s in sets]
    row = 0
    menu = nothing
    if length(sets) > 1
        row += 1
        menu = Menu(panel[row, 1]; options = labels(sets), width = 250)
        push!(state.blocks, menu)
    end
    extra = menu === nothing ? () : (menu.selection,)   # redraw when another data set is chosen
    selected() = sets[menu === nothing ? 1 : max(menu.i_selected[], 1)]

    if vertical
        show = Toggle(panel[row += 1, 1]; active = true, halign = :left)
        showlabel = Label(panel[row, 2], "show topography axis"; halign = :left, fontsize = 14)
        fill = Checkbox(panel[row += 1, 1]; checked = true, halign = :left)
        filllabel = Label(panel[row, 2], "fill below the line"; halign = :left, fontsize = 14)
        append!(state.blocks, (show, showlabel, fill, filllabel))
        redraw = function (_...)
            set_profile_layout!(state.axes, profile; show_topography = show.active[])
            plot_topography!(topo_ax, profile, name; key = first(selected()), fill = fill.checked[])
        end
        onany(redraw, show.active, fill.checked, extra...)
        state.controls[] = (; menu, show, fill)
    else
        mode = Menu(panel[row += 1, 1]; options = ["Heatmap", "Contours", "Off"], width = 250)
        opacity = Slider(panel[row += 1, 1]; range = 0:0.05:1, startvalue = 0.6, width = 180, halign = :left)
        opacitylabel = Label(panel[row, 2], lift(a -> "opacity $(round(a; digits = 2))", opacity.value);
                             halign = :left, fontsize = 14)
        levels = Textbox(panel[row += 1, 1]; width = 250, placeholder = "Contour levels (default 0)")
        append!(state.blocks, (mode, opacity, opacitylabel, levels))
        grids = Dict{Symbol,Any}()
        redraw = function (_...)
            foreach(p -> delete!(ax, p), state.plots)
            empty!(state.plots)
            key, geo = selected()
            lon, lat, z = get!(() -> topography_grid(geo), grids, key)
            kind = something(mode.selection[], "Off")
            if kind == "Heatmap"
                finite = filter(isfinite, z)
                m = isempty(finite) ? 1.0 : max(maximum(abs, finite), eps())
                plot = heatmap!(ax, lon, lat, z; colormap = :oleron, colorrange = (-m, m),
                                alpha = opacity.value)
                translate!(plot, 0, 0, -40)   # above the volume heatmap (-50), below contours and lines
                push!(state.plots, plot)
            elseif kind == "Contours"
                lv = something(parse_levels(levels.stored_string[]), [0.0])
                halo = contour!(ax, lon, lat, z; levels = lv, color = :white, linewidth = 3.5)
                plot = contour!(ax, lon, lat, z; levels = lv, color = :black, linewidth = 1.5)
                translate!(halo, 0, 0, 3)
                translate!(plot, 0, 0, 4)
                push!(state.plots, halo, plot)
            end
        end
        onany(redraw, mode.selection, levels.stored_string, extra...)
        state.controls[] = (; menu, mode, opacity, levels)
    end

    redraw()
    rowgap!(panel, 4)
    fit_panel!(panel)
    return
end

"""
    fit_horizontal_axis!(ax::Axis, profile)

Set the limits of the axis of a horizontal slice to the lon / lat extent of its topography (of
the volume data if there is no topography) and its aspect ratio such that distances look
approximately equal: a degree of longitude is `cos(latitude)` times as long as one of latitude.
For a vertical profile the axis gets its default aspect ratio back and its limits are left
alone. Called by [`connect_profile!`](@ref). Requires a GeophysicalModelGenerator `ProfileData`.

# Arguments
- `ax`: the profile axis, e.g. `area.profile` of [`profile_plot_area!`](@ref).
- `profile`: the loaded profile.

Returns `nothing`.
"""
function fit_horizontal_axis!(ax::Axis, profile)
    if is_vertical(profile)
        ax.aspect = nothing
        return
    end
    sets = topography_sets(profile)
    extent = if isempty(sets)
        slice_extent(profile)
    else
        geo = last(first(sets))
        extrema(geo.lon.val[:, 1, 1]), extrema(geo.lat.val[1, :, 1])
    end
    extent === nothing && return
    (xmin, xmax), (ymin, ymax) = extent
    limits!(ax, xmin, xmax, ymin, ymax)
    ax.aspect = AxisAspect(cosd((ymin + ymax) / 2) * (xmax - xmin) / (ymax - ymin))
    return
end
