# the is the first version of the Adria Array Visualizuation and Pickking tool 
# this tool is meant to work with the GeophysicalModelGenerator to help interpreting geophysical datasets

# For development reasons, all functionality is contained within this single file 
# IMPORTANT: FOR NOW, ONLY VERTICAL PROFILES WORK


# add files for specific tasks
include("utils.jl") # this file contains some utility functions
include("FileIO/fileIO_utils.jl") # this file contains the functions to load and save data
include("Controls/layout_main_controls.jl") # this file contains the layour for the main controls

###############################################################
# main function to start the tool

"""
    start_AdA_Picker()

Start the AdA Picker GUI. No input arguments are required. 

"""



function start_AdA_Picker(;data=nothing)

    # initialization of some plot handles so that we can check things have been plotted yet
    h1 = nothing
    # initialization of picking-related variables
    global dragging, idx, picks,ax1,p1

    # initialize the picks observable
    picks = Observable(Point3f[]) # --> this has to be done at the initialization, the third dimension is there to ensure that the scatter plot is always on top

    # arguments for picking, should go somewhere else
    dragging = false
    idx = 1

    # create a figure
    fig = Figure(backgroundcolor = RGBf(0.98, 0.98, 0.98),
    size = (1000, 600))

    # create the main layout for the GUI - this is the basic structure
    # changes only occur in the plotting panel
    panel_main_menu     = fig[1,1] = GridLayout() # menu panel
    panel_pick_controls = fig[1,2] = GridLayout() # main control panel
    panel_pick_legend   = fig[1,3] = GridLayout() # main control panel
    panel_logo          = fig[1,4] = GridLayout(width=250) # logo panel
    panel_plot_controls = fig[2,1] = GridLayout() # plot cotrol panel
    panel_plot          = fig[2,2:4] = GridLayout() # main plotting window

    colsize!(fig.layout,1,Fixed(300)) # set a fixed column size
    rowsize!(fig.layout,1,Fixed(80)) # set a fixed row size
    ### PICKING CONTROLS ###
    panel_pick_main = panel_pick_controls[1,1:4] = GridLayout(tellheight = false, halign = :left)
    panel_pick_compare = panel_pick_controls[2,1:4] = GridLayout(tellheight = false, halign = :left)

    pick_label = Label(panel_pick_main[1,1],"Picking",tellwidth=false)
    pick_toggle = Toggle(panel_pick_main[1,2],active=false,buttoncolor = RGBf(0.9, 0.9, 0.9), framecolor_inactive = RGBf(0.5, 0.1, 0.1), framecolor_active = RGBf(0.1, 0.5, 0.1))
    pick_name  = Textbox(panel_pick_main[1,3],width=100,placeholder = "User name")

    compare_label = Label(panel_pick_compare[1,1],"Compare Picks",tellwidth=false)
    compare_toggle = Toggle(panel_pick_compare[1,2],active=false,buttoncolor = RGBf(0.9, 0.9, 0.9), framecolor_inactive = RGBf(0.5, 0.1, 0.1), framecolor_active = RGBf(0.1, 0.5, 0.1))

    ### LOGO ###
    insert_logo!(panel_logo[1,1])
    # logo_img = load("./assets/AdA_Picker_logo_tr.png") # load the logo
    # logo_axis = Axis(panel_logo[1,1], aspect = DataAspect())
    # image!(logo_axis, rotr90(logo_img))
    # hidedecorations!(logo_axis) # no axes labels for the logo
    # logo_axis.leftspinevisible  = false # no left spine for the topo
    # logo_axis.rightspinevisible = false # no right spine for the topo
    # logo_axis.bottomspinevisible = false # no bottom spine for the topo
    # logo_axis.topspinevisible   = false # no top spine for the topo

    ### MAIN MENU ###
    plot_vertical = nothing # this will be used to store the vertical profile plot
    # create the menu layout
    menu_fileIO = set_fileIO_menu!(fig,panel_main_menu) # see layout_main_controls.jl for details
    # set the menu response ( should be defined in fileIO.jl, but there are issues with that)
    on(menu_fileIO.selection) do s
        if s == "Load Profile..."
            ############################################################
            # LOAD PROFILE DATA
            @async begin 
                fn = fetch(Threads.@spawn pick_file(""))

                data = load(fn,"Profile") # we need to make this more foolproof, I don't think we can rely on people calling hteir profile structure Profile
                println(fn*" loaded")
            
                ### Volume Data ###
                field_names = (collect(keys(data.VolData.fields)))
                    println("Volume data extracted")
                ### Surface Data ###
                surf_names  = (collect(keys(data.SurfData)))
                # remove the topography from the surface data names, we will plot it separately
                surf_names = filter(name -> name != :Topography, surf_names)
                # remove all datasets that only contain NaN values, this means that tihs surface does not intersect with the profile
                surf_names = filter(name -> !all(isnan, data.SurfData[name].depth.val), surf_names)
                    println("Surface data extracted")
                ### Point Data ###
                point_names = (collect(keys(data.PointData)))
                # remove all datasets that do not contain any data points
                point_names = filter(name -> !isempty(data.PointData[name].fields), point_names)
                    println("Point data extracted")
                # get the topography data
                x_topo = data.SurfData.Topography.fields.x_profile; # is in km!!!
                y_topo = Vector(ustrip(data.SurfData.Topography.fields.Topography)) # is also in km! thank Unitful for the mess

                # take the first field to get the field data
                x = data.VolData.fields.x_profile[:,:,1]
                x = x[:,1] # create a vector, we assume that we are dealing with a regular grid
                y = data.VolData.depth.val[:,:,1]
                y = y[1,:]; # create a vector, we assume that we are dealing with a regular grid

                value = ustrip.(data.VolData.fields[field_names[1]])
                value = Observable(value[:,:,1]) # convert to a 2D matrix for plotting, this is an Observable

                # min and max are also observables that depend on the value observable
                minval = @lift(minimum($value[.!(isnan.($value))]))
                maxval = @lift(maximum($value[.!(isnan.($value))]))

                # non-allocating version, to be tested
                #minval = minimum(x->isnan(x) ? Inf : x,tmp)
                #maxval = maximum(x->isnan(x) ? -Inf : x,tmp)

                # create a range from these values, which is also an observable (to be used with the interval slider)
                colrange = @lift(LinRange($minval,$maxval,1000))
                    
                println("Data extracted for vertical profile plotting")
                
                ############################################################
                # SET THE CONTROL PANEL
                
                # VOLUME DATA CONTROLS
                field_data_panel = panel_plot_controls[1, 1] = GridLayout(tellheight = false, halign = :left)
                field_data_box   = Box(field_data_panel[1, 1:5], color = :steelblue1,strokecolor = :steelblue1, cornerradius = 3);
                    Label(field_data_panel[1, 1:5], "Field data (Tomographies etc.)", fontsize = 16,halign = :left,width = nothing)
                
                menu_field_data = Menu(field_data_panel[2,1:5])
                menu_field_data.options = field_names[1:end-2] # the last one is empty, so we remove it

                Label(field_data_panel[3, 1], "Colormap", fontsize = 14,halign = :left,width=nothing)
                menu_field_colormap  = Menu(field_data_panel[3,2:5], options = [:seismic,:roma,:glasgow,:lipari,:vik,:managua,:lajolla,:inferno,:plasma,:magma,:RdBu,:RdYlBu], fontsize = 12)
                
                #Label(field_data_panel[4, 1], "Clim", fontsize = 12,halign = :left,width=nothing)
                colorrange_slider = IntervalSlider(field_data_panel[4,2:4],linewidth = 20,range = colrange) 
                
                # text for the label of the colorbar
                colrange_text = lift(colorrange_slider.interval) do int
                    string(round.(int,digits = 2))
                end

                # add the colorbar label
                col_label = Label(field_data_panel[5,2:4],colrange_text,fontsize = 14, )

                # add textboxes to enter min and max of the colorbar manually
                colmin_textbox = Textbox(field_data_panel[4,1],width=50)
                colmax_textbox = Textbox(field_data_panel[4,5],width=50)
                
                rowgap!(field_data_panel,2)

                # SURFACE DATA CONTROLS
                surf_data_panel = panel_plot_controls[2, 1] = GridLayout(tellheight = false, halign = :left,tellwidth = false)
                surf_data_box   = Box(surf_data_panel[1, 1:5], color = :steelblue1,strokecolor = :steelblue1, cornerradius = 3);
                Label(surf_data_panel[1, :], "Surface data (Moho etc.)", fontsize = 16,halign = :left,width = nothing)

                # create a vector to store the toggles for the surface controls 
                surf_toggles = []
                for isurf in 1:length(surf_names)
                    # create a label for the surface data
                    Label(surf_data_panel[isurf+1, 1], String(surf_names[isurf]), fontsize = 14, halign = :left)
                    # create a toggle for the surface data
                    ts = Toggle(surf_data_panel[isurf+1, 2], active = true)
                    push!(surf_toggles,ts)
                end
                rowgap!(surf_data_panel,2)

                # POINT DATA CONTROLS
                point_data_panel = panel_plot_controls[3, 1] = GridLayout(tellheight = false, halign = :left,tellwidth = false)
                point_data_box   = Box(point_data_panel[1,1:5], color = :steelblue1,strokecolor = :steelblue1, cornerradius = 3,tellheight = false);
                Label(point_data_panel[1, 1], "Point data (Seismicity etc.)", fontsize = 16,halign = :left,width = nothing)

                ipoint = 1
                # create a vector to store the toggles for the surface controls 
                point_toggles = []
                for ipoint in 1:length(point_names)
                    # create a label for the point data
                    Label(point_data_panel[1+ipoint, 1], String(point_names[ipoint]), fontsize = 14, halign = :left)
                    # create a toggle for the point data
                    toggle = Toggle(point_data_panel[1+ipoint, 2], active = true)
                    push!(point_toggles,toggle)
                end 
                rowgap!(point_data_panel,2)

                # SCREENSHOT DATA CONTROLS
                screenshot_panel = panel_plot_controls[4, 1] = GridLayout(tellheight = false, halign = :left)
                screenshot_box   = Box(screenshot_panel[1, 1], color = :white, cornerradius = 3);
                
                println("Data controls initialized")
                ############################################################
                
                ############################################################
                # SET THE PLOTTING WINDOW
                # if we have loaded a vertical profile, we now create two axes: 
                # one on top for topography, one directly below for the tomography
                topo_ax1 = Axis(panel_plot[1,1])
                ax1      = Axis(panel_plot[2:3,1]) # , aspect=DataAspect()
                colorbar_panel = panel_plot[4,1] = GridLayout(height=100,tellheight = false,tellwidth=false)

                hidedecorations!(topo_ax1) # no axes labels for the topo
                topo_ax1.leftspinevisible  = false # no left spine for the topo
                topo_ax1.rightspinevisible = false # no right spine for the topo
                topo_ax1.bottomspinevisible = false # no bottom spine for the topo
                topo_ax1.topspinevisible   = false # no top spine for the topo
                linkxaxes!(ax1, topo_ax1)  # link the axes in the x-direction

                # display the profile limits
                text!(topo_ax1,minimum(x_topo),maximum(y_topo);text = string(data.start_lonlat),align = (:left, :center),offset = (20, 0))
                text!(topo_ax1,maximum(x_topo),maximum(y_topo);text = string(data.end_lonlat), align = (:right, :center),offset = (-20, 0))

                # plot layout
                rowgap!(panel_plot,0) # no vertical space between topo and profile plot
                rowsize!(panel_plot, 1, Relative(0.2)) # make the topo plot take up 20% of the vertical space

                # set the ax1 limits to the profile limits
                ax1.limits = (minimum(x), maximum(x), minimum(y), maximum(y))

                ################## PLOT CONTROLS #####################

                ###################### PLOTTING ######################
                # plot topo in the topo axis
                band!(topo_ax1,x_topo,y_topo.*0 .+ minimum(y_topo) ,y_topo.*0,color = :skyblue2) # water level
                topo1 = lines!(topo_ax1,x_topo,y_topo,color = :black)
                band!(topo_ax1,x_topo,y_topo.*0 .+ minimum(y_topo) ,y_topo,color = :grey70) # fill the topography to base level to denote rock
            
                println("Topography plotted")

                # plot the heatmap
                h1 = heatmap!(ax1,x,y,value,colormap = Reverse(:seismic))

                println("Volume data plotted")

                # plot all surface data
                surf_plot = Vector{Lines{Tuple{Vector{Point{2, Float64}}}}}()
                surflabel_plot = Vector{String}()

                for isurf in 1:length(surf_names)
                    surf_data = data.SurfData[surf_names[isurf]]
                    x_surf = surf_data.fields.x_profile
                    y_surf = surf_data.depth.val
                    lines!(ax1, x_surf,y_surf, color = :white,linewidth = 3,visible = @lift($(surf_toggles[isurf].active) ? true : false))
                    sp = lines!(ax1, x_surf,y_surf, visible = @lift($(surf_toggles[isurf].active) ? true : false))
                    push!(surf_plot,sp)
                    push!(surflabel_plot,String(surf_names[isurf]))
                end

                println("Surface data plotted")

                # plot all point data
                point_plot = Vector{Scatter{Tuple{Vector{Point{2, Float64}}}}}()
                pointlabel_plot = Vector{String}()
                for ipoint in 1:length(point_names)
                    # get the coordinates of the points
                    point_data = data.PointData[point_names[ipoint]]
                    x_point = point_data.fields.x_profile
                    y_point = point_data.fields.depth_proj
                    p = scatter!(ax1,x_point,y_point,strokecolor = :black, strokewidth = 1,markersize = 5, visible = @lift($(point_toggles[ipoint].active) ? true : false))

                    push!(point_plot,p)
                    push!(pointlabel_plot,String(point_names[ipoint]))

                    ipoint += 1
                end

                println("Point data plotted")
                
                # plot the picks 
                p1 = scatter!(ax1,picks,color = :white,markersize = 15,strokewidth = 2,strokecolor = :black)
                
                ######################### COLORBAR AND LEGENDS #########################
                cbar         = Colorbar(colorbar_panel[1,1], h1, vertical = false,width = 300)
                clabel       = Label(colorbar_panel[2,1], String(field_names[1])) # split(field_names[1],"_",limit=3)
                legend_surf  = Legend(colorbar_panel[1:2,2:3],surf_plot,surflabel_plot,"Moho data",valign = :top,framevisible = false,nbanks = 2)
                legend_point = Legend(colorbar_panel[1:2,4],point_plot,pointlabel_plot,"Seismicity",valign = :top,framevisible = false)

                ########################## CALLBACKS ##########################

                ### FOR COLORBAR
                # Change values in textboxes to set the colorbar limits manually
                on(colmin_textbox.stored_string) do valmin
                    tmpmin = maximum((minimum((parse(Float64,valmin),colorrange_slider.interval[][2])),minimum(colorrange_slider.range[])))
                    tmpmax = minimum((maximum((parse(Float64,valmin),colorrange_slider.interval[][2])),maximum(colorrange_slider.range[])))
                    set_close_to!(colorrange_slider,tmpmin,tmpmax)
                end
                on(colmax_textbox.stored_string) do valmin
                    tmpmin = maximum((minimum((parse(Float64,valmin),colorrange_slider.interval[][1])),minimum(colorrange_slider.range[])))
                    tmpmax = minimum((maximum((parse(Float64,valmin),colorrange_slider.interval[][1])),maximum(colorrange_slider.range[])))
                    set_close_to!(colorrange_slider,tmpmin,tmpmax)
                end

                # change the color limits in the slider
                on(colorrange_slider.interval) do int
                    # change the color limits of the heatmap, this should be directly reflected in the colorbar
                    h1.colorrange = int
                end

                    ### FIELD DATA SELECTION
                on(menu_field_data.selection) do s

                    # update heatmap values
                    tmp     = data.VolData.fields[Symbol(s)]
                    tmp = ustrip.(tmp) # remove units (if applicable)
                    tmp = ustrip.(tmp[:,:,1]) # only take 2D data, strip again just to make sure
                        # delete the interval slider, insert it again and add all the callbacks
                        # this is necessary, as there are sometimes issues with the interval if the heatmap values change drastically
                        
                        # delete slider and label
                        delete!(colorrange_slider)
                        delete!(col_label)

                        # update the heatmap value -> this should also update colrange through minval and maxval
                        value[] = tmp 

                        # create new slider 
                        colorrange_slider = IntervalSlider(field_data_panel[4,2:4],linewidth = 20,range = colrange) 
                        
                        ### recreate the label
                        # text for the label of the colorbar
                        colrange_text = lift(colorrange_slider.interval) do int
                            string(round.(int,digits = 2))
                        end
                        col_label = Label(field_data_panel[5,2:4],colrange_text,fontsize = 14)

                        # define what happens if the slider values are changed
                        on(colorrange_slider.interval) do int
                            # change the color limits of the heatmap, this should be directly reflected in the colorbar
                            h1.colorrange = int
                        end

                    # adapt colorbar label
                    clabel.text = String(s)


                    println("Field data changed to: ",s)
                end

                # change colormap in colormap menu
                on(menu_field_colormap.selection) do s
                    # change the colormap of the heatmap
                    h1.colormap = Reverse(s) # colormap of the colorbar is automatically updated
                end        
            end
        elseif s == "Load Picks..."
            # load picks from a text file, these will be modifyable
            @async begin 
                fn = fetch(Threads.@spawn pick_file(""))
                println(fn)

                
                # see if we are dealing with a jld2 or txt file (given as csv) -> distinguish via the extension
                filetype = split(fn,".")[end] # this gives us everything after the last dot in the filename
                if filetype == "jld2"
                    println(fn*" loading")
                    data_picks = load(fn) 
                    println(fn*" loaded")
                
                    # the available fields of the pick data are:
                    # picks: Nx2 array with x and y coordinates of the picks
                    # profile_info: start and end lonlat of the profile
                    # user_name: name of the user who created the picks
                    # date: date of creation
                
                    # check if the start and end point match
                    if  data_picks["profile_info"].start_lonlat == data.start_lonlat && data_picks["profile_info"].end_lonlat == data.end_lonlat
                        println("The loaded picks belong to the current profile. Loading picks...")
                        # assign the loaded pick data to the picks observable
                        pickarray = data_picks["picks"]
                        # convert to Point3f vector
                        pickpoints = Point3f[]
                        for ipick in 1:size(pickarray,1)
                            push!(pickpoints,Point3f(pickarray[ipick,1],pickarray[ipick,2],1000)) # z-value is set to 1000 to ensure that picks are always on top
                        end
                        picks[] = pickpoints
                        notify(picks)
                        println("Picks loaded: ",length(picks[]))
                    else
                        println("Warning: The loaded picks do not belong to the current profile. Picks not loaded.")
                    end
                    
                elseif filetype == "csv"
                        # Not implemented yet
                elseif filetype == ""
                        # not implemented yet
                else
                    println("This is not a valid pick file at the moment. Feel free to add this functionality :)")
                end

            end
        elseif s == "Load Picks (not modifyable)..."
            # load the picks as point data, these will be treated in a similar way as e.g. the seismicity data
            @async begin 
                fn = fetch(Threads.@spawn pick_file(""))
                println(fn)

                # test plot in ax1
                #lines!(ax1, [0,100],[0,-200], color = :red,linewidth = 3)

                # see if we are dealing with a jld2 or txt file (given as csv) -> distinguish via the extension
                filetype = split(fn,".")[end] # this gives us everything after the last dot in the filename
                if filetype == "jld2"
                    data_picks = load(fn) 
                    println(fn*" loaded")

                    if  data_picks["profile_info"].start_lonlat == data.start_lonlat && data_picks["profile_info"].end_lonlat == data.end_lonlat
                        println("The loaded picks belong to the current profile. Loading picks...")
                        # assign the loaded pick data to the picks observable
                        pickarray = data_picks["picks"]
                        x_pick = pickarray[:,1]
                        y_pick = pickarray[:,2]
                        println("Picks loaded")                        

                        # add these picks as a dashed line
                        #lines!(ax1, x_pick,y_pick, color = :white,linewidth = 3,visible = @lift($(surf_toggles[isurf].active) ? true : false)) # white background line
                        pp = lines!(ax1, x_pick,y_pick,color=:black,linewidth=3,linestyle=:dash,visible = @lift($(compare_toggle.active) ? true : false)) # black main line
                        #push!(comppick_plot,pp)
                        #push!(comppick_label,data_picks["user_name"])
                        
                        println("Picks plotted")

                    else
                        println("Warning: The loaded picks do not belong to the current profile. Picks not loaded.")
                    end

                    # now create the pick data
                elseif filetype == "csv"
                    println("This is not a valid pick file at the moment. Feel free to add this functionality :)")
                    #csvread()
                else
                    println("This is not a valid pick file at the moment. Feel free to add this functionality :)")
                end

            end


        elseif s == "Save All..."
            # save a jld2 file with all data attached -- similar to a state file in paraview?
            # this still has to be implemented 
        elseif s ==  "Save Picks..."
            # save a file with the picked data
            # picks can be stored as either jld2 file or csv file,depending on the chosen file extension
            # if no file extension is chosen, the default is a jld2 file
            println("saving picks")

            # create an array for the picks
            pickarray = zeros(length(picks[]),2)
            for ipick in 1:length(picks[])
                pickarray[ipick,1] = picks[][ipick][1]
                pickarray[ipick,2] = picks[][ipick][2]
            end
            println("reorganized picks")
            
            @async begin 
                fn_save = fetch(Threads.@spawn save_file("")) # open native file dialog and choose a filename
                filetype = split(fn_save,".")[end] # get the ending
                # save depending on file ending
                if filetype == "jld2"
                    # file should contain: profile information, picker information, picks
                    profile_info = (start_lonlat = data.start_lonlat,end_lonlat = data.end_lonlat)
                    jldsave(fn_save; picks=pickarray, profile_info=profile_info, user_name=pick_name.stored_string[], date=now())
                    println(fn_save*" saved")
                elseif filetype == "csv"    
                    println("Saving as csv is not implemented yet")
                else
                    println("This is not a valid pick file format. Picks are saved as jld2 file.")
                end 
            end
            # get the file ending

            #pickarray = zeros(length(picks[]),3)

        elseif s == "Save Screenshot..."
            # save a screen shot of the makie window
            @async begin 
                fn_screen = fetch(Threads.@spawn save_file(""))
                save(fn_screen, fig, px_per_unit = 2)
                println(fn_screen*" saved")
            end
        elseif s == "Close"
        GLMakie.closeall() # close the window
        end
    end
    notify(menu_fileIO.selection)
    
    ##### PICKING #####
    # adding, deleting, dragging
    on(events(fig).mousebutton, priority = 2) do event
        if pick_toggle.active[]
            if event.button == Mouse.left
                if event.action == Mouse.press
                    plt, i = pick(fig)
                    if Keyboard.d in events(fig).keyboardstate 
                        # Delete marker
                        deleteat!(picks[], i)
                        notify(picks)
                        println("   deleted pick")
                        return Consume(true)
                    elseif Keyboard.a in events(fig).keyboardstate
                        # Add marker
                        #if is_mouseinside(ax1)
                            push!(picks[], [mouseposition(ax1);1000])
                            println([mouseposition(ax1);1000])
                        #end
                        notify(picks)
                        println("   added pick")
                        return Consume(true)
                    else
                        # Initiate drag --> this is not working yet
                        dragging = plt == p1 # What is happening here?
                        idx = i
                        return Consume(dragging)
                    end
                elseif event.action == Mouse.release
                    # Exit drag
                    dragging = false
                    return Consume(false)
                end
            end
            return Consume(false)
        end
    end

    on(events(fig).mouseposition, priority = 2) do mp
        if pick_toggle.active[]
            if dragging
                #if is_mouseinside(ax1)
                    picks[][idx] = [mouseposition(ax1);1000]
                #end
                
                notify(picks)
                return Consume(true)
            end
            return Consume(false)
        end
    end    
    ##########################################
    display(fig)
    return fig
end
###############################################################



