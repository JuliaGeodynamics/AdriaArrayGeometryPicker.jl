# Using the picker from the REPL

```@meta
CurrentModule = AdriaArrayGeometryPicker
```

Everything in the window can also be done from Julia code. This is useful to export picks in
another format, to process many pick files, or to prepare a window with given settings.

## The session

[`geometry_picker`](@ref) returns the *session*, a `NamedTuple` with everything that belongs to
the window:

```julia
using AdriaArrayGeometryPicker
session = geometry_picker("profile.pgmg")
```

| Field | Content |
|:--|:--|
| `fig` | the Makie `Figure` |
| `screen` | the GLMakie screen (window) |
| `profile` | `Observable` with the loaded GMG `ProfileData` (`nothing` before a profile is loaded) |
| `profile_file`, `profile_path` | `Observable`s with the file name and the full path of the profile |
| `panels`, `axes`, `widgets` | the layouts, axes and widgets of the window (see [`picker_layout`](@ref)) |
| `picking` | the picks (see [`picking_state`](@ref)) |
| `volume`, `surface`, `points`, `topography`, `topomap`, `compare` | the plot states of the panels |

## Getting and setting picks

[`current_picks`](@ref) returns the picks of the window as a [`Picks`](@ref) object, with the
columns `x`, `depth`, `lon` and `lat` and the metadata (user, date, profile):

```julia
p = current_picks(session)
points(p)                                    # the (x, depth) points
AdriaArrayGeometryPicker.columns(p)          # all columns as a NamedTuple
AdriaArrayGeometryPicker.metadata(p)         # user, date, profile_file, ...
save_picks("picks.csv", p)                   # or "picks.aagpp"
```

[`set_picks!`](@ref) puts picks into the window. As with **Load Picks**, picks of another
profile of the same type (vertical or horizontal) are taken over as well, with a warning; picks
of the other type are not loaded:

```julia
set_picks!(session, load_picks("picks.aagpp"))       # false if they belong to another profile (warning shown, not loaded if of the other type)
```

To set picks from coordinates, create a [`Picks`](@ref) object:

```julia
set_picks!(session, Picks([(100.0, -50.0), (250.0, -120.0)]; names = (:x, :depth)))
```

## Working with pick files without a window

[`load_picks`](@ref), [`save_picks`](@ref) and [`Picks`](@ref) need no window. For example,
to convert all `.aagpp` files in a folder to CSV:

```julia
using AdriaArrayGeometryPicker

for file in filter(endswith(".aagpp"), readdir("picks"; join = true))
    save_picks(replace(file, r"\.aagpp$" => ".csv"), load_picks(file))
end
```

## Saving and restoring the state

```julia
save_gui_state("my_state", session)          # writes my_state.aagps
load_gui_state!(session, "my_state.aagps")
```

## Rendering the window into an image

With the keyword `save`, [`geometry_picker`](@ref) renders the window offscreen into a PNG
file instead of showing it, for example for reports:

```julia
geometry_picker("my_state.aagps"; save = "picker.png")
```

## Building your own window

The window is assembled from building blocks: panels, plot states for the volume, surface,
point and topography data, picking, file dialogs and state IO. They can be combined into other
windows, for example a window without contour lines or with a different layout. They are
documented in [Building blocks](@ref).
