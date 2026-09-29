# this is main_layout.jl
# It creates the figure and the basic structure of the GUI.
# Changes only occur in the plotting panel (and the plot controls).

"""
    fig, panels = create_main_layout(; size = (1000, 600))

Creates the figure and its main panels:

    | main_menu     | pick_controls | pick_legend | logo |
    | plot_controls | plot                               |
"""
function create_main_layout(; size = (1000, 600))
    fig = Figure(backgroundcolor = RGBf(0.98, 0.98, 0.98), size = size)

    panels = (
        main_menu     = fig[1, 1]   = GridLayout(),           # menu panel
        pick_controls = fig[1, 2]   = GridLayout(),           # picking controls
        pick_legend   = fig[1, 3]   = GridLayout(),           # legend of the picks
        logo          = fig[1, 4]   = GridLayout(width = 250), # logo panel
        plot_controls = fig[2, 1]   = GridLayout(),           # plot control panel
        plot          = fig[2, 2:4] = GridLayout(),           # main plotting window
    )

    colsize!(fig.layout, 1, Fixed(300)) # set a fixed column size
    rowsize!(fig.layout, 1, Fixed(80))  # set a fixed row size

    return fig, panels
end
