module AdriaArrayGeometryPicker

# load required packages
using GLMakie
using GeophysicalModelGenerator
using DelimitedFiles
using Dates
using FileIO
using NativeFileDialog
using JLD2
using Interpolations

# export the function that starts the tool
export start_AdA_Picker # this is the function that starts the GUI, it is defined in AdA_Picker.jl

# The code is split into:
# - functions without any graphics, that extract data from profiles and handle picks
include("Data/profile_data.jl")        # get the data to plot from a GMG ProfileData structure
include("Picks/picks_io.jl")           # convert, save and load picks
# - generic building blocks for GUIs (styled panels, toggle lists, logo, ...)
include("Layout/building_blocks.jl")
# - the parts of this specific GUI
include("GUI/gui_state.jl")            # struct that holds the state of one GUI window
include("Layout/main_layout.jl")       # main layout of the window
include("Controls/layout_main_controls.jl") # main menu and picking controls
include("Controls/data_controls.jl")   # controls for field, surface and point data
include("Plotting/profile_plot.jl")    # plots a vertical profile
include("Picks/picking_interaction.jl") # adding, deleting and dragging picks with the mouse
include("FileIO/fileIO_utils.jl")      # file dialogs and the actions of the main menu
include("AdA_Picker.jl")               # start_AdA_Picker, which puts everything together

end
