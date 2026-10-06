"""
    AdriaArrayGeometryPicker

The AdriaArray geometry picker: a GLMakie window for visualizing GeophysicalModelGenerator.jl
profiles (vertical cross-sections and horizontal slices) and picking points on them. Start it
with [`geometry_picker`](@ref).

The code is split into two parts:

- generic building blocks, independent of the profile data structure:
  - [`Picks`](@ref): container for a single set of picked points plus metadata
  - [`save_picks`](@ref) / [`load_picks`](@ref): JLD2 and CSV file IO
  - file dialogs that do not block the GUI ([`save_picks_dialog`](@ref), ...)
  - [`save_screenshot`](@ref)
  - panels with a header, optionally collapsible ([`control_panel!`](@ref), [`fit_panel!`](@ref),
    [`exclusive_panels!`](@ref)) and widget helpers ([`link_range_controls!`](@ref), [`parse_levels`](@ref),
    [`select_label!`](@ref), [`set_text!`](@ref))
  - interactive picking on an `Axis` ([`pickable!`](@ref), [`set_pick_points!`](@ref))
- GeophysicalModelGenerator profiles, built on the generic part:
  - [`load_profile!`](@ref), [`is_vertical`](@ref), [`slice_depth`](@ref)
  - the picker window: [`picker_layout`](@ref), [`on_profile_loaded`](@ref), [`menu_selection`](@ref),
    assembled by [`geometry_picker`](@ref)
  - plots of the volume, surface, point and topography data, the map overview and picks of
    other files, each with a state (e.g. [`volume_plot_state`](@ref)) that is filled for every
    loaded profile (e.g. [`load_volume_data!`](@ref))
  - picks on a profile: [`picking_state`](@ref), [`current_picks`](@ref), [`set_picks!`](@ref),
    [`pick_lonlat`](@ref)
  - [`save_gui_state`](@ref) / [`load_gui_state!`](@ref): profile and GUI state IO

Derived from MakiePickerGUI.jl (GeometryPicker repository); it contains only the code of its
ready-made picker window.
"""
module AdriaArrayGeometryPicker

using Dates
using DelimitedFiles
using GeometryBasics: Point2
using JLD2
using GLMakie                   # interactive backend; also provides the widgets (Menu, Toggle, ...)
import Makie
import NativeFileDialog
using ColorSchemes: ColorSchemes
using GeophysicalModelGenerator: GeophysicalModelGenerator, ustrip

# generic building blocks
include("picks.jl")
include("picks_io.jl")
include("dialogs.jl")
include("screenshot.jl")
include("widget_helpers.jl")
include("panels.jl")
include("picking.jl")

# GeophysicalModelGenerator profiles
include("profile_io.jl")
include("layout.jl")
include("topography.jl")
include("topography_panel.jl")
include("volume.jl")
include("surface.jl")
include("points.jl")
include("map_overview.jl")
include("profile_events.jl")
include("profile_picks.jl")
include("compare_picks.jl")
include("gui_state.jl")
include("menu.jl")

# the picker window
include("geometry_picker.jl")

export geometry_picker
export Picks, points, save_picks, load_picks
export current_picks, set_picks!, save_gui_state, load_gui_state!

end
