"""
    surface_plot_state(ax::Axis, panel::GridLayout, colorbar::GridLayout) -> NamedTuple
    surface_plot_state(axes, panels) -> NamedTuple

State for the surface data: what [`load_surface_data!`](@ref) created for the current profile
(toggles and labels in the surface data panel, lines in the profile axis, the legend). Created
once, before a profile is loaded; it creates nothing itself. Meant for a GeophysicalModelGenerator
`ProfileData`.

# Arguments
- `ax`: the profile axis.
- `panel`: the (empty) layout for the toggles, e.g. the content of a [`control_panel!`](@ref).
- `colorbar`: the colorbar layout (see [`profile_plot_area!`](@ref)); the legend goes right of
  the colorbars (the first legend).
- `axes`, `panels`: as returned by [`picker_layout`](@ref); `axes.profile`,
  `panels.surface_data_panel` and `panels.colorbar` are used.

Returns the state, a `NamedTuple` with the fields `ax`, `panel`, `colorbar`, the plots, the
toggles with their `labels` and the `legend` (`Ref`).
"""
surface_plot_state(ax::Axis, panel::GridLayout, colorbar::GridLayout) =
    (; ax, panel, colorbar, blocks = Any[], plots = Any[], lines = Any[], toggles = Any[],
       labels = String[], legend = Ref{Any}(nothing))
surface_plot_state(axes, panels) =
    surface_plot_state(axes.profile, panels.surface_data_panel, panels.colorbar)

"""
    load_surface_data!(state, profile) -> nothing

Replace the surface data of the previous profile by `profile.SurfData`: for each surface a
label and a toggle in the surface data panel, a white line with a coloured line on top of it in
the profile axis (visible as long as the toggle is on) and an entry in the "Surface data"
legend, the first legend right of the colorbars (greyed out by Makie while the toggle is off).
Surfaces that only contain NaN do not intersect the profile and are skipped, as is a
`Topography` entry, which is plotted separately. On a horizontal slice, `SurfData` entries that
cross the depth of the slice are shown as a contour line at that depth. The panel is empty and
there is no legend if there is no surface data. Called by [`connect_profile!`](@ref) for the
state `surface`. Requires a GeophysicalModelGenerator `ProfileData`.

# Arguments
- `state`: the surface state of [`surface_plot_state`](@ref).
- `profile`: the loaded profile.
"""
function load_surface_data!(state, profile)
    for plot in state.plots
        delete!(state.ax, plot)
    end
    foreach(delete!, state.blocks)
    state.legend[] = place_legend!(state.colorbar, :surface, nothing)
    foreach(empty!, (state.blocks, state.plots, state.lines, state.toggles, state.labels))

    vertical = is_vertical(profile)
    sets = vertical ? [(; name = k, geo = g, level = NaN) for (k, g) in pairs(something(profile.SurfData, (;)))
                       if k != :Topography && !all(isnan, g.depth.val)] :
           [s for s in horizontal_surfaces(profile) if crosses_depth(s.geo, s.level)]
    names = [s.name for s in sets]

    for (i, (name, surface, level)) in enumerate(sets)

        push!(state.blocks, Label(state.panel[i, 1], String(name); fontsize = 14, halign = :left))
        toggle = Toggle(state.panel[i, 2]; active = true)
        push!(state.blocks, toggle)

        color = Makie.wong_colors()[mod1(i, 7)]
        # white line below a thinner coloured one, so it is visible on any heatmap colour
        if vertical
            x = vec(Float64.(surface.fields.x_profile))
            y = vec(Float64.(surface.depth.val))
            halo = lines!(state.ax, x, y; color = :white, linewidth = 4, visible = toggle.active)
            line = lines!(state.ax, x, y; color, linewidth = 2, visible = toggle.active)
        else
            # horizontal slice: the contour line of the surface at the depth of the slice
            x, y, z = grid_data(surface, :depth)
            level = [level]
            halo = contour!(state.ax, x, y, z; levels = level, color = :white, linewidth = 4,
                            visible = toggle.active)
            line = contour!(state.ax, x, y, z; levels = level, color, linewidth = 2,
                            visible = toggle.active)
            # a contour plot has no legend entry of its own: an empty line with the same
            # colour and visibility stands in for it
            legend_line = lines!(state.ax, [NaN], [NaN]; color, linewidth = 2, visible = toggle.active)
            push!(state.plots, legend_line)
        end
        translate!(halo, 0, 0, 10)
        translate!(line, 0, 0, 11)
        push!(state.plots, halo, line)
        push!(state.lines, vertical ? line : legend_line)
        push!(state.toggles, toggle)
        push!(state.labels, String(name))
    end

    rowgap!(state.panel, 2)
    fit_panel!(state.panel)   # also handles an empty panel and a collapsed one
    # Makie greys out the legend entries of lines that are not visible
    isempty(names) || (state.legend[] = place_legend!(state.colorbar, :surface) do gp
        Legend(gp, state.lines, state.labels, "Surface data"; valign = :top, framevisible = false)
    end)
    return nothing
end


# The surfaces that can be shown on a horizontal slice as `(; name, geo, level)`: the entries of
# `SurfData` that do not only contain NaN (topography has its own panel, see
# `load_topography_panel!`). `level` is the depth of the contour line, i.e. of the slice.
function horizontal_surfaces(profile)
    return [(; name = k, geo = g, level = slice_depth(profile))
            for (k, g) in pairs(something(profile.SurfData, (;)))
            if k != :Topography && !all(isnan, g.depth.val)]
end

# whether the depth of the surface `geo` is above and below `depth` somewhere, i.e. whether the
# surface intersects the horizontal slice at `depth`
function crosses_depth(geo, depth)
    values = filter(isfinite, geo.depth.val)
    return !isempty(values) && minimum(values) < depth < maximum(values)
end
