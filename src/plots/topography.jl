"""
    plot_topography!(ax::Axis, profile, name; key = nothing, fill = true) -> Bool

Plot the topography of a vertical `profile` in `ax`, replacing what was plotted before: an entry
of `profile.TopoData` as a black line over the distance along the profile (`x_profile`), with
a grey fill below the line and a blue fill where it lies below sea level. The profile ends are
marked with "A" and "B". Requires a GeophysicalModelGenerator `ProfileData` of a vertical
cross-section (the topography of a horizontal slice is plotted by [`load_topography_panel!`](@ref)).

# Arguments
- `ax`: the axis to plot in; its title is set to `name` and the start / end coordinates of the
  profile are written in its top left / top right corner.
- `profile`: the loaded profile.
- `name`: title of the axis, usually the file name.

# Keywords
- `key`: entry of `TopoData` to plot (default: the first).
- `fill`: `false` plots only the line.

Returns `false` (and only clears `ax`) if the profile has no topography, `true` otherwise.
"""
function plot_topography!(ax::Axis, profile, name; key = nothing, fill::Bool = true)
    empty!(ax)
    ax.title = name
    (profile.TopoData === nothing || isempty(profile.TopoData)) && return false

    topo = key === nothing ? first(values(profile.TopoData)) : profile.TopoData[key]
    x = Vector{Float64}(topo.fields.x_profile)   # distance along the profile [km]
    y = Vector{Float64}(topo.depth.val)          # topography [km]
    ybase = min(minimum(y), 0.0)

    if fill
        band!(ax, x, Base.fill(ybase, length(x)), Base.fill(0.0, length(x)); color = :skyblue2)   # water
        band!(ax, x, Base.fill(ybase, length(x)), y; color = :grey70)                             # rock
    end
    lines!(ax, x, y; color = :black)

    coords(lonlat) = lonlat === nothing ? "" : string(round.(lonlat; digits = 2))
    # pinned to the axis corners; headroom above the line keeps them clear of the topography
    text!(ax, 0, 1; space = :relative, text = coords(profile.start_lonlat),
          align = (:left, :top), offset = (5, -3))
    text!(ax, 1, 1; space = :relative, text = coords(profile.end_lonlat),
          align = (:right, :top), offset = (-5, -3))
    # A and B mark the start and the end of the profile
    text!(ax, x[1], y[1]; text = "A", font = :bold, fontsize = 18, align = (:left, :bottom),
          offset = (4, 4), strokecolor = :white, strokewidth = 3)
    text!(ax, x[end], y[end]; text = "B", font = :bold, fontsize = 18, align = (:right, :bottom),
          offset = (-4, 4), strokecolor = :white, strokewidth = 3)
    ax.yautolimitmargin = (0.05, 0.35)
    # x fixed to the topography: `autolimits!` would use the data of all x-linked axes, so points
    # of the profile axis outside the profile would stretch both axes; y follows the topography
    ax.limits = (extrema(x), nothing)
    reset_limits!(ax)
    return true
end

