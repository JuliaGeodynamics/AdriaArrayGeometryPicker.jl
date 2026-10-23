"""
    volume_entries(voldata) -> Vector{Tuple{String,Tuple}}

Dropdown entries `(label, (geodata, fieldname))` for all data fields in `voldata`, which is
`nothing`, a single `GeoData` (as GeophysicalModelGenerator declares `VolData`) or a NamedTuple
of them (also accepted by this package). The coordinate fields (`*x_profile`) and
the `*FlatCrossSection` fields are left out. A field name that occurs in several `GeoData` objects gets the key of its object as
prefix.
"""
function volume_entries(voldata)
    voldata === nothing && return Tuple{String,Tuple}[]
    geos = voldata isa NamedTuple ? collect(pairs(voldata)) : [:volume => voldata]
    hidden(f) = endswith(string(f), "x_profile") || endswith(string(f), "FlatCrossSection")
    datafields(g) = [f for f in keys(g.fields) if !hidden(f)]
    names = [f for (_, g) in geos for f in datafields(g)]
    return Tuple{String,Tuple}[((count(==(f), names) > 1 ? "$k: $f" : string(f)), (g, f))
                               for (k, g) in geos for f in datafields(g)]
end

"""
    surface_entries(profile) -> Vector{Tuple{String,Tuple}}

Dropdown entries `("name: depth", (geodata, :depth))` for the surface data sets
of a horizontal slice, which can be plotted like volume data (the depth of the
surface is the value). Sets that only contain NaN are left out.
"""
surface_entries(profile) = Tuple{String,Tuple}[("$(s.name): depth", (s.geo, :depth))
                                               for s in horizontal_surfaces(profile)]

# names of the colormaps offered by `volume_panel!`: matplotlib and the continuous scientific
# colour maps (Crameri); the category "scientific" only holds their discrete variants
# (batlow10, batlowS, ...)
function colormap_names()
    categories = ("matplotlib", "scientific colour-maps (crameri)")
    return sort!([string(name) for (name, scheme) in ColorSchemes.colorschemes
                  if scheme.category in categories]; by = lowercase)
end

