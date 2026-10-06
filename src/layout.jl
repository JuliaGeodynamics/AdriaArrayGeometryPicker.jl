"""
    picker_layout(; size = (1200, 1000), profile = nothing, empty_height = 20,
                  logo_file = <assets/AdA_Picker_logo_tr.png>) -> NamedTuple

Create the figure and window layout of the picker:

    ┌─────────────┬───────────────┬─────────────┬──────────┐
    │ menu        │ pick controls │ pick legend │ logo     │
    ├─────────────┼───────────────┴─────────────┴──────────┤
    │ volume data │ topography (20 %)                      │
    │ surface data│ profile                                │
    │ point data  │                                        │
    │ topography  │                                        │
    │ compare     │                                        │
    │ map overview│ colorbar / legends (160 px)            │
    │ screenshot  │                                        │
    └─────────────┴────────────────────────────────────────┘

This is the ready-made window for profile data and therefore specific to
GeophysicalModelGenerator profiles (the widgets belong to the plot states). It is made of
[`control_panel!`](@ref) panels, [`profile_plot_area!`](@ref) (plot panel),
[`volume_panel!`](@ref) (volume data widgets) and [`map_panel!`](@ref) (map overview widgets);
[`on_profile_loaded`](@ref) connects them. [`geometry_picker`](@ref) builds the whole window.

# Keywords
- `size`: size of the figure in pixels.
- `profile`: the `Observable` that holds the profile. If given, every panel that has widgets
  switches to following its content as soon as `profile` holds a profile. This listener has
  the same priority (`-10`) as the one of [`connect_profile!`](@ref) and is registered first, so it
  runs before the loaders; this is harmless because every `load_*!` function fits its panel itself.
- `empty_height`: the menu panels start with this small fixed content height.
- `logo_file`: image shown in the top right corner (a warning is logged if it does not exist).

The first row and column of the window adapt to the panels; the plot panel takes the remaining
space. The menu panel holds the dropdown menu (see [`menu_selection`](@ref) for its entries),
the picking panel the picking toggle and a user name field, the picks panel the compare-picks
toggle. The volume data panel holds the widgets of [`volume_panel!`](@ref) (a data dropdown,
the colorbar limits, a colormap dropdown with a "reverse" checkbox and the same controls for the
contour lines); [`volume_plot_state`](@ref) connects them. The plot panel is made by
[`profile_plot_area!`](@ref). The map overview panel holds the widgets of [`map_panel!`](@ref)
(a "Load topography" button, a label and a map axis; connected by [`map_plot_state`](@ref)). The other collapsible panels are filled when a profile is loaded
(see [`on_profile_loaded`](@ref)); only one of them is expanded at a time (see
[`exclusive_panels!`](@ref)). The topography and profile axes are linked in x.

# Returns
A `NamedTuple` `(; fig, panels, axes, widgets)`:
- `fig`: the figure,
- `panels`: the content `GridLayout` of each menu panel (`main_menu`, `pick_controls`,
  `pick_legend`, `volume_data_panel`, `surface_data_panel`, `point_data_panel`,
  `topography_data_panel`, `compare_picks_panel`, `map_data_panel`, `screenshot_data_panel`),
  plus the layouts `logo`, `plot` and `colorbar`,
- `axes`: `topo_ax`, `profile`, `logo` and `map`,
- `widgets`: `menu`, `pick_toggle`, `pick_name`, `compare_toggle`, the volume data and contour
  controls `volume_*` (see [`volume_panel!`](@ref)), `map_load_button`, `map_label` (see
  [`map_panel!`](@ref)) and the expand / collapse toggles `*_panel_toggle` of the collapsible
  panels (`volume`, `surface`, `point`, `topography`, `compare`, `map`, `screenshot`).

Do not destructure the result into a variable named `axes`: that would shadow `Base.axes` in
your module. The examples use `axis`.

# Example
```julia
profile = Observable{Any}(nothing)
fig, panels, axis, widgets = picker_layout(; profile)
display(fig)
```
"""
function picker_layout(; size = (1200, 1000), profile::Union{Nothing,Observable} = nothing,
                       empty_height = 20,
                       logo_file = joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "AdA_Picker_logo_tr.png"))
    fig = Figure(; size, backgroundcolor = RGBf(0.98, 0.98, 0.98))
    panel!(gp, title; kwargs...) = control_panel!(gp, title; empty_height, kwargs...)

    # top row: menu panels, sized by their content
    main_menu     = panel!(fig[1, 1], ""; color = :darkorange1)
    pick_controls = panel!(fig[1, 2], "Picking")
    pick_legend   = panel!(fig[1, 3], "Picks")
    # the legend column absorbs the remaining width, so the plot panel below spans the window
    contents(fig[1, 3])[1].tellwidth = false

    # dropdown menu (entries are handled by `menu_selection`)
    # default = nothing: start without selection (Menu preselects the first entry otherwise,
    # and choosing it would then not count as a change)
    menu = Menu(main_menu[1, 1]; options = ["Load Profile", "Save State", "Load State", "Save Picks", "Load Picks", "Load Compare Picks", "Save Screenshot", "Close"], prompt = "Menu", default = nothing,
                width = 200, height = 32, fontsize = 16)

    # picking controls as in the original: picking on/off and user name (see `picking_state`)
    toggle_colors = (buttoncolor = RGBf(0.9, 0.9, 0.9), framecolor_inactive = RGBf(0.5, 0.1, 0.1),
                     framecolor_active = RGBf(0.1, 0.5, 0.1))
    Label(pick_controls[1, 1], "Picking")
    pick_toggle = Toggle(pick_controls[1, 2]; active = false, toggle_colors...)
    pick_name = Textbox(pick_controls[1, 3]; width = 100, placeholder = "User name")
    # comparison with other picks
    Label(pick_legend[1, 1], "Compare Picks")
    compare_toggle = Toggle(pick_legend[1, 2]; active = false, toggle_colors...)
    # these panels have their widgets already, so they can follow their content right away
    fit_panel!(main_menu)
    fit_panel!(pick_controls)
    fit_panel!(pick_legend)

    # logo, as in the original: image in an axis without decorations
    logo = fig[1, 4] = GridLayout(width = 250)
    logo_ax = Axis(logo[1, 1]; aspect = DataAspect())
    hidedecorations!(logo_ax)
    hidespines!(logo_ax)
    if isfile(logo_file)
        image!(logo_ax, rotr90(Makie.FileIO.load(logo_file)))
    else
        @warn "Logo not found: $logo_file"
    end

    # left column: plot controls, stacked from the top; the column is as wide as the widest
    # panel, the unused height below the panels stays empty
    plot_controls = fig[2, 1] = GridLayout(valign = :top, tellheight = false)
    # collapsible, with a fixed width so the plot does not move when a panel is collapsed
    collapsible_panel!(gp, title; kwargs...) =
        panel!(gp, title; collapsible = true, expanded = false, width = 340, kwargs...)
    volume_data_panel  = panel!(plot_controls[1, 1], "Volume data (tomographies etc.)";
                                collapsible = true, expanded = true, width = 340)
    surface_data_panel = collapsible_panel!(plot_controls[2, 1], "Surface data (Moho etc.)")
    point_data_panel   = collapsible_panel!(plot_controls[3, 1], "Point data (seismicity etc.)")
    # topography: its axis (vertical profile) or an overlay (horizontal slice); filled by `load_topography_panel!`
    topography_data_panel = collapsible_panel!(plot_controls[4, 1], "Topography")
    # picks of other files, shown for comparison (filled by `load_compare_picks!`)
    compare_picks_panel = collapsible_panel!(plot_controls[5, 1], "Compare picks")
    map_data_panel = collapsible_panel!(plot_controls[6, 1], "Map overview")
    screenshot_data_panel = collapsible_panel!(plot_controls[7, 1], "Screenshot"; color = :grey80)

    # map overview: button to load a topography file (see `map_plot_state`), the name of the
    # loaded file and a map with the aspect ratio of the region (set when topography is loaded)
    map_widgets = map_panel!(map_data_panel)
    map_ax = map_widgets.map_ax

    # only one of the collapsible panels is expanded at a time: expanding one collapses the others
    panel_toggles = exclusive_panels!((volume_data_panel, surface_data_panel, point_data_panel,
                                       topography_data_panel, compare_picks_panel, map_data_panel,
                                       screenshot_data_panel))

    # volume data controls (connected by `volume_plot_state`)
    volume_widgets = volume_panel!(volume_data_panel)

    # plot panel: topography on top, profile below, colorbar and legends at the bottom
    area = profile_plot_area!(fig[2, 2:4])
    plot, topo_ax, colorbar = area.plot, area.topo_ax, area.colorbar
    profile_ax = area.profile   # not `profile`: that is the keyword argument

    panels = (; main_menu, pick_controls, pick_legend, logo,
              volume_data_panel, surface_data_panel, point_data_panel, topography_data_panel, compare_picks_panel,
              map_data_panel, screenshot_data_panel, plot, colorbar)

    # once a profile is loaded, let the menu panels follow their widgets
    if profile !== nothing
        menu_panels = (volume_data_panel, surface_data_panel, point_data_panel,
                       topography_data_panel, compare_picks_panel, map_data_panel, screenshot_data_panel)
        on(profile; priority = -10) do p
            p === nothing && return
            foreach(fit_panel!, menu_panels)
        end
    end
    axes = (; topo_ax, profile = profile_ax, logo = logo_ax, map = map_ax)
    widgets = (; menu, pick_toggle, pick_name, compare_toggle, volume_widgets...,
               map_load_button = map_widgets.map_load_button, map_label = map_widgets.map_label,
               volume_panel_toggle = panel_toggles[1], surface_panel_toggle = panel_toggles[2],
               point_panel_toggle = panel_toggles[3], topography_panel_toggle = panel_toggles[4],
               compare_panel_toggle = panel_toggles[5], map_panel_toggle = panel_toggles[6],
               screenshot_panel_toggle = panel_toggles[7])

    return (; fig, panels, axes, widgets)
