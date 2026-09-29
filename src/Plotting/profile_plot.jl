# this is profile_plot.jl
# It contains the functions that plot a vertical profile:
# topography on top, the profile data (field, surface and point data + picks) below

"""
    ax_topo, ax_profile, colorbar_panel = create_profile_axes!(panel)

Creates two axes: one on top for topography, one directly below for the profile data,
and a panel for the colorbar and legends below them.
"""
function create_profile_axes!(panel)
    ax_topo    = Axis(panel[1, 1])
    ax_profile = Axis(panel[2:3, 1])
    colorbar_panel = panel[4, 1] = GridLayout(height = 100, tellheight = false, tellwidth = false)

    hide_axis!(ax_topo)                # no axes labels and spines for the topo
    linkxaxes!(ax_profile, ax_topo)    # link the axes in the x-direction

    rowgap!(panel, 0)                  # no vertical space between topo and profile plot
    rowsize!(panel, 1, Relative(0.2))  # make the topo plot take up 20% of the vertical space
    return ax_topo, ax_profile, colorbar_panel
end

"""
    plot_topography!(ax, profile, title)

Plots the topography of `profile`, with water in blue and rock in grey. The start and end
points of the profile are shown at the top.
"""
function plot_topography!(ax, profile, title)
    x_topo, y_topo = topography(profile)

    # display the profile limits
    text!(ax, minimum(x_topo), maximum(y_topo); text = string(round.(profile.start_lonlat, digits = 2)), align = (:left, :center), offset = (20, 0))
    text!(ax, maximum(x_topo), maximum(y_topo); text = string(round.(profile.end_lonlat, digits = 2)), align = (:right, :center), offset = (-20, 0))
    ax.title = title # display the profile name in the title

    base = y_topo .* 0 .+ minimum(y_topo)
    band!(ax, x_topo, base, y_topo .* 0, color = :skyblue2) # water level
    lines!(ax, x_topo, y_topo, color = :black)
    band!(ax, x_topo, base, y_topo, color = :grey70)        # fill the topography to base level to denote rock
    return nothing
end

"""
    plot_surfaces!(ax, profile, names, toggles)

Plots the surface data sets `names` as lines, which are only visible if the corresponding toggle is active.
Returns the plots and labels for the legend.
"""
function plot_surfaces!(ax, profile, names, toggles)
    plots  = Vector{Lines{Tuple{Vector{Point{2, Float64}}}}}()
    labels = Vector{String}()
    for (name, toggle) in zip(names, toggles)
        x_surf, y_surf = surface_line(profile, name)
        lines!(ax, x_surf, y_surf, color = :white, linewidth = 3, visible = visible_if(toggle)) # white background line
        push!(plots, lines!(ax, x_surf, y_surf, visible = visible_if(toggle)))
        push!(labels, String(name))
    end
    return plots, labels
end

"""
    plot_points!(ax, profile, names, toggles)

Plots the point data sets `names`, which are only visible if the corresponding toggle is active.
Returns the plots and labels for the legend.
"""
function plot_points!(ax, profile, names, toggles)
    plots  = Vector{Scatter{Tuple{Vector{Point{2, Float64}}}}}()
    labels = Vector{String}()
    for (name, toggle) in zip(names, toggles)
        x_point, y_point = point_coordinates(profile, name)
        push!(plots, scatter!(ax, x_point, y_point, strokecolor = :black, strokewidth = 1, markersize = 5, visible = visible_if(toggle)))
        push!(labels, String(name))
    end
    return plots, labels
end

"""
    plot_profile!(gui, value, field_name, surf_names, surf_toggles, point_names, point_toggles)

Plots the loaded profile of `gui`: topography, the field data `value` (an Observable),
surface and point data, the picks, the colorbar and the legends.
"""
function plot_profile!(gui, value, field_name, surf_names, surf_toggles, point_names, point_toggles)
    profile = gui.profile
    ax_topo, ax, colorbar_panel = create_profile_axes!(gui.panels.plot)
    gui.ax_topo, gui.ax_profile = ax_topo, ax

    plot_topography!(ax_topo, profile, gui.profile_file)
    println("Topography plotted")

    # set the axis limits to the profile limits
    x, y = profile_grid(profile)
    ax.limits = (minimum(x), maximum(x), minimum(y), maximum(y))

    gui.heatmap = heatmap!(ax, x, y, value, colormap = Reverse(:seismic))
    println("Volume data plotted")

    surf_plots, surf_labels = plot_surfaces!(ax, profile, surf_names, surf_toggles)
    println("Surface data plotted")

    point_plots, point_labels = plot_points!(ax, profile, point_names, point_toggles)
    println("Point data plotted")

    # plot the picks
    gui.pick_plot = scatter!(ax, gui.picks, color = :white, markersize = 15, strokewidth = 2, strokecolor = :black)

    # colorbar and legends
    Colorbar(colorbar_panel[1, 1], gui.heatmap, vertical = false, width = 300)
    gui.colorbar_label = Label(colorbar_panel[2, 1], String(field_name))
    Legend(colorbar_panel[1:2, 2:3], surf_plots, surf_labels, "Moho data", valign = :top, framevisible = false, nbanks = 2)
    Legend(colorbar_panel[1:2, 4], point_plots, point_labels, "Seismicity", valign = :top, framevisible = false)
    return nothing
end

"""
    plot_fixed_picks!(gui, pick_data)

Adds picks that cannot be modified (e.g. from another user) as a dotted line to the profile.
They are only visible if the compare toggle is active.
"""
function plot_fixed_picks!(gui, pick_data)
    visible = visible_if(gui.compare_toggle)
    lines!(gui.ax_profile, pick_data.x, pick_data.depth, color = :white, linewidth = 3, visible = visible) # white background line
    lines!(gui.ax_profile, pick_data.x, pick_data.depth, color = :red, linewidth = 2, linestyle = (:dot, :dense), visible = visible)
    return nothing
end
