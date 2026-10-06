# every content layout made by `control_panel!`: its expand / collapse toggle (`nothing` if the
# panel is not collapsible) and its empty height
const PANELS = IdDict{GridLayout,Tuple{Union{Toggle,Nothing},Int}}()

"""
    control_panel!(gp, title; color = :steelblue1, empty_height = 20, collapsible = false,
                   expanded = true, width = nothing) -> GridLayout

Create a menu panel at the grid position `gp`: a colored header with `title` and below it an
empty `GridLayout` for the panel's widgets, which is returned. Generic.

# Arguments
- `gp`: grid position, e.g. `fig[1, 1]`.
- `title`: text of the header.

# Keywords
- `color`: color of the header.
- `empty_height`: height of the content while it has no widgets.
- `collapsible`: add an expand / collapse toggle to the header.
- `expanded`: initial state of the toggle (only with `collapsible = true`).
- `width`: fixed width of the panel (default: determined by the content).

An empty layout has no size that Makie can determine, which would make the whole window
layout undeterminable. The content row therefore starts with the fixed height
`empty_height`; call [`fit_panel!`](@ref) once widgets have been added to make it follow
its content.

With `collapsible = true` the header gets a toggle (on: expanded, initially `expanded`) that
shows or hides the widgets of the panel; `width` fixes the panel width, so that the layout
does not move when panels are collapsed. Collapsible panels start expanded unless
`expanded = false` is given; [`exclusive_panels!`](@ref) keeps only one of several panels
expanded.

# Example
```julia
fig = Figure()
content = control_panel!(fig[1, 1], "Options"; collapsible = true)
Button(content[1, 1]; label = "Go")
fit_panel!(content)
```
"""
function control_panel!(gp, title; color = :steelblue1, empty_height = 20,
                        collapsible = false, expanded = true, width = nothing)
    panel = gp[] = GridLayout(halign = :left, valign = :top)
    width === nothing || colsize!(panel, 1, Fixed(width))
    Box(panel[1, 1]; color, strokecolor = color, cornerradius = 3)
    Label(panel[1, 1], title; fontsize = 16, halign = :left, padding = (5, 5, 2, 2))
    content = panel[2, 1] = GridLayout(halign = :left)
    rowgap!(panel, 2)
    rowsize!(panel, 2, Fixed(empty_height))
    PANELS[content] = (nothing, empty_height)
    if collapsible
        toggle = Toggle(panel[1, 1]; active = expanded, halign = :right, width = 34, height = 16,
                        buttoncolor = RGBf(0.95, 0.95, 0.95), framecolor_inactive = RGBf(0.45, 0.6, 0.8),
                        framecolor_active = RGBf(0.1, 0.35, 0.7))
        PANELS[content] = (toggle, empty_height)
        on(_ -> fit_panel!(content), toggle.active)
        fit_panel!(content)
    end
    return content
end

# size (width, height) of the hidden widgets before they were shrunk, see `set_visible!`
const HIDDEN_SIZES = IdDict{Any,Tuple{Any,Any}}()

"""
    set_visible!(layout::GridLayout, visible::Bool)

Show or hide all widgets in `layout`, including those in nested layouts. Hidden widgets still
react to the mouse, and those of a collapsed panel sit on top of the panels below it, so
hidden widgets with a mouse interaction are also shrunk to zero size (and get their size back
when they are shown again). Generic. Returns `nothing`.
"""
function set_visible!(layout::GridLayout, visible::Bool)
    for item in contents(layout)
        item isa GridLayout ? set_visible!(item, visible) :
        if item isa Makie.Block
            item.blockscene.visible[] = visible
            if item isa Union{Button,Slider,IntervalSlider,Toggle,Checkbox,Textbox,Menu}
                if !visible && !haskey(HIDDEN_SIZES, item)
                    HIDDEN_SIZES[item] = (item.width[], item.height[])
                    item.width[] = 0
                    item.height[] = 0
                elseif visible && haskey(HIDDEN_SIZES, item)
                    item.width[], item.height[] = pop!(HIDDEN_SIZES, item)
                end
            end
            # the plots of an axis live in a scene of their own
            item isa Axis && (item.scene.visible[] = visible)
        end
    end
end

"""
    fit_panel!(content::GridLayout) -> Bool

Let the menu panel whose content layout is `content` follow the size of its widgets; call it
after adding widgets. Panels without widgets keep their fixed height, because an empty layout
has no determinable size. A collapsible panel whose toggle is off is collapsed instead: its
widgets are hidden and its content has no height. Widgets added later are hidden as well when
`fit_panel!` is called again. Generic.

# Arguments
- `content`: the content layout of a panel, as returned by [`control_panel!`](@ref). The panel
  is resized through the layout around `content` (the row below the header), so any other
  layout throws an `ArgumentError`. The plot states, [`volume_panel!`](@ref) and
  [`map_panel!`](@ref) call `fit_panel!` on their panel, so their panels have to be made by
  `control_panel!` as well.

Returns `true` if the panel now follows its content, `false` if it is empty or collapsed.

# Example
```julia
fig = Figure()
panel = control_panel!(fig[1, 1], "Options")
Button(panel[1, 1]; label = "Go")
fit_panel!(panel)      # true
```
"""
function fit_panel!(content::GridLayout)
    haskey(PANELS, content) ||
        throw(ArgumentError("fit_panel! needs the content layout of a panel made by `control_panel!` " *
                            "(e.g. `panel = control_panel!(fig[1, 1], \"Title\")`), got another GridLayout"))
    toggle, empty_height = PANELS[content]
    expanded = toggle === nothing || toggle.active[]
    set_visible!(content, expanded)
    if !expanded
        rowsize!(content.parent, 2, Fixed(0))
    elseif isempty(content.content)
        rowsize!(content.parent, 2, Fixed(empty_height))
    else
        rowsize!(content.parent, 2, Auto())
    end
    return expanded && !isempty(content.content)
end

"""
    panel_toggle(content::GridLayout) -> Union{Toggle,Nothing}

The expand / collapse toggle of the collapsible panel whose content layout is `content` (as
returned by [`control_panel!`](@ref) with `collapsible = true`), `nothing` for a panel that is
not collapsible. Generic.
"""
panel_toggle(content::GridLayout) = first(get(PANELS, content, (nothing, 0)))

"""
    exclusive_panels!(contents) -> Vector{Toggle}

Let only one of the collapsible panels with the content layouts `contents` (a tuple or vector
of layouts returned by [`control_panel!`](@ref) with `collapsible = true`) be expanded at a
time: expanding one collapses the others. If several of them are expanded when this is called
([`control_panel!`](@ref) creates expanded panels by default), the first expanded one stays
expanded and the others are collapsed. Returns the toggles of the panels (see
[`panel_toggle`](@ref)), in the order of `contents`. Generic. Throws an `ArgumentError` if one
of the panels is not collapsible.
"""
function exclusive_panels!(contents)
    panel_toggles = [panel_toggle(content) for content in contents]
    any(isnothing, panel_toggles) && throw(ArgumentError("all panels must be collapsible"))
    # start with at most one expanded panel
    first_expanded = findfirst(toggle -> toggle.active[], panel_toggles)
    for (i, toggle) in enumerate(panel_toggles)
        first_expanded !== nothing && i > first_expanded && toggle.active[] && (toggle.active[] = false)
    end
    for toggle in panel_toggles
        on(toggle.active) do expanded
            expanded || return
            for other in panel_toggles
                other !== toggle && other.active[] && (other.active[] = false)
            end
        end
    end
    return panel_toggles
end