"""
    volume_panel!(panel::GridLayout; contours = true, colormaps = <all matplotlib and Crameri maps>,
                  colormap = "viridis", contour_colormap = "coolwarm") -> NamedTuple

Create the widgets of the volume data panel in the layout `panel` (e.g. the content of a
[`control_panel!`](@ref)) and let the panel follow their size ([`fit_panel!`](@ref)). These are
the widgets of the volume data panel of [`picker_layout`](@ref); they do nothing until
[`volume_plot_state`](@ref) connects them. Requires nothing but a layout; the widgets are meant
for the volume data of a GeophysicalModelGenerator `ProfileData`.

The rows of `panel`, from the top: a dropdown for the data field, the colorbar limits (min / max
text fields around an interval slider), a label with the current limits, a colormap dropdown
with a "reverse" checkbox; with `contours = true` also the same controls for contour lines of a
second field (dropdown with a "show" toggle, colormap with "reverse" checkbox, colour range) and
a text field for the contour levels.

# Arguments
- `panel`: the (empty) content layout of a panel made by [`control_panel!`](@ref).

# Keywords
- `contours`: `false` leaves out the contour line widgets (the volume data are then only shown
  as a heatmap).
- `colormaps`: the names of the colormaps in the colormap dropdowns.
- `colormap`, `contour_colormap`: the initially selected colormaps.

# Returns
A `NamedTuple` of the widgets, named as in the `widgets` of [`picker_layout`](@ref):
`volume_menu`, `volume_cbar_min`, `volume_cbar_slider`, `volume_cbar_max`, `volume_cbar_label`,
`volume_cmap_menu`, `volume_cmap_reverse` and, with `contours = true`, `volume_contour_menu`,
`volume_contour_toggle`, `volume_contour_cmap_menu`, `volume_contour_cmap_reverse`,
`volume_contour_cbar_min`, `volume_contour_cbar_slider`, `volume_contour_cbar_max` and
`volume_contour_levels`.

# Example
```julia
fig = Figure()
area = profile_plot_area!(fig[1, 2])
panel = control_panel!(fig[1, 1], "Volume data"; collapsible = true, width = 340)
widgets = volume_panel!(panel; colormaps = ["viridis", "roma", "coolwarm"])
volume = volume_plot_state(area.profile, widgets, area.colorbar)
```
"""
function volume_panel!(panel::GridLayout; contours::Bool = true, colormaps = colormap_names(),
                       colormap = "viridis", contour_colormap = "coolwarm")
    volume_menu = Menu(panel[1, 1]; options = ["Placeholder"], width = 250)
    # colorbar limits: min text field, slider, max text field; each row has its own layout so
    # the widths of one row do not change the columns of the others
    cbar_row = panel[2, 1] = GridLayout()
    volume_cbar_min = Textbox(cbar_row[1, 1]; width = 65, placeholder = "min", validator = Float64)
    volume_cbar_slider = IntervalSlider(cbar_row[1, 2]; range = LinRange(0, 1, 101), width = 130)
    volume_cbar_max = Textbox(cbar_row[1, 3]; width = 65, placeholder = "max", validator = Float64)
    volume_cbar_label = Label(panel[3, 1], "Colorbar limits: –"; halign = :left)
    # colormap and whether it is reversed
    cmap_row = panel[4, 1] = GridLayout()
    volume_cmap_menu = Menu(cmap_row[1, 1]; options = colormaps, default = colormap, width = 150)
    volume_cmap_reverse = Checkbox(cmap_row[1, 2]; checked = false)
    Label(cmap_row[1, 3], "reverse")
    widgets = (; volume_menu, volume_cbar_min, volume_cbar_slider, volume_cbar_max,
               volume_cbar_label, volume_cmap_menu, volume_cmap_reverse)
    if !contours
        fit_panel!(panel)
        return widgets
    end

    # additional volume data as contour lines: field and visibility, colormap with reverse
    # checkbox, colour range (same layout as the colorbar limits above) and optional levels
    contour_row = panel[5, 1] = GridLayout()
    volume_contour_menu = Menu(contour_row[1, 1]; options = ["Placeholder"], width = 200)
    volume_contour_toggle = Toggle(contour_row[1, 2]; active = true)
    Label(contour_row[1, 3], "contour: show")
    contour_cmap_row = panel[6, 1] = GridLayout()
    volume_contour_cmap_menu = Menu(contour_cmap_row[1, 1]; options = colormaps,
                                    default = contour_colormap, width = 150)
    volume_contour_cmap_reverse = Checkbox(contour_cmap_row[1, 2]; checked = false)
    Label(contour_cmap_row[1, 3], "contour: reverse")
    contour_range_row = panel[7, 1] = GridLayout()
    Label(contour_range_row[1, 1:3], "contour: color range"; fontsize = 13, halign = :left)
    volume_contour_cbar_min = Textbox(contour_range_row[2, 1]; width = 65,
                                      placeholder = "min", validator = Float64)
    volume_contour_cbar_slider = IntervalSlider(contour_range_row[2, 2];
                                                range = LinRange(0, 1, 101), width = 130)
    volume_contour_cbar_max = Textbox(contour_range_row[2, 3]; width = 65,
                                      placeholder = "max", validator = Float64)
    volume_contour_levels = Textbox(panel[8, 1]; width = 250,
                                    placeholder = "Contour levels, e.g. -2, 0, 2 (auto)")
    fit_panel!(panel)
    return (; widgets..., volume_contour_menu, volume_contour_toggle, volume_contour_cmap_menu,
            volume_contour_cmap_reverse, volume_contour_cbar_min, volume_contour_cbar_slider,
            volume_contour_cbar_max, volume_contour_levels)
