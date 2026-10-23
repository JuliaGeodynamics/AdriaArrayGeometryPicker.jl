"""
    load_profile!(profile::Observable, path) -> profile data

Load the GeophysicalModelGenerator profile stored in the `.pgmg` file `path` and assign it
to `profile`, which notifies everything that listens to it (see [`on_profile_loaded`](@ref)).
Returns the loaded `ProfileData`. The file may hold a vertical cross-section or a horizontal
slice, see [`is_vertical`](@ref).

# Arguments
- `profile`: `Observable` that holds the current profile (`nothing` before a profile is loaded).
- `path`: path of the `.pgmg` file (a JLD2 file with a single `ProfileData` entry).

# Example
```julia
profile = Observable{Any}(nothing)
load_profile!(profile, joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "Profile1.pgmg"))
```
"""
function load_profile!(profile::Observable, path::AbstractString)
    # the file contains a single entry (the profile), but its name depends on the variable name
    # used when the profile was saved, so the first entry is taken, whatever its name
    data = jldopen(file -> file[first(keys(file))], path)

    profile[] = data
    return data
end

"""
    open_profile!(session, path) -> profile data

Load the profile file `path` into the GUI (see [`load_profile!`](@ref)) and remember its file
name (`session.profile_file`, the title of the topography axis and stored with the picks) and its
full path (`session.profile_path`, for [`save_gui_state`](@ref)). Both are set before the
profile, so the listeners of `profile` see the new names. Returns the loaded profile.

# Arguments
- `session`: a `NamedTuple` (or any object with these properties):
  - `profile` (required): the `Observable` that holds the profile,
  - `profile_file` (optional): `Observable{String}` that receives the file name,
  - `profile_path` (optional): `Observable{String}` that receives the absolute path.
  The `session` of the picker has them all (see [`menu_selection`](@ref)).
- `path`: path of the `.pgmg` file.

Requires a GeophysicalModelGenerator `ProfileData` in the file.
"""
function open_profile!(session, path::AbstractString)
    hasproperty(session, :profile_file) && (session.profile_file[] = basename(path))
    hasproperty(session, :profile_path) && (session.profile_path[] = abspath(path))
    return load_profile!(session.profile, path)
end

"""
    is_vertical(profile) -> Bool

Whether `profile` is a vertical cross-section (`true`, also for `nothing` and for profiles
without a `vertical` field) or a horizontal slice at a certain depth (`false`). Vertical
and horizontal profiles are plotted and picked differently: along the profile (distance, depth) or
in the lon / lat plane. Accepts a GeophysicalModelGenerator `ProfileData` or `nothing`.
"""
is_vertical(profile) = profile === nothing || !isdefined(profile, :vertical) || profile.vertical

"""
    slice_depth(profile) -> Float64

Depth of the horizontal slice `profile` (same sign convention as the depth of the data).
Only meaningful for horizontal slices (`is_vertical(profile) == false`). Requires a
GeophysicalModelGenerator `ProfileData`.
"""
slice_depth(profile) = Float64(profile.depth)
