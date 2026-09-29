# this is picking_interaction.jl
# It defines how picks are added, deleted and dragged with the mouse, if picking is active:
#   a + left click: add a pick
#   d + left click: delete the pick under the mouse
#   left click + drag: move a pick (not working yet)

"""
    connect_picking!(gui)

Registers the mouse callbacks for picking in the figure of `gui`.
"""
function connect_picking!(gui)
    fig = gui.fig

    on(events(fig).mousebutton, priority = 2) do event
        (gui.pick_toggle.active[] && !isnothing(gui.ax_profile)) || return Consume(false)
        event.button == Mouse.left || return Consume(false)

        if event.action == Mouse.press
            plt, i = pick(fig)
            if Keyboard.d in events(fig).keyboardstate
                # Delete marker
                deleteat!(gui.picks[], i)
                notify(gui.picks)
                println("   deleted pick")
                return Consume(true)
            elseif Keyboard.a in events(fig).keyboardstate
                # Add marker
                push!(gui.picks[], mouse_pick_position(gui))
                notify(gui.picks)
                println("   added pick")
                return Consume(true)
            else
                # Initiate drag --> this is not working yet
                gui.dragging   = plt == gui.pick_plot
                gui.drag_index = i
                return Consume(gui.dragging)
            end
        elseif event.action == Mouse.release
            # Exit drag
            gui.dragging = false
        end
        return Consume(false)
    end

    on(events(fig).mouseposition, priority = 2) do mp
        (gui.pick_toggle.active[] && gui.dragging) || return Consume(false)
        gui.picks[][gui.drag_index] = mouse_pick_position(gui)
        notify(gui.picks)
        return Consume(true)
    end
    return nothing
end

# position of the mouse in the profile axis, as a pick
mouse_pick_position(gui) = Point3f(mouseposition(gui.ax_profile)..., PICK_Z)
