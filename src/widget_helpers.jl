"""
    link_range_controls!(slider, minbox, maxbox, range::Observable, label = nothing)

Connect an `IntervalSlider` with a min and a max `Textbox`: moving the slider sets `range`
to its interval and shows the limits in the text fields (and in `label`, if given); entering a
number in a text field moves the slider to the closest possible value. Generic.

# Arguments
- `slider`: an `IntervalSlider`.
- `minbox`, `maxbox`: `Textbox`es for the lower and upper limit.
- `range`: `Observable` that receives the interval `(lo, hi)`.
- `label`: optional `Label` showing the limits as "Colorbar limits: lo to hi".
"""
function link_range_controls!(slider, minbox, maxbox, range::Observable, label = nothing)
    on(slider.interval) do (lo, hi)
        range[] = (lo, hi)
        label === nothing ||
            (label.text[] = "Colorbar limits: $(round(lo; digits = 2)) to $(round(hi; digits = 2))")
        minbox.displayed_string[] = string(round(lo; digits = 2))
        maxbox.displayed_string[] = string(round(hi; digits = 2))
    end
    for (box, index) in ((minbox, 1), (maxbox, 2))
        on(box.stored_string) do s
            value = tryparse(Float64, something(s, ""))
            value === nothing && return
            lo, hi = slider.interval[]
            index == 1 ? set_close_to!(slider, value, hi) : set_close_to!(slider, lo, value)
        end
    end
end

"""
    parse_levels(text) -> Union{Nothing,Vector{Float64}}

Contour levels from a string of numbers separated by commas, semicolons or spaces, sorted and
without duplicates. `nothing` if `text` is empty or not a list of numbers. Generic.

# Example
```julia
parse_levels("1, 2.5; 0.5 2.5")   # [0.5, 1.0, 2.5]
parse_levels("a b")               # nothing
```
"""
function parse_levels(text)
    (text === nothing || isempty(strip(text))) && return nothing
    parsed = tryparse.(Float64, split(text, r"[,;\s]+"; keepempty = false))
    (isempty(parsed) || any(isnothing, parsed)) && return nothing
    return sort!(unique(Float64[v for v in parsed]))
end

"""
    label_of(option) -> String

The text a dropdown shows for one of its options (a string, or a `(label, value)` tuple).
"""
label_of(option) = option isa Tuple ? string(first(option)) : string(option)

# label of the selected entry of `menu`, `nothing` if nothing is selected
selected_label(menu) = (i = menu.i_selected[]; i < 1 ? nothing : label_of(menu.options[][i]))

"""
    select_label!(menu::Menu, label) -> Bool

Select the entry of the dropdown `menu` whose text is `label` (options are strings or
`(label, value)` tuples), as if the user had chosen it: `menu.selection` changes and its
listeners run. Generic.

# Arguments
- `menu`: a `Menu`.
- `label`: the text of the entry (`nothing` selects nothing).

Returns `true` if the entry was found and selected, `false` otherwise (the selection is then
left alone).

# Example
```julia
fig = Figure()
menu = Menu(fig[1, 1]; options = ["Heatmap", "Contours", "Off"])
select_label!(menu, "Contours")   # true
```
"""
function select_label!(menu, label)
    label === nothing && return false
    i = findfirst(option -> label_of(option) == label, menu.options[])
    i === nothing && return false
    menu.i_selected[] = i
    return true
end

"""
    set_text!(box::Textbox, text::AbstractString)

Set the text of the text field `box` programmatically, as if the user had typed `text` and
pressed enter: the shown text (`displayed_string`) and the stored text (`stored_string`, whose
listeners run) change. An empty `text` clears the field (`stored_string` becomes `nothing`).
Generic. Returns the new stored text.

# Example
```julia
fig = Figure()
levels = Textbox(fig[1, 1]; placeholder = "Contour levels")
set_text!(levels, "-1, 0, 1")
```
"""
function set_text!(box, text)
    box.displayed_string[] = text
    box.stored_string[] = isempty(text) ? nothing : text
end

# move an interval slider to `limits = [lo, hi]` (the closest possible values)
set_limits!(slider, limits) =
    limits isa AbstractVector && length(limits) == 2 && set_close_to!(slider, limits[1], limits[2])