end


"""
    profile_plot_area!(gp; topography = true) -> NamedTuple

Create the plot panel of a profile GUI at the grid position `gp` (the plot panel of
[`picker_layout`](@ref)):

    ┌────────────────────────────────────────────┐
    │ topography axis (20 % of the height)       │
    ├────────────────────────────────────────────┤
    │ profile axis                               │
    │                                            │
    ├──────────┬─────────┬─────────┬─────────────┤
    │ colorbars│ surface │ point   │ compare     │  colorbar layout (160 px)
    │          │ legend  │ legend  │ legend      │
    └──────────┴─────────┴─────────┴─────────────┘

The topography axis has no decorations and is linked to the profile axis in x; the profile
axis has no grid (it would show through the heatmap). The colorbar layout holds the colorbars
of the volume data in its first column (see [`volume_plot_state`](@ref)) and right of them the
legends of the surface data, point data and compared picks, in this order. The legends are
packed from the left: a legend that does not exist (e.g. no surface data) leaves no gap.
Requires nothing but a figure; the axes are meant for GeophysicalModelGenerator profiles.

# Arguments
- `gp`: grid position, e.g. `fig[1, 2]`.

# Keywords
- `topography`: `false` creates no topography axis (`topo_ax` is then `nothing`), the profile
  axis takes the whole height.

# Returns
A `NamedTuple` `(; plot, topo_ax, profile, colorbar)`: the layout of the plot panel, the
topography axis, the profile axis and the colorbar layout. It has the fields of the `axes`
(`profile`, `topo_ax`) and `panels` (`plot`, `colorbar`) of [`picker_layout`](@ref) that the
plot states and [`connect_profile!`](@ref) use, so it can be passed as either.

# Example
```julia
fig = Figure()
area = profile_plot_area!(fig[1, 2])
panel = control_panel!(fig[1, 1], "Volume data"; width = 340)
volume = volume_plot_state(area.profile, volume_panel!(panel), area.colorbar)
```
"""
function profile_plot_area!(gp; topography::Bool = true)
    plot = gp[] = GridLayout()
    topo_ax = nothing
    if topography
        topo_ax = Axis(plot[1, 1])
        hidedecorations!(topo_ax)
        hidespines!(topo_ax)
    end
    # no grid, it would show through the heatmap
    profile = Axis(plot[2:3, 1]; xgridvisible = false, ygridvisible = false)
    topo_ax === nothing || linkxaxes!(profile, topo_ax)
    colorbar = plot[4, 1] = GridLayout(height = 160, tellheight = false, tellwidth = false)
    rowgap!(plot, 0)
    rowsize!(plot, 1, topography ? Relative(0.2) : Fixed(0))
    return (; plot, topo_ax, profile, colorbar)
