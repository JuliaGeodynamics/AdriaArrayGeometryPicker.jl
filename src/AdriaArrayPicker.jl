module AdriaArrayPicker

# load required packages
using GLMakie
using GeophysicalModelGenerator
using DelimitedFiles
using Dates

# export the function that starts the tool
export start_AdA_Picker # this is the function that starts the GUI, it is defined in AdA_VizPickTool_V1.jl

# now include the main function that starts the GUI
include("AdA_VizPickTool_V1.jl")

end
