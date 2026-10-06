# Introduction

The AdriaArray geometry picker is a [GLMakie](https://docs.makie.org) window for viewing
[GeophysicalModelGenerator.jl](https://github.com/JuliaGeodynamics/GeophysicalModelGenerator.jl)
(GMG) profiles, that is vertical cross-sections and horizontal slices, and for picking points
on them. Typical picks are interfaces such as the Moho or the top of a slab.

![The picker window with a vertical profile](assets/window_compare.png)

The window shows:

- the **volume data** of a profile (tomographies etc.) as a heatmap with contour lines,
- **surface data** (Moho etc.) as lines,
- **point data** (seismicity etc.) as markers,
- the **topography** above the profile,
- a **map overview** with the location of the profile.

You add, move and remove picks with the mouse. You can save picks to JLD2 or CSV files,
load them again, and compare them with the picks of other people. You can also save the whole
state of the window (profile, settings and picks) and restore it later.

## Installation

The package is not registered. It needs Julia 1.10 or newer. Install it from a local clone or
from its git repository:

```julia
using Pkg
Pkg.develop(path = "path/to/AdriaArrayGeometryPicker")
# or
Pkg.add(url = "<git URL of AdriaArrayGeometryPicker.jl>")
```

The package depends on a development branch of GeophysicalModelGenerator.jl
(`profile_processing_mt`). This branch is declared in the `[sources]` section of `Project.toml`
and is installed automatically.

## Quick start

```julia
using AdriaArrayGeometryPicker

# open the demo profile that comes with the package
geometry_picker(joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "Profile1.pgmg"))
```

Then:

1. Type your name in the **User name** field (top of the window).
2. Switch the **Picking** toggle on.
3. Hold **A** and click into the profile to add picks. Drag a pick to move it. Hold **D** and
   click a pick to remove it.
4. Choose **Menu → Save Picks** and save the picks as `.aagpp` or `.csv`.

The [Picker manual](manual/getting_started.md) explains every part of the window.

## Origin

This package is derived from MakiePickerGUI.jl (repository GeometryPicker), a set of building
blocks for profile GUIs. It contains only the code of the ready-made picker window. The picker
script of MakiePickerGUI.jl became the function [`geometry_picker`](@ref). State files and pick
files of MakiePickerGUI.jl and of the original AdriaArrayGeometryPicker.jl can still be loaded.
