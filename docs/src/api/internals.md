# Building blocks

```@meta
CurrentModule = AdriaArrayGeometryPicker
```

The picker window is assembled from building blocks that can be reused for other windows.
They are not exported; call them as `AdriaArrayGeometryPicker.picker_layout` etc., or import
them with `using AdriaArrayGeometryPicker: picker_layout, ...`.

```@docs
AdriaArrayGeometryPicker
```

## Assembling a window

[`geometry_picker`](@ref) builds the window like this:

```julia
using AdriaArrayGeometryPicker
using AdriaArrayGeometryPicker: picker_layout, on_profile_loaded, picking_state, menu_selection
using GLMakie

profile = Observable{Any}(nothing)
profile_file = Observable("")
profile_path = Observable("")
fig, panels, axis, widgets = picker_layout(; profile)
states = on_profile_loaded(profile, profile_file, axis, panels, widgets)
picking = picking_state(fig, profile, axis, widgets)
session = (; fig, profile, profile_file, profile_path, panels, axes = axis, widgets, picking, states...)
menu_selection(widgets.menu, session)
display(fig)
```

```@docs
picker_layout
profile_plot_area!
set_profile_layout!
on_profile_loaded
connect_profile!
menu_selection
is_state_file
```

## Profiles

```@docs
load_profile!
open_profile!
is_vertical
slice_depth
```

## Volume data

```@docs
volume_panel!
volume_plot_state
load_volume_data!
plot_volume!
plot_contours!
clear_contours!
volume_entries
surface_entries
```

## Surface and point data

```@docs
surface_plot_state
load_surface_data!
point_plot_state
load_point_data!
```

## Topography

```@docs
topography_panel_state
load_topography_panel!
plot_topography!
fit_horizontal_axis!
```

## Map overview

```@docs
map_panel!
map_plot_state
load_topography!
update_map_line!
fit_map!
```

## Compared picks

```@docs
compare_plot_state
add_compare_picks!
load_compare_picks!
clear_compare_picks!
```

## Picks on a profile

```@docs
picking_state
pick_lonlat
profile_track
picks_match_profile
```

## Settings of a window

```@docs
gui_settings
apply_settings!
```

## Generic: panels and widgets

These do not depend on the profile data and work in any Makie figure.

```@docs
control_panel!
fit_panel!
set_visible!
panel_toggle
exclusive_panels!
link_range_controls!
parse_levels
label_of
select_label!
set_text!
```

## Generic: picking on an axis

```@docs
PICK_Z
pickable!
set_pick_points!
```

## Generic: file dialogs and screenshots

The native file dialogs block the thread they run on. The `with_*` functions run them in a
background task, so that the window keeps drawing while a dialog is open. The dialogs can be
replaced, for example in tests:

```julia
AdriaArrayGeometryPicker.OPEN_DIALOG[] = (; kwargs...) -> "picks.aagpp"
```

```@docs
open_dialog
save_dialog
with_open_dialog
with_save_dialog
save_picks_dialog
load_picks_dialog
OPEN_DIALOG
SAVE_DIALOG
PICKS_FILTER
IMAGE_FILTER
save_screenshot
save_screenshot_dialog
```
