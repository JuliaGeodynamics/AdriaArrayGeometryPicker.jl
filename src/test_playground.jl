
using GLMakie

# function to clear a GridLayout unit (I call it panel) by recursively deleting all its children
function clear_panel!(panel::GridLayout)
    for child in panel.children
        if child isa GridLayout
            clear_panel!(child)
        end
        delete!(panel, child)
    end
    return nothing
end

function CreateFigure()
# create figure
fig = Figure(backgroundcolor = RGBf(0.98, 0.98, 0.98),size = (1000, 600))
# create panels
panel_clear    = fig[1,1] = GridLayout(tellheight = false)
panel_main_menu     = fig[2,1] = GridLayout(tellheight = false)
panel_plots         = fig[2,2:3] = GridLayout(tellheight = false)

# create subpanels in main menu
panel1 = panel_main_menu[1,1] = GridLayout(tellheight = false)  # for logo
panel2 = panel_main_menu[2,1] = GridLayout(tellheight = false)  # for toggles

# add text to panel1
 Label(panel1[1, 1], "Field data (Tomographies etc.)", fontsize = 16,halign = :left,width = nothing)
# add toggles to panel2
 toggle1 = Toggle(panel2[1,1],active=false,buttoncolor = RGBf(0.9, 0.9, 0.9), framecolor_inactive = RGBf(0.5, 0.1, 0.1), framecolor_active = RGBf(0.1, 0.5, 0.1))
 toggle2 = Toggle(panel2[1,2],active=false,buttoncolor = RGBf(0.9, 0.9, 0.9), framecolor_inactive = RGBf(0.5, 0.1, 0.1), framecolor_active = RGBf(0.1, 0.5, 0.1))

# add a button to clear panel_plots
 btn_clear = Button(panel_clear[1,1], label = "Clear Plots", width = 100)
 #on(btn_clear.clicks) do _
 #   clear_panel!(panel_plots)
 #end

 # add a button to clear panel_main_menu
 btn_clear_main = Button(panel_clear[1,2], label = "Clear Main Menu", width = 150)
 #on(btn_clear_main.clicks) do _
 #   clear_panel!(panel_main_menu)
 #end

# create a line plot and a heatmap in panel_plots
ax1 = Axis(panel_plots[1,1],title = "Line Plot Example")
l = lines!(ax1, 1:10, rand(10), color = :blue)
ax2 = Axis(panel_plots[2,1],title = "Heatmap Example")
hm = heatmap!(ax2, rand(10,10), colormap = :viridis)

return fig,ax1,ax2,hm,l
end