end

# size of the row of each topography axis while it is shown (see `set_profile_layout!`)
const TOPO_ROW_SIZES = IdDict{Axis,Any}()

"""
    set_profile_layout!(axes, profile; show_topography = true)

Adapt the plot panel to the type of `profile`: a vertical cross-section gets the topography
axis above the profile axis. For a horizontal slice the topography axis is hidden and the
profile axis takes its space; the profile axis then shows longitude / latitude and the depth of
the slice as its title. Requires a GeophysicalModelGenerator `ProfileData`.

The topography axis is hidden by shrinking the layout row it sits in to zero height (its
original size is restored when it is shown again), so it can be in any row of any layout.

# Arguments
- `axes`: a `NamedTuple` with the profile axis `profile` and, optionally, the topography axis
  `topo_ax` (`nothing` or missing: only the profile axis is adapted), e.g. the `axes` of
  [`picker_layout`](@ref) or the result of [`profile_plot_area!`](@ref).
- `profile`: the loaded profile (`nothing` is treated as vertical).

# Keywords
- `show_topography`: set to `false` to hide the topography axis of a vertical profile as well
  (e.g. if it has no topography data).

Returns `nothing`.
"""
function set_profile_layout!(axes, profile; show_topography::Bool = true)
    vertical = is_vertical(profile)
    topo_ax = get(axes, :topo_ax, nothing)
    if topo_ax !== nothing
        show_topo = vertical && show_topography
        topo_ax.blockscene.visible[] = show_topo
        # the row of the layout that holds the topography axis
        content = Makie.GridLayoutBase.gridcontent(topo_ax)
        layout, row = content.parent, first(content.span.rows)
        shown_size = get!(TOPO_ROW_SIZES, topo_ax, layout.rowsizes[row])
        rowsize!(layout, row, show_topo ? shown_size : Fixed(0))
    end
    ax = axes.profile
    ax.xlabel = vertical ? "" : "Longitude"
    ax.ylabel = vertical ? "" : "Latitude"
    ax.title = vertical ? "" : "Depth: $(round(slice_depth(profile); digits = 1)) km"
    return nothing
