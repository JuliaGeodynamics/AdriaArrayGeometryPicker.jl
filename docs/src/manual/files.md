# Files: picks, states, screenshots

The picker reads and writes four kinds of files:

| File | Extension | Written by | Read by |
|:--|:--|:--|:--|
| profile | `.pgmg` | GeophysicalModelGenerator.jl | **Load Profile** |
| picks | `.aagpp` (JLD2) or `.csv` | **Save Picks** | **Load Picks**, **Load Compare Picks** |
| state of the window | `.aagps` (JLD2) | **Save State** | **Load State**, `geometry_picker(path)` |
| screenshot | `.png` | **Save Screenshot** | – |

The details of the file contents are in [File formats](@ref).

## Saving picks

1. Choose **Menu → Save Picks**.
2. Choose a file name. The format follows the extension:
   - `.aagpp`: a JLD2 file. It keeps all values exactly and is the best choice for loading the
     picks into the picker again.
   - `.csv`: a text file with one row per pick, easy to read in a spreadsheet, Python, GMT etc.

   A name without extension gets `.aagpp`.

The picks are taken at the moment you close the dialog. The REPL logs where they were saved:

```
[ Info: Picks saved to C:\data\picks_MT.aagpp
```

A CSV pick file looks like this:

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
300.0,-80.0,12.191160417839841,44.99923534718524
```

!!! tip "Name your files"
    Pick files of several people for the same profile are easier to handle with names such as
    `Profile1_Moho_MT.aagpp`.

## Loading picks

1. Load the profile the picks belong to.
2. Choose **Menu → Load Picks** and choose a `.aagpp`, `.csv` or `.jld2` pick file.

The loaded picks replace the current picks and can be edited. If the **User name** field is
empty, it is filled with the user name stored in the file.

Picks are only loaded if they belong to the loaded profile: the type of profile (vertical or
horizontal) and the start and end coordinates (or the depth of a horizontal slice) must
match. If they do not, a warning in the REPL tells you why, and the current picks stay. Files
without profile information (for example a CSV file written by another program) are accepted.

Pick files of MakiePickerGUI.jl and of the original AdriaArrayGeometryPicker.jl (`.jld2`) can be
loaded as well.

## Saving and restoring the state of the window

A *state* stores everything you need to continue where you stopped:

- the path of the profile file (the profile data itself is not copied; it is loaded again
  from this file),
- the settings of the panels: the selected fields, colormaps and colour limits, contour
  levels, which surfaces and point data sets are shown, the topography settings, which panel
  is expanded,
- the topography file of the map overview,
- the user name,
- your picks and the compared picks (the picks themselves, so the state still works if the
  pick files have been moved or deleted).

To save the state, choose **Menu → Save State** and choose a file name (`.aagps` is added if
there is no extension). This needs a profile that was loaded from a file.

To restore a state, either

- choose **Menu → Load State** and choose the `.aagps` file, or
- open the window with it: `geometry_picker("my_state.aagps")`.

!!! warning "Keep the profile file where it is"
    A state refers to the profile file by its full path. If the profile file has been moved
    or deleted, the state cannot be restored and an error is logged. Settings that do not fit
    the profile (for example a field that it no longer contains) are skipped with a warning.

State files (`.jld2`) of MakiePickerGUI.jl can be loaded as well.

## Screenshots

Choose **Menu → Save Screenshot** and choose a file name. The whole window is saved as a PNG
image at twice the screen resolution. A name without extension gets `.png`.

## Closing the window

Choose **Menu → Close**, or close the window as usual. Unsaved picks are lost; there is no
question whether to save them.
