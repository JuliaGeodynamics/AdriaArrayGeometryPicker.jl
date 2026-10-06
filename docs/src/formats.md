# File formats

```@meta
CurrentModule = AdriaArrayGeometryPicker
```

The picker recognises its files by their content, not by their extension.

## Profiles (`.pgmg`)

A JLD2 file with a single entry, a GeophysicalModelGenerator `ProfileData` object. The name of
the entry does not matter. Profile files are made with GeophysicalModelGenerator.jl
(branch `profile_processing_mt`); see [`load_profile!`](@ref).

The picker uses these fields of the `ProfileData`:

| Field | Used for |
|:--|:--|
| `vertical` | vertical cross-section (`true`) or horizontal slice (`false`) |
| `start_lonlat`, `end_lonlat` | start and end point of a vertical profile |
| `depth` | depth of a horizontal slice |
| `VolData` | volume data (a `GeoData`, or a `NamedTuple` of them), shown as heatmap and contour lines |
| `SurfData` | surface data (`NamedTuple` of `GeoData`), shown as lines |
| `PointData` | point data (`NamedTuple` of `GeoData`), shown as markers |
| `TopoData` | topography (`NamedTuple` of `GeoData`) |

## Picks (`.aagpp`, `.csv`)

Written by [`save_picks`](@ref) (**Menu → Save Picks**), read by [`load_picks`](@ref).

### JLD2 (`.aagpp`)

| Entry | Content |
|:--|:--|
| `format` | `"AdriaArrayGeometryPicker.Picks"` |
| `version` | `1` |
| `names` | the names of the two coordinates, e.g. `["x", "depth"]` |
| `picks` | all columns as a `NamedTuple` of vectors, e.g. `(x = [...], depth = [...], lon = [...], lat = [...])` |
| `metadata` | a `Dict{String,Any}` |

### CSV (`.csv`)

Metadata as `# key = value` comment lines (nested keys joined with `.`), then a header row and
one row per pick:

```
# AdriaArrayGeometryPicker.Picks v1
# date = 2026-10-05T10:31:12.123
# end_lonlat = (15.465423125301268, 47.79656290565586)
# profile_file = Profile1.pgmg
# profile_type = vertical
# start_lonlat = (9.777223439354351, 42.936916884179524)
# user = MT
x,depth,lon,lat
60.0,-35.0,10.257199224941168,43.346978510988194
180.0,-45.0,11.221291268553239,44.17063912818688
```

Metadata values in CSV files are text, so they come back as strings from [`load_picks`](@ref).

### Columns and metadata of picks made in the picker

| Column | Vertical profile | Horizontal slice |
|:--|:--|:--|
| `x` | distance along the profile (km) | `NaN` |
| `depth` | depth (km) | depth of the slice |
| `lon`, `lat` | interpolated along the profile (`NaN` outside the profile) | picked position |

| Metadata | Content |
|:--|:--|
| `user` | the name in the **User name** field |
| `date` | date and time of saving |
| `profile_file` | file name of the profile |
| `profile_type` | `"vertical"` or `"horizontal"` |
| `start_lonlat`, `end_lonlat` | start and end of a vertical profile |
| `depth` | depth of a horizontal slice |

### Older pick files

[`load_picks`](@ref) also reads the pick files of MakiePickerGUI.jl (format
`"MakiePickerGUI.Picks"`) and of the original AdriaArrayGeometryPicker.jl (`.jld2`).

## State of the window (`.aagps`)

Written by [`save_gui_state`](@ref) (**Menu → Save State**), read by
[`load_gui_state!`](@ref). A JLD2 file with:

| Entry | Content |
|:--|:--|
| `format` | `"AdriaArrayGeometryPicker state"` (state files of MakiePickerGUI.jl: `"MakiePickerGUI state"`) |
| `version` | `1` |
| `profile_path` | full path of the profile file; the profile is loaded again from this file |
| `settings` | a `Dict{String,Any}` with the settings of the window, see [`gui_settings`](@ref) |
