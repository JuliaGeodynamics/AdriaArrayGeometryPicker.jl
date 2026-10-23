# bright colours of the point data sets, visible on the heatmaps (and unlike the surface lines)
const POINT_COLORS = [colorant"#ff00ff", colorant"#ff8000", colorant"#00e5ff", colorant"#ffee00",
                      colorant"#ff1744", colorant"#76ff03", colorant"#ffffff"]

"""
    point_plot_state(ax::Axis, panel::GridLayout, colorbar::GridLayout) -> NamedTuple
    point_plot_state(axes, panels) -> NamedTuple

State for the point data: what [`load_point_data!`](@ref) created for the current profile
(toggles and labels in the point data panel, scatter plots in the profile axis, the legend).
Created once, before a profile is loaded; it creates nothing itself. Meant for a
GeophysicalModelGenerator `ProfileData`.

# Arguments
- `ax`: the profile axis.
- `panel`: the (empty) layout for the toggles, e.g. the content of a [`control_panel!`](@ref).
- `colorbar`: the colorbar layout (see [`profile_plot_area!`](@ref)); the legend goes right of
  the colorbars and the surface data legend (if there is one).
- `axes`, `panels`: as returned by [`picker_layout`](@ref); `axes.profile`,
  `panels.point_data_panel` and `panels.colorbar` are used.

Returns the state, a `NamedTuple` with the fields `ax`, `panel`, `colorbar`, the plots, the
toggles with their `labels` and the `legend` (`Ref`).
"""
point_plot_state(ax::Axis, panel::GridLayout, colorbar::GridLayout) =
    (; ax, panel, colorbar, blocks = Any[], plots = Any[], toggles = Any[], labels = String[],
       legend = Ref{Any}(nothing))
point_plot_state(axes, panels) = point_plot_state(axes.profile, panels.point_data_panel, panels.colorbar)

"""
    load_point_data!(state, profile) -> nothing

Replace the point data of the previous profile by `profile.PointData`: for each dataset a label
and a toggle in the point data panel, a scatter plot in the profile axis (`x_profile` against
`depth_proj`, visible as long as the toggle is on) and an entry in the "Point data" legend,
right of the surface data legend if there is one (greyed out by Makie while the toggle is off).
For a horizontal slice the points are plotted as longitude against latitude. Datasets without
points are skipped. Called by [`connect_profile!`](@ref) for the state `points`. Requires a
GeophysicalModelGenerator `ProfileData`.

# Arguments
- `state`: the point state of [`point_plot_state`](@ref).
- `profile`: the loaded profile.
"""
function load_point_data!(state, profile)
    foreach(p -> delete!(state.ax, p), state.plots)
    foreach(delete!, state.blocks)
    state.legend[] = place_legend!(state.colorbar, :points, nothing)
    foreach(empty!, (state.blocks, state.plots, state.toggles, state.labels))

    points = profile.PointData
    vertical = is_vertical(profile)
    # vertical profile: x_profile against depth_proj; horizontal slice: longitude against latitude
    coords(point) = vertical ? (point.fields.x_profile, point.fields.depth_proj) :
                               (point.lon.val, point.lat.val)
    names = points === nothing ? Symbol[] : [k for k in keys(points) if !isempty(coords(points[k])[1])]

    for (i, name) in enumerate(names)
        point = points[name]
        x, y = (vec(Float64.(c)) for c in coords(point))

        push!(state.blocks, Label(state.panel[i, 1], String(name); fontsize = 14, halign = :left))
        toggle = Toggle(state.panel[i, 2]; active = true)
        push!(state.blocks, toggle)
        push!(state.toggles, toggle)

        scatter = scatter!(state.ax, x, y; color = POINT_COLORS[mod1(i, length(POINT_COLORS))],
                           strokecolor = :black, strokewidth = 1, markersize = 5,
                           visible = toggle.active)
        translate!(scatter, 0, 0, 12)
        push!(state.plots, scatter)
        push!(state.labels, String(name))
    end

    rowgap!(state.panel, 2)
    fit_panel!(state.panel)   # also handles an empty panel and a collapsed one
    if !isempty(names)
        state.legend[] = place_legend!(state.colorbar, :points) do gp
            Legend(gp, state.plots, state.labels, "Point data"; valign = :top, framevisible = false)
        end
    end
    return nothing
end