end

# legends in the colorbar layout of `profile_plot_area!`, by colorbar layout and kind; they are
# placed right of the colorbars in this order
const LEGEND_ORDER = (:surface, :points, :compare)
const LEGENDS = IdDict{GridLayout,Dict{Symbol,Any}}()

# Replace the legend `key` (one of `LEGEND_ORDER`) of the colorbar layout `colorbar` by the one
# that `build(gp)` creates at the grid position `gp` (`nothing`: remove it) and pack all legends
# of the layout from the left, right of the colorbars and without empty columns between them.
# Returns the new legend (or `nothing`).
function place_legend!(build::Union{Function,Nothing}, colorbar::GridLayout, key::Symbol)
    GLB = Makie.GridLayoutBase
    legends = get!(() -> Dict{Symbol,Any}(), LEGENDS, colorbar)
    old = pop!(legends, key, nothing)
    old === nothing || delete!(old)
    if build !== nothing
        # created in a new column, so it overlaps nothing until the legends are packed
        legends[key] = build(colorbar[1:2, GLB.ncols(colorbar) + 1])
    end
    # the legends start in column 2 if column 1 holds the colorbars, otherwise in column 1
    is_legend(c) = any(l -> l === c.content, values(legends))
    col = any(c -> !is_legend(c) && 1 in c.span.cols, colorbar.content) ? 2 : 1
    for k in sort!(collect(keys(legends)); by = k -> something(findfirst(==(k), LEGEND_ORDER), 99))
        colorbar[1:2, col] = legends[k]
        col += 1
    end
    # remove the empty columns at the end (an empty column would take the free width)
    used = maximum((last(c.span.cols) for c in colorbar.content); init = 1)
    while GLB.ncols(colorbar) > used
        GLB.deletecol!(colorbar, GLB.ncols(colorbar))
    end
    return build === nothing ? nothing : legends[key]
end
place_legend!(colorbar::GridLayout, key::Symbol, ::Nothing) = place_legend!(nothing, colorbar, key)