end

# colormap of a dropdown with a "reverse" checkbox: a Symbol or a Reverse
function connect_colormap!(colormap::Observable, menu, reverse)
    onany(menu.selection, reverse.checked; update = true) do name, rev
        name === nothing && return
        colormap[] = rev ? Reverse(Symbol(name)) : Symbol(name)
    end
end

"""
    volume_plot_state(ax::Axis, widgets, colorbar::GridLayout) -> NamedTuple
    volume_plot_state(axes, panels, widgets) -> NamedTuple

Create the colorbars of the volume data and connect the volume data widgets (field dropdown,
colorbar limits slider and text fields, colormap dropdown and reverse checkbox, and the same
for the contour lines with their own colorbar and levels). Returns the state that
[`load_volume_data!`](@ref) fills when a profile is loaded. Created once, before a profile is
loaded; the plots follow the widgets from then on. Works for vertical and horizontal
GeophysicalModelGenerator profiles alike.

# Arguments
- `ax`: the profile axis, in which the heatmap and the contour lines are plotted.
- `widgets`: the widgets made by [`volume_panel!`](@ref) (any `NamedTuple` with these fields,
  e.g. the `widgets` of [`picker_layout`](@ref)). Without the `volume_contour_*` widgets
  (`volume_panel!(panel; contours = false)`) there are no contour lines and no contour colorbar.
- `colorbar`: the layout for the colorbars (see [`profile_plot_area!`](@ref)). The colorbar of
  the heatmap and its title go into the rows 1 and 2 of its first column, those of the contour
  lines into the rows 3 and 4.
- `axes`, `panels`: as returned by [`picker_layout`](@ref); `axes.profile` and
  `panels.colorbar` are used.

# Returns
A `NamedTuple` with the plots (`heatmap`, `contour`: `Ref`s), the Observables they follow
(`colormap`, `colorrange`, `contour_colormap`, `contour_colorrange`, `levels`), the profile
axis `ax`, the `widgets` and a few internal fields. `contours` says whether there are contour
lines.

# Example
```julia
fig = Figure()
area = profile_plot_area!(fig[1, 2])
panel = control_panel!(fig[1, 1], "Volume data"; width = 340)
volume = volume_plot_state(area.profile, volume_panel!(panel), area.colorbar)
profile = Observable{Any}(nothing)
connect_profile!(profile, (; volume); axes = area)    # or call `load_volume_data!` yourself
load_profile!(profile, joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "Profile1.pgmg"))
```
"""
function volume_plot_state(ax::Axis, widgets, colorbar::GridLayout)
    slider = widgets.volume_cbar_slider
    colorrange = Observable((0.0, 1.0))
    colormap = Observable{Any}(:viridis)   # a Symbol or a Reverse
    connect_colormap!(colormap, widgets.volume_cmap_menu, widgets.volume_cmap_reverse)

    Colorbar(colorbar[1, 1]; colormap, limits = colorrange, vertical = false, width = 300)
    cbar_title = Label(colorbar[2, 1], "")

    # slider -> colorbar limits, label and text fields; text fields -> slider
    link_range_controls!(slider, widgets.volume_cbar_min, widgets.volume_cbar_max, colorrange,
                         widgets.volume_cbar_label)

    # the same for the contour lines (if there are widgets for them), with their own colormap
    # and colour range
    contours = haskey(widgets, :volume_contour_menu)
    contour_colorrange = Observable((0.0, 1.0))
    contour_colormap = Observable{Any}(:coolwarm)
    levels = Observable(collect(range(0.0, 1.0; length = 10)))
    contour_slider = contour_cbar_title = nothing
    if contours
        contour_slider = widgets.volume_contour_cbar_slider
        connect_colormap!(contour_colormap, widgets.volume_contour_cmap_menu,
                          widgets.volume_contour_cmap_reverse)
        link_range_controls!(contour_slider, widgets.volume_contour_cbar_min,
                             widgets.volume_contour_cbar_max, contour_colorrange)

        # contour levels: the ones typed in the text field, otherwise 10 regular ones in the
        # colour range of the contour lines
        onany(contour_colorrange, widgets.volume_contour_levels.stored_string; update = true) do (lo, hi), text
            manual = parse_levels(text)
            levels[] = manual === nothing ? collect(range(lo, hi; length = 10)) : manual
        end

        # colorbar of the contour lines below the one of the heatmap; hidden while the lines are
        contour_cbar = Colorbar(colorbar[3, 1]; colormap = contour_colormap,
                                limits = contour_colorrange, vertical = false, width = 300)
        contour_cbar_title = Label(colorbar[4, 1], "")
        on(widgets.volume_contour_toggle.active; update = true) do visible
            contour_cbar.blockscene.visible[] = visible
            contour_cbar_title.visible[] = visible
        end
    end

    state = (; heatmap = Ref{Any}(nothing), contour = Ref{Any}(nothing), loading = Ref(false),
             contours, colormap, colorrange, contour_colormap, contour_colorrange, contour_slider,
             contour_cbar_title, levels, slider, cbar_title, ax, widgets)
    # field dropdowns -> heatmap / contours
    on(widgets.volume_menu.selection) do entry
        state.loading[] && return
        entry isa Tuple && plot_volume!(state, entry...)
    end
    contours && on(widgets.volume_contour_menu.selection) do entry
        state.loading[] && return
        entry isa Tuple && plot_contours!(state, entry...)
    end
    return state
