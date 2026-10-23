"""
    PICK_Z = 1000

z value of the pick markers of [`pickable!`](@ref): the third coordinate of every pick, so that
the markers are drawn above the heatmap, contours, surface lines and points. Generic. Use [`set_pick_points!`](@ref) to set picks from code
without handling it yourself.
"""
const PICK_Z = 1000

"""
    pickable!(fig, ax::Axis; active = Observable(true)) -> NamedTuple

Make `ax` pickable and return the picking state `(; picks, scatter, dragging, index)`.
Generic: works on any `Axis`, independent of the profile data. `picks` is an
`Observable{Vector{Point3d}}` with the picked points in data coordinates of `ax`, in double
precision (`Point3d` = `Point3{Float64}`), so values set from code or loaded from a file are
kept exactly. The third coordinate is always [`PICK_Z`](@ref); it only keeps the markers on top
of everything else. The picks are drawn by `scatter`.

Picking is active while `active` (e.g. the `active` Observable of a `Toggle`) is `true`. The
mouse is handled with high priority, so clicks on picks do not zoom or pan the axis:

- **A + click** adds a pick at the mouse position (inside `ax`),
- **D + click** removes the pick under the mouse,
- **click and drag** a pick moves it (release the button to drop it).

(Holding ctrl in addition is allowed.) `Picks(state.picks[])` converts the picks to a
[`Picks`](@ref); [`set_pick_points!`](@ref) sets them from code.

# Arguments
- `fig`: the figure that contains `ax` (its mouse events are used).
- `ax`: the axis to pick on.

# Keywords
- `active`: `Observable{Bool}` that switches picking on and off (default: always on).

# Returns
The picking state `(; picks, scatter, dragging, index)`. `dragging` and `index` are `Ref`s used
internally to track the pick being moved. For picking on a GMG profile see
[`picking_state`](@ref).

# Example
```julia
fig = Figure()
ax = Axis(fig[1, 1])
toggle = Toggle(fig[2, 1]; active = true)
state = pickable!(fig, ax; active = toggle.active)
on(state.picks) do pts
    println(length(pts), " picks")
end
```
"""
function pickable!(fig, ax::Axis; active::Observable = Observable(true))
    picks = Observable(Point3d[])
    scatter = scatter!(ax, picks; color = :white, markersize = 15, strokewidth = 2,
                       strokecolor = :black)
    state = (; picks, scatter, dragging = Ref(false), index = Ref(0))
    ev = events(fig)
    pick_point(position) = Point3d(position[1], position[2], PICK_Z)

    on(ev.mousebutton; priority = 2) do event
        active[] && event.button == Mouse.left || return Consume(false)
        if event.action == Mouse.press
            Makie.is_mouseinside(ax) || return Consume(false)
            held = ev.keyboardstate
            if Keyboard.d in held || Keyboard.a in held
                if Keyboard.d in held
                    plt, i = Makie.pick(fig)
                    plt === scatter && 1 <= i <= length(picks[]) && (deleteat!(picks[], i); notify(picks))
                else
                    push!(picks[], pick_point(mouseposition(ax)))
                    notify(picks)
                end
                return Consume(true)
            end
            plt, i = Makie.pick(fig)
            state.dragging[] = plt === scatter && 1 <= i <= length(picks[])
            state.index[] = i
            return Consume(state.dragging[])
        elseif event.action == Mouse.release && state.dragging[]
            state.dragging[] = false
            return Consume(true)
        end
        return Consume(false)
    end

    on(ev.mouseposition; priority = 2) do _
        if active[] && state.dragging[]
            picks[][state.index[]] = pick_point(mouseposition(ax))
            notify(picks)
            return Consume(true)
        end
        return Consume(false)
    end
    return state
end

"""
    set_pick_points!(picking, points) -> picking

Replace the picks of the picking state `picking` (of [`pickable!`](@ref) or
[`picking_state`](@ref)) by `points`, given as 2D points in data coordinates of the axis: any
indexable objects with at least two coordinates (tuples, `Point2`, `Point3`, vectors; a third
coordinate is ignored). The picks are stored in double precision with the z value
[`PICK_Z`](@ref), which keeps the markers on top. Generic.

# Arguments
- `picking`: the picking state; only its field `picks` is used.
- `points`: the new picks, e.g. `[(1.0, 2.0), (3.0, 4.0)]` or `points(p)` of a [`Picks`](@ref)
  (an empty vector removes all picks).

Returns `picking`.

# Example
```julia
fig = Figure()
ax = Axis(fig[1, 1])
picking = pickable!(fig, ax)
set_pick_points!(picking, [(1.0, 2.0), (3.0, 4.5)])
picking.picks[]     # [Point3d(1.0, 2.0, 1000.0), Point3d(3.0, 4.5, 1000.0)]
```
"""
function set_pick_points!(picking, pts)
    picking.picks[] = Point3d[Point3d(q[1], q[2], PICK_Z) for q in pts]
    return picking
end
