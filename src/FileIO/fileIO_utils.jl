# this is fileIO.jl
# it contains all functions that handle the file input and output
using FileIO
using NativeFileDialog
using JLD2

# The GUI opens the native file dialogs through these Refs, so that the tests can
# replace them by functions that return a fixed filename (there is no user on CI)
const PICK_FILE = Ref{Function}(pick_file)
const SAVE_FILE = Ref{Function}(save_file)

# function for fileIO menu response
function menu_fileIO_response(s)
    if s == "Load Profile..."
        @async begin 
            filename = fetch(Threads.@spawn PICK_FILE[](""))
            println(filename)
            #data = load_GMG(filename) # load the profile data, this did not work properly
            data = load(filename,"Profile") 
            # depending on the type of data, initialize the plotting panel
            # populate the dropdown menu
            #dropdown_strings = collect(String.(keys(data.VolData.fields)))
            #menu_plot1.options = ["Choose data to plot",dropdown_strings[1:end-1]]
        end
    elseif s == "Load Picks..."
    elseif s == "Load Picks (not modifyable)..."
    elseif s == "Save All..."
    elseif s ==  "Save Picks..."
    elseif s == "Save Screenshot..."
    elseif s == "Close"
        #GLMakie.closeall() # this needs to be done properly to free up everything
    end
    # what do we need to return?
end