end
volume_plot_state(axes, panels, widgets) = volume_plot_state(axes.profile, widgets, panels.colorbar)

"""
    load_volume_data!(state, profile) -> nothing

Fill the field dropdowns with the data fields of `profile.VolData` and plot the first one as a
heatmap and as contour lines (`plot_volume!`, `plot_contours!`), replacing the plots of the
previous profile. On a horizontal slice the depth of the `SurfData` entries is offered as
additional fields. Without volume data the dropdowns say so and the previous plots are removed.
Called by [`connect_profile!`](@ref) for the state `volume`. Requires a GeophysicalModelGenerator
`ProfileData`.

GeophysicalModelGenerator declares `VolData` as a single `GeoData` (or `nothing`); this package
also accepts a `NamedTuple` of `GeoData`, whose fields are then all offered (a field name that
occurs in several of them gets the key as prefix).

On a vertical profile the heatmap is over the distance along the profile and the depth; on a
horizontal slice over longitude and latitude.

# Arguments
- `state`: the volume state of [`volume_plot_state`](@ref) (without contour widgets only the
  heatmap is plotted).
- `profile`: the loaded profile.

Returns `nothing`.
"""
function load_volume_data!(state, profile)
    entries = volume_entries(profile.VolData)
    is_vertical(profile) || append!(entries, surface_entries(profile))
    menus = state.contours ? (state.widgets.volume_menu, state.widgets.volume_contour_menu) :
                             (state.widgets.volume_menu,)
    if isempty(entries)
        # no volume data: remove what the previous profile left behind
        state.heatmap[] === nothing || delete!(state.ax, state.heatmap[])
        state.heatmap[] = nothing
        clear_contours!(state)
        state.loading[] = true
        try
            for menu in menus
                menu.options[] = [("No volume data", nothing)]
                menu.i_selected[] = 1
            end
        finally
            state.loading[] = false
        end
        state.cbar_title.text[] = ""
        state.widgets.volume_cbar_label.text[] = "Colorbar limits: –"
        return
    end
    state.loading[] = true      # the plots are made once below, not by the selection listeners
    try
        for menu in menus
            menu.options[] = entries
            menu.i_selected[] = 1
        end
    finally
        state.loading[] = false
    end
    plot_volume!(state, entries[1][2]...)
    state.contours && plot_contours!(state, entries[1][2]...)
    return nothing
