# This is set_main_controls.jl
# It provides the functions to set the controls on:
# - file input/output
# - panel switching (vertical/horizontal picking/ data comparison)

# function to set the buttons for panel switching

function set_panel_buttons!(fig,panel)
    panel[1,1] = buttongrid = GridLayout(tellwidth = false)
    button_picking    = buttongrid[1,1] = Button(fig,label = "Pick")
    button_comparison = buttongrid[1,2] = Button(fig,label = "Compare")
    button_clear = buttongrid[1,3] = Button(fig,label = "Clear")
    return button_picking,button_comparison
end

# the menu contains save picks, save screenshotload data, load picks (to modify and without modifying) and close

function set_fileIO_menu!(fig,panel)
    fileIO_menu_layout        = GridLayout(panel[1,1],tellheight=false,halign= :left) 
    fileIO_menu_box             = Box(fileIO_menu_layout[1, 1], color = :darkorange1,strokecolor = :darkorange1, alignmode= Outside(),cornerradius = 3);
    # somehow add a label
    # menu
    Label(fileIO_menu_layout[1, 1], "Menu", fontsize = 16,halign = :left,width = nothing)
    menu_fileIO = Menu(fileIO_menu_layout[2,1], options = ["Click to choose ... ","Load Profile...", "Load Picks...", "Load Picks (not modifyable)...", "Save All...", "Save Picks...","Save Screenshot...","Close"], fontsize=14, dropdown_arrow_color = (:darkorange1),dropdown_arrow_size = 14, prompt = "Select...")

    rowgap!(fileIO_menu_layout,2) # small vertical space 
    return menu_fileIO
end