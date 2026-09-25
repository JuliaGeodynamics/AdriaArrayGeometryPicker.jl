# this is gui_state.jl
# It defines the structure that holds the state of one window of the AdA Picker, so that
# the different parts of the GUI can access it (instead of using global variables)

"""
    PickerGUI

Holds the figure, its panels and controls, the loaded profile, the plots and the picks of
one AdA Picker window. The GUI that was started last can be accessed with `current_gui()`.
"""
Base.@kwdef mutable struct PickerGUI
    fig::Figure
    panels::NamedTuple                  # the main panels of the layout, see create_main_layout

    # controls that exist from the start
    menu::Any           = nothing       # main (file) menu
    pick_toggle::Any    = nothing       # switches picking on and off
    compare_toggle::Any = nothing       # shows/hides the picks loaded for comparison
    user_name::Any      = nothing       # textbox with the name of the user

    # data and plots, available once a profile has been loaded
    profile::Any         = nothing      # ProfileData
    profile_file::String = ""
    ax_topo::Any         = nothing      # axis with the topography
    ax_profile::Any      = nothing      # axis with the profile data and the picks
    heatmap::Any         = nothing      # heatmap of the volume data
    colorbar_label::Any  = nothing

    # picking
    picks::Observable{Vector{Point3f}} = Observable(Point3f[]) # the third dimension is there to ensure that the picks are always on top
    pick_plot::Any    = nothing
    dragging::Bool    = false
    drag_index::Int   = 1
end

const CURRENT_GUI = Ref{Union{Nothing, PickerGUI}}(nothing)

"""
    current_gui()

Returns the `PickerGUI` that was started last (or `nothing`). This is useful for debugging,
e.g. `current_gui().picks[]` gives the current picks.
"""
current_gui() = CURRENT_GUI[]
