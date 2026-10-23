"""
    map_panel!(panel::GridLayout; width = 250, height = 200) -> NamedTuple

Create the widgets of the map overview in the layout `panel` (the content of a
[`control_panel!`](@ref)) and let the panel follow their size ([`fit_panel!`](@ref)): a "Load
topography" button, a label with the name of the loaded topography file and a map axis
(longitude / latitude). These are the widgets of the map overview panel of
[`picker_layout`](@ref); they do nothing until [`map_plot_state`](@ref) connects them. Requires
nothing but a layout; the map is meant for the profile line of a GeophysicalModelGenerator
`ProfileData`.

# Arguments
- `panel`: the (empty) content layout of a panel made by [`control_panel!`](@ref).

# Keywords
- `width`, `height`: initial size of the map axis in pixels (it gets the aspect ratio of the
  region once a profile or a topography is shown, at most 250 × 300).

# Returns
A `NamedTuple` `(; map_ax, map_load_button, map_label)`: the map `Axis`, the `Button` and the
`Label`, named as in the `axes` (`map`) and `widgets` of [`picker_layout`](@ref).

# Example
```julia
fig = Figure()
panel = control_panel!(fig[1, 1], "Map overview"; collapsible = true, width = 340)
map_widgets = map_panel!(panel)
topomap = map_plot_state(map_widgets.map_ax, map_widgets.map_load_button, map_widgets.map_label)
```
"""
function map_panel!(panel::GridLayout; width = 250, height = 200)
    map_load_button = Button(panel[1, 1]; label = "Load topography", fontsize = 14,
                             width = 130, cornerradius = 4)
    map_label = Label(panel[1, 2], "no topography loaded"; fontsize = 12, halign = :left)
    map_ax = Axis(panel[2, 1:2]; width, height, halign = :left,
                  xticklabelsize = 11, yticklabelsize = 11, xlabel = "lon", ylabel = "lat",
                  xlabelsize = 11, ylabelsize = 11)
    fit_panel!(panel)
    return (; map_ax, map_load_button, map_label)
end

"""
    map_plot_state(ax::Axis, load_button = nothing, label = nothing) -> NamedTuple
    map_plot_state(axes, widgets) -> NamedTuple

Create the state of the map overview: the profile line in the map axis `ax` (a white line with
a red one on top, from the start to the end point of the profile, empty until a profile is
loaded) and, if given, connect the `load_button`, which asks for a file and calls
[`load_topography!`](@ref). Created once, before a profile is loaded;
[`update_map_line!`](@ref) draws each loaded profile (called by [`connect_profile!`](@ref) for
the state `topomap`). Meant for a GeophysicalModelGenerator `ProfileData`.

# Arguments
- `ax`: the map axis, e.g. `map_ax` of [`map_panel!`](@ref).
- `load_button`: a `Button` that loads a topography file (a JLD2 file with a `GeoData`), or
  `nothing` (load topography from code with [`load_topography!`](@ref)).
- `label`: a `Label` that shows the name of the loaded topography file, or `nothing`.
- `axes`, `widgets`: as returned by [`picker_layout`](@ref); `axes.map`,
  `widgets.map_load_button` and `widgets.map_label` are used.

# Returns
A `NamedTuple` with the map axis `ax`, the `label`, the Observables of the profile line
(`line_points`) and of its labels (`markers`), and `Ref`s to the topography `heatmap`, its
`extent` and the `path` of the loaded topography file (`""` if none).

# Example
```julia
fig = Figure()
panel = control_panel!(fig[1, 1], "Map overview"; collapsible = true, width = 340)
map_widgets = map_panel!(panel)
topomap = map_plot_state(map_widgets.map_ax, map_widgets.map_load_button, map_widgets.map_label)
load_topography!(topomap, "path/to/etopo1.jld2")
```
"""
function map_plot_state(ax::Axis, load_button = nothing, label = nothing)
    line_points = Observable(Point2{Float64}[])
    halo = lines!(ax, line_points; color = :white, linewidth = 4)
    line = lines!(ax, line_points; color = :red, linewidth = 2)
    translate!(halo, 0, 0, 10)
    translate!(line, 0, 0, 11)
    # A and B mark the start and the end of the profile; for a horizontal slice a label with its depth
    markers = Observable(Tuple{String,Point2f}[])
    text!(ax, markers; font = :bold, fontsize = 16, align = (:center, :bottom), offset = (0, 6),
          color = :black, strokecolor = :white, strokewidth = 3)

    state = (; ax, label, line_points, markers, heatmap = Ref{Any}(nothing),
             extent = Ref{Any}(nothing), path = Ref(""))
    if load_button !== nothing
        on(load_button.clicks) do _
            with_open_dialog(; filter = "jld2") do path
                load_topography!(state, path)
            end
        end
    end
    return state
end
map_plot_state(axes, widgets) = map_plot_state(axes.map, widgets.map_load_button, widgets.map_label)

