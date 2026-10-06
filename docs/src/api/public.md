# Public API

```@meta
CurrentModule = AdriaArrayGeometryPicker
```

These are the functions and types exported by `AdriaArrayGeometryPicker` (plus the two
accessors [`columns`](@ref) and [`metadata`](@ref), which are not exported because their names
are common).

## The picker window

```@docs
geometry_picker
```

## Picks

```@docs
Picks
points
columns
metadata
save_picks
load_picks
```

## Picks and state of a window

```@docs
current_picks
set_picks!
save_gui_state
load_gui_state!
```
