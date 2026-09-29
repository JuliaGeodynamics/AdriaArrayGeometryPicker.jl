# This is the main function of the Adria Array Visualization and Picking tool.
# This tool is meant to work with the GeophysicalModelGenerator to help interpreting geophysical datasets.
# It puts together the building blocks defined in the other files.
# IMPORTANT: FOR NOW, ONLY VERTICAL PROFILES WORK

const LOGO_FILE = joinpath(@__DIR__, "..", "assets", "AdA_Picker_logo_tr.png")

"""
    start_AdA_Picker(; data = nothing)

Start the AdA Picker GUI. No input arguments are required. Optionally, a profile can be
given as `data` (a `ProfileData` structure or the name of a jld2 file containing a
`Profile`), which is then loaded directly.

Returns the figure. The state of the GUI can be accessed with `AdriaArrayGeometryPicker.current_gui()`.
"""
function start_AdA_Picker(; data = nothing)
    fig, panels = create_main_layout()
    gui = PickerGUI(fig = fig, panels = panels)
    CURRENT_GUI[] = gui

    gui.pick_toggle, gui.user_name, gui.compare_toggle = set_picking_controls!(panels.pick_controls)
    add_logo!(panels.logo[1, 1], LOGO_FILE)

    gui.menu = set_fileIO_menu!(fig, panels.main_menu) # see layout_main_controls.jl
    on(s -> handle_menu_selection!(gui, s), gui.menu.selection) # see fileIO_utils.jl

    connect_picking!(gui) # see picking_interaction.jl

    isnothing(data) || load_profile!(gui, data)

    display(fig)
    return fig
end