"""
    load_topography!(state, path)

Load the topography file `path` (a JLD2 file holding a `GeoData` object, e.g. `etopo1.jld2`)
and plot it in the map overview as a heatmap with the `oleron` colormap, centred around zero,
replacing the previous one. Only every n-th grid point is plotted, so that large grids stay
responsive. The map is shown with the aspect ratio of the region, and the label of the state
(if any) shows the file name. Needs no profile, but the topography file has to hold a
GeophysicalModelGenerator `GeoData`.

# Arguments
- `state`: the map state of [`map_plot_state`](@ref).
- `path`: the topography file.

Returns the `GeoData` that was plotted; throws an error if the file holds no `GeoData`.
"""
function load_topography!(state, path::AbstractString)
    data = JLD2.load(path)
    geos = [v for v in values(data) if v isa GeophysicalModelGenerator.GeoData]
    isempty(geos) && error("$path does not contain a GeoData object")
    geo = first(geos)

    # regular grid: the first column holds lon, the first row holds lat; elevation in the depth field
    step_x = cld(size(geo.depth.val, 1), 1000)
    step_y = cld(size(geo.depth.val, 2), 1000)
    x = Vector{Float64}(geo.lon.val[1:step_x:end, 1, 1])
    y = Vector{Float64}(geo.lat.val[1, 1:step_y:end, 1])
    z = Float64.(geo.depth.val[1:step_x:end, 1:step_y:end, 1])

    state.heatmap[] === nothing || delete!(state.ax, state.heatmap[])
    finite = filter(isfinite, z)
    m = isempty(finite) ? 1.0 : max(maximum(abs, finite), eps())
    state.heatmap[] = heatmap!(state.ax, x, y, z; colormap = :oleron, colorrange = (-m, m))
    translate!(state.heatmap[], 0, 0, -50)

    state.extent[] = (extrema(x), extrema(y))
    state.path[] = abspath(path)
    state.label === nothing || (state.label.text[] = basename(path))
    fit_map!(state)
    return geo
end

"""
    fit_map!(state)

Set limits and aspect ratio of the map to the loaded topography, or, as long as there is none, to
the profile line. Internal helper of the map overview.
"""
function fit_map!(state)
    extent = state.extent[]
    if extent === nothing
        points = state.line_points[]
        isempty(points) && return
        lon = extrema(p[1] for p in points)
        lat = extrema(p[2] for p in points)
        padx = max(0.1 * (lon[2] - lon[1]), 0.1)
        pady = max(0.1 * (lat[2] - lat[1]), 0.1)
        extent = ((lon[1] - padx, lon[2] + padx), (lat[1] - pady, lat[2] + pady))
    end
    (xmin, xmax), (ymin, ymax) = extent
    # a margin of 4 %, so that the labels of the profile ends are not cut off at the map edge
    padx, pady = 0.04 * (xmax - xmin), 0.04 * (ymax - ymin)
    xmin, xmax, ymin, ymax = xmin - padx, xmax + padx, ymin - pady, ymax + pady
    limits!(state.ax, xmin, xmax, ymin, ymax)
    # axis box with the shape of the region: a degree of longitude is cos(lat) times as long as
    # a degree of latitude; at most 250 wide and 300 high
    ratio = cosd((ymin + ymax) / 2) * (xmax - xmin) / (ymax - ymin)
    width = min(250, 300 * ratio)
    state.ax.width = width
    state.ax.height = width / ratio
end

"""
    update_map_line!(state, profile)

Draw the profile in the map overview, replacing the previous one: a vertical profile as a line
from its start to its end point (marked "A" and "B"), a horizontal slice as a box of its lon / lat
extent labelled with its depth. Without a loaded topography the map limits follow the profile.
Called by [`connect_profile!`](@ref) for the state `topomap`. Requires a
GeophysicalModelGenerator `ProfileData`.

# Arguments
- `state`: the map state of [`map_plot_state`](@ref).
- `profile`: the loaded profile.
"""
function update_map_line!(state, profile)
    if is_vertical(profile)
        start, stop = profile.start_lonlat, profile.end_lonlat
        state.line_points[] = (start === nothing || stop === nothing) ? Point2{Float64}[] :
                              [Point2{Float64}(start...), Point2{Float64}(stop...)]
        state.markers[] = [(string(name), Point2f(point))
                           for (name, point) in zip("AB", state.line_points[])]
    else
        # horizontal slice: its lon / lat extent as a box, labelled with the depth
        corners = slice_extent(profile)
        if corners === nothing
            state.line_points[] = Point2{Float64}[]
            state.markers[] = Tuple{String,Point2f}[]
        else
            (xmin, xmax), (ymin, ymax) = corners
            state.line_points[] = Point2{Float64}[(xmin, ymin), (xmax, ymin), (xmax, ymax),
                                                  (xmin, ymax), (xmin, ymin)]
            state.markers[] = [("$(round(slice_depth(profile); digits = 1)) km",
                                Point2f((xmin + xmax) / 2, ymax))]
        end
    end
    fit_map!(state)
end

# lon / lat extent `((lonmin, lonmax), (latmin, latmax))` of the volume data of a horizontal
# slice (or of its first surface / point data set), `nothing` if it has none
function slice_extent(profile)
    geos = Any[]
    vol = profile.VolData
    vol === nothing || append!(geos, vol isa NamedTuple ? collect(values(vol)) : [vol])
    for sets in (profile.SurfData, profile.PointData)
        sets === nothing || append!(geos, collect(values(sets)))
    end
    for g in geos
        isempty(g.lon.val) && continue
        lon, lat = filter(isfinite, g.lon.val), filter(isfinite, g.lat.val)
        isempty(lon) || isempty(lat) || return extrema(lon), extrema(lat)
    end
    return nothing
end