end

# x, y and the 2D values of `field` in `geo` (regular grid: the first column holds x, the
# first row holds y). Vertical profile: x is the distance along the profile, y the depth.
# Horizontal slice (no `x_profile`): x is the longitude, y the latitude. The field `:depth` is
# the depth of a surface data set (`geo.depth`).
function grid_data(geo, field)
    if haskey(geo.fields, :x_profile)
        x = Vector{Float64}(geo.fields.x_profile[:, 1, 1])
        y = Vector{Float64}(geo.depth.val[1, :, 1])
    else
        x = Vector{Float64}(geo.lon.val[:, 1, 1])
        y = Vector{Float64}(geo.lat.val[1, :, 1])
    end
    raw = field === :depth && !haskey(geo.fields, :depth) ? geo.depth.val : geo.fields[field]
    values = Float64.(ustrip.(raw)[:, :, 1])
    return x, y, values
end

"""
    plot_contours!(state, geo::GeoData, field::Symbol)

Plot `field` of `geo` as contour lines on top of the heatmap, replacing the previous ones. The
levels follow `state.levels`, the lines are coloured with the contour colormap and colour range
(own slider, range: plus/minus the largest absolute value of `field`) and are visible as long
as the contour toggle is on. Their colorbar (created in [`volume_plot_state`](@ref)) sits below
the one of the heatmap and is titled with the field name.
"""
function plot_contours!(state, geo, field::Symbol)
    clear_contours!(state)
    x, y, values = grid_data(geo, field)
    finite = filter(isfinite, values)
    m = isempty(finite) ? 1.0 : maximum(abs, finite)
    m == 0 && (m = 1.0)
    state.contour_slider.range[] = LinRange(-m, m, 1000)
    set_close_to!(state.contour_slider, -m, m)

    contours = contour!(state.ax, x, y, values; levels = state.levels,
                        colormap = state.contour_colormap, colorrange = state.contour_colorrange,
                        linewidth = 1.5, visible = state.widgets.volume_contour_toggle.active)
    translate!(contours, 0, 0, 5)   # above the heatmap, below surface lines and points
    state.contour[] = contours
    state.contour_cbar_title.text[] = string("contour: ", field)
    return contours
end

"""
    clear_contours!(state)

Remove the contour lines and the title of their colorbar.
"""
function clear_contours!(state)
    state.contours || return
    state.contour[] === nothing || delete!(state.ax, state.contour[])
    state.contour[] = nothing
    state.contour_cbar_title.text[] = ""
end

"""
    plot_volume!(state, geo::GeoData, field::Symbol)

Plot `field` of `geo` as a heatmap in the profile axis, replacing the previous one, and adapt
the colorbar slider (range and initial limits: minus/plus the largest absolute value of the
field, so they are symmetric around zero) and the colorbar title.
"""
function plot_volume!(state, geo, field::Symbol)
    ax = state.ax
    state.heatmap[] === nothing || delete!(ax, state.heatmap[])

    x, y, values = grid_data(geo, field)

    state.heatmap[] = heatmap!(ax, x, y, values; colormap = state.colormap,
                               colorrange = state.colorrange)
    translate!(state.heatmap[], 0, 0, -50)   # below lines and points, but above the grid (z = -100)

    finite = filter(isfinite, values)
    m = isempty(finite) ? 1.0 : maximum(abs, finite)
    m == 0 && (m = 1.0)
    state.slider.range[] = LinRange(-m, m, 1000)
    set_close_to!(state.slider, -m, m)
    state.cbar_title.text[] = string(field)
    # fixed to the volume data, so points outside the profile do not stretch the axes (the limits
    # of a horizontal slice are set by `fit_horizontal_axis!`)
    haskey(geo.fields, :x_profile) && limits!(ax, extrema(x)..., extrema(y)...)
    return state.heatmap[]
end

