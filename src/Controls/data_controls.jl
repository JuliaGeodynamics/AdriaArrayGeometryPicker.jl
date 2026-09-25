# this is data_controls.jl
# It contains the controls for the data of a profile: field data (menu, colormap, color range),
# surface data and point data (toggles to show/hide them)

const COLORMAPS = [:seismic, :roma, :glasgow, :lipari, :vik, :managua, :lajolla, :inferno, :plasma, :magma, :RdBu, :RdYlBu]

"""
    set_field_controls!(pos, field_names, colrange)

Adds the controls for the field data (tomographies etc.): a menu to choose the field, a menu
for the colormap, and a slider and textboxes for the color range, which can be chosen within
`colrange`. Returns a named tuple with the controls.
"""
function set_field_controls!(pos, field_names, colrange)
    panel = titled_panel(pos, "Field data (Tomographies etc.)")

    field_menu = Menu(panel[2, 1:5], options = field_names)

    Label(panel[3, 1], "Colormap", fontsize = 14, halign = :left, width = nothing)
    colormap_menu = Menu(panel[3, 2:5], options = COLORMAPS, fontsize = 12)

    # textboxes to enter min and max of the colorbar manually
    colmin_textbox = Textbox(panel[4, 1], width = 50)
    colmax_textbox = Textbox(panel[4, 5], width = 50)

    # the slider is recreated when the field changes, so it is stored in a Ref
    controls = (panel = panel, field_menu = field_menu, colormap_menu = colormap_menu,
        colmin_textbox = colmin_textbox, colmax_textbox = colmax_textbox,
        slider = Ref{Any}(nothing), slider_label = Ref{Any}(nothing))
    set_colorrange_slider!(controls, colrange)

    rowgap!(panel, 2)
    return controls
end

"""
    set_colorrange_slider!(controls, colrange)

Adds an interval slider (with a label) for the color range to the field controls.
"""
function set_colorrange_slider!(controls, colrange)
    panel  = controls.panel
    slider = IntervalSlider(panel[4, 2:4], linewidth = 20, range = colrange)

    # text for the label of the colorbar
    colrange_text = lift(int -> string(round.(int, digits = 2)), slider.interval)
    label = Label(panel[5, 2:4], colrange_text, fontsize = 14)

    controls.slider[]       = slider
    controls.slider_label[] = label
    return slider
end

# change the color limits of the heatmap if the slider changes, this is directly reflected in the colorbar
connect_colorrange_slider!(slider, hm) = on(int -> hm.colorrange = int, slider.interval)

# sets one end of the color range slider to `val`, keeping the end with index `other_index`
function set_colorrange_limit!(slider, val, other_index)
    other  = slider.interval[][other_index]
    tmpmin = max(min(val, other), minimum(slider.range[]))
    tmpmax = min(max(val, other), maximum(slider.range[]))
    set_close_to!(slider, tmpmin, tmpmax)
    return nothing
end

"""
    connect_field_controls!(gui, controls, value, colrange)

Defines what happens if the field, the colormap or the color range are changed.
`value` is the Observable with the data of the heatmap.
"""
function connect_field_controls!(gui, controls, value, colrange)
    hm = gui.heatmap
    connect_colorrange_slider!(controls.slider[], hm)

    # change values in textboxes to set the colorbar limits manually
    on(s -> set_colorrange_limit!(controls.slider[], parse(Float64, s), 2), controls.colmin_textbox.stored_string)
    on(s -> set_colorrange_limit!(controls.slider[], parse(Float64, s), 1), controls.colmax_textbox.stored_string)

    # field data selection
    on(controls.field_menu.selection) do s
        # delete the interval slider and its label, and create them again after the data is updated.
        # This is necessary, as there are sometimes issues with the interval if the heatmap values change drastically
        delete!(controls.slider[])
        delete!(controls.slider_label[])

        # update the heatmap value -> this also updates colrange
        value[] = volume_slice(gui.profile, s)

        connect_colorrange_slider!(set_colorrange_slider!(controls, colrange), hm)

        # adapt colorbar label
        gui.colorbar_label.text = String(s)

        println("Field data changed to: ", s)
    end

    # change colormap in colormap menu
    on(controls.colormap_menu.selection) do s
        hm.colormap = Reverse(s) # colormap of the colorbar is automatically updated
    end
    return nothing
end

"""
    set_toggle_panel!(pos, title, names)

Panel with a title and a toggle for each of the data sets `names`. Returns the toggles.
"""
function set_toggle_panel!(pos, title, names)
    panel   = titled_panel(pos, title; tellwidth = false)
    toggles = toggle_list!(panel, names)
    rowgap!(panel, 2)
    return toggles
end
