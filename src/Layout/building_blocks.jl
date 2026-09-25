# this is building_blocks.jl
# It contains generic building blocks that can be used to create GUIs with a consistent look

"""
    titled_panel(pos, title; color = :steelblue1, ncols = 5, fontsize = 16, layout_kwargs...)

Creates a GridLayout at the position `pos` (e.g. `fig[1, 1]`), with a colored title bar
spanning `ncols` columns in its first row. Add the contents of the panel from row 2 onwards,
and call `rowgap!(panel, 2)` afterwards for a compact layout (it only applies to existing rows).
"""
function titled_panel(pos, title; color = :steelblue1, ncols = 5, fontsize = 16, layout_kwargs...)
    panel = GridLayout(pos; tellheight = false, halign = :left, layout_kwargs...)
    Box(panel[1, 1:ncols], color = color, strokecolor = color, cornerradius = 3)
    Label(panel[1, 1:ncols], title, fontsize = fontsize, halign = :left, width = nothing)
    return panel
end

"""
    styled_toggle(pos; active = false)

Toggle with a red frame when inactive and a green frame when active.
"""
function styled_toggle(pos; active = false)
    return Toggle(pos, active = active, buttoncolor = RGBf(0.9, 0.9, 0.9),
        framecolor_inactive = RGBf(0.5, 0.1, 0.1), framecolor_active = RGBf(0.1, 0.5, 0.1))
end

"""
    toggle_list!(panel, names; first_row = 2, active = true)

Adds a label and a toggle for each of `names` to `panel`, one per row starting at `first_row`.
Returns the toggles.
"""
function toggle_list!(panel, names; first_row = 2, active = true)
    toggles = Toggle[]
    for (i, name) in enumerate(names)
        row = first_row + i - 1
        Label(panel[row, 1], String(name), fontsize = 14, halign = :left)
        push!(toggles, Toggle(panel[row, 2], active = active))
    end
    return toggles
end

"""
    visible_if(toggle)

Observable that can be used as the `visible` attribute of a plot, to show it only if `toggle` is active.
"""
visible_if(toggle) = lift(identity, toggle.active)

"""
    add_logo!(pos, filename)

Shows the image `filename` at the position `pos`, without axis decorations.
"""
function add_logo!(pos, filename)
    logo_img  = load(filename)
    logo_axis = Axis(pos, aspect = DataAspect())
    image!(logo_axis, rotr90(logo_img))
    hide_axis!(logo_axis)
    return logo_axis
end

"""
    hide_axis!(ax)

Hides the decorations and all spines of `ax`.
"""
function hide_axis!(ax)
    hidedecorations!(ax)
    hidespines!(ax)
    return ax
end
