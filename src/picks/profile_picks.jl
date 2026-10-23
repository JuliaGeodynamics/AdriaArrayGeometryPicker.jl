# Picks on a GeophysicalModelGenerator profile: interactive picking in the profile axis and
# conversion between the picks of the GUI and `Picks` (with longitude / latitude and profile
# information).

"""
    picking_state(fig, profile::Observable, ax::Axis; active = Observable(true)) -> NamedTuple
    picking_state(fig, profile::Observable, axes, widgets) -> NamedTuple

Make the profile axis pickable with [`pickable!`](@ref) and return its picking state
`(; picks, scatter, dragging, index)`. The data coordinates of the picks are x (distance
along the profile) and depth; on a horizontal slice they are longitude and latitude instead.
`picks` holds them as `Point3d` (double precision, z = [`PICK_Z`](@ref)); set them from code
with [`set_pick_points!`](@ref) or [`set_picks!`](@ref). Profile-specific wrapper of the
generic [`pickable!`](@ref); requires a GeophysicalModelGenerator `ProfileData` in `profile`.

Picking is active while `active` is `true`. A newly loaded profile clears the picks (listener of
`profile` with priority `-20`). See [`current_picks`](@ref) and [`set_picks!`](@ref) for the
connection to [`Picks`](@ref).

# Arguments
- `fig`: the figure of the window (`fig` of [`picker_layout`](@ref)).
- `profile`: `Observable` that holds the profile.
- `ax`: the profile axis.
- `axes`, `widgets`: as returned by [`picker_layout`](@ref); picks are made in `axes.profile`
  while the "Picking" toggle `widgets.pick_toggle` is on.

# Keywords
- `active`: `Observable{Bool}` that switches picking on and off, e.g. the `active` of a
  `Toggle` (default: always on).

# Returns
The picking state of [`pickable!`](@ref), `(; picks, scatter, dragging, index)`.

# Example
```julia
# window of `picker_layout`
profile = Observable{Any}(nothing)
fig, panels, axis, widgets = picker_layout(; profile)
picking = picking_state(fig, profile, axis, widgets)

# own layout
fig = Figure()
area = profile_plot_area!(fig[1, 1])
toggle = Toggle(fig[2, 1]; active = true)
picking = picking_state(fig, profile, area.profile; active = toggle.active)
```
"""
picking_state(fig, profile::Observable, axes, widgets) =
    picking_state(fig, profile, axes.profile; active = widgets.pick_toggle.active)
function picking_state(fig, profile::Observable, ax::Axis; active::Observable = Observable(true))
    state = pickable!(fig, ax; active)
    # picks belong to one profile
    on(profile; priority = -20) do p
        state.dragging[] = false
        isempty(state.picks[]) || (state.picks[] = Point3d[])
    end
    return state
end

# the longitude / latitude pairs in `x` (a tuple, vector or the text of one, as in CSV files)
_lonlat(x) = x === nothing ? nothing :
             parse.(Float64, [m.match for m in eachmatch(r"-?\d+(\.\d+)?([eE][-+]?\d+)?", string(x))])

"""
    profile_track(profile) -> Union{Nothing,NTuple{3,Vector{Float64}}}

Distance along the profile (`x_profile`) with the longitude and latitude at each distance,
sorted by distance: from the topography of `profile` (`TopoData`, finest sampling) or, without
topography, from the first column of the volume data. `nothing` if neither is available (and for
horizontal slices, which have no `x_profile`). Requires a GeophysicalModelGenerator
`ProfileData` of a vertical cross-section.

Returns `(x, lon, lat)`, three vectors of the same length.
"""
function profile_track(profile)
    geos = Any[]
    profile.TopoData === nothing || isempty(profile.TopoData) || push!(geos, first(values(profile.TopoData)))
    vol = profile.VolData
    vol === nothing || push!(geos, vol isa NamedTuple ? first(values(vol)) : vol)
    for g in geos
        haskey(g.fields, :x_profile) || continue
        # 1D (topography) or regular grid (volume data: x varies along the first dimension)
        xp, lon, lat = g.fields.x_profile, g.lon.val, g.lat.val
        n = size(xp, 1)
        x = Float64[xp[i] for i in 1:n]
        lo = Float64[lon[i] for i in 1:n]
        la = Float64[lat[i] for i in 1:n]
        order = sortperm(x)
        length(x) >= 2 && return x[order], lo[order], la[order]
    end
    return nothing
end

# linear interpolation of `ys(xs)` at `x`; NaN outside the range of `xs` (sorted)
function _interp(xs, ys, x)
    (isnan(x) || x < xs[1] || x > xs[end]) && return NaN
    i = clamp(searchsortedlast(xs, x), 1, length(xs) - 1)
    t = xs[i+1] == xs[i] ? 0.0 : (x - xs[i]) / (xs[i+1] - xs[i])
    return ys[i] + t * (ys[i+1] - ys[i])
end

"""
    pick_lonlat(profile, x) -> (lon, lat)

Longitude and latitude of the picks at the distances `x` along `profile`, interpolated linearly
from the coordinates of the profile data (see [`profile_track`](@ref)). NaN for distances
outside the profile, and for all picks if the profile has no coordinates. Vertical profiles
only; requires a GeophysicalModelGenerator `ProfileData`.

# Arguments
- `profile`: the loaded profile (or `nothing`).
- `x`: vector of distances along the profile.

Returns the vectors `(lon, lat)`, one value per distance.
"""
function pick_lonlat(profile, x::AbstractVector)
    track = profile === nothing ? nothing : profile_track(profile)
    track === nothing && return fill(NaN, length(x)), fill(NaN, length(x))
    xs, lon, lat = track
    return [_interp(xs, lon, xi) for xi in x], [_interp(xs, lat, xi) for xi in x]
end

# start / end point stored with picks: as metadata of this package, or in the `profile_info`
# entry of files of the old AdriaArray picker
function _picks_lonlat(p::Picks, key)
    value = get(p.metadata, key, nothing)
    info = get(p.metadata, "profile_info", nothing)
    if value === nothing && info !== nothing
        value = info isa AbstractDict ? get(info, key, get(info, Symbol(key), nothing)) :
                hasproperty(info, Symbol(key)) ? getproperty(info, Symbol(key)) : nothing
    end
    return _lonlat(value)
end

"""
    picks_match_profile(profile, picks::Picks; warn = true) -> Bool

Whether `picks` belong to `profile`: they were made on the same type of profile (vertical or
horizontal; files that do not say are taken as vertical) and their start / end coordinates
(vertical) or depth (horizontal), if the file has them, are those of the profile. Requires a
GeophysicalModelGenerator `ProfileData`.

# Arguments
- `profile`: the loaded profile (or `nothing`).
- `picks`: the [`Picks`](@ref), e.g. from [`load_picks`](@ref); its metadata `profile_type`,
  `start_lonlat`, `end_lonlat` and `depth` are compared.

# Keywords
- `warn`: log a warning that says why the picks do not match.

Returns `true` if the picks match, `false` if not or if no profile is loaded.
"""
function picks_match_profile(profile, p::Picks; warn::Bool = true)
    reason = _picks_mismatch(profile, p)
    reason === nothing && return true
    warn && @warn reason
    return false
end

# why `p` does not belong to `profile` (`nothing` if it does)
function _picks_mismatch(profile, p::Picks)
    profile === nothing && return "Load a profile before loading picks"
    kind = is_vertical(profile) ? "vertical" : "horizontal"
    _picks_type(p) != kind &&
        return "The picks were made on a $(_picks_type(p)) profile, the loaded profile is $kind"
    if !is_vertical(profile)
        depth = tryparse(Float64, string(get(p.metadata, "depth", "")))
        if depth !== nothing && !isapprox(depth, slice_depth(profile); atol = 1e-6)
            return "The picks belong to a slice at depth $depth, the loaded slice is at $(slice_depth(profile))"
        end
        return nothing
    end
    for (key, want) in (("start_lonlat", profile.start_lonlat), ("end_lonlat", profile.end_lonlat))
        have = _picks_lonlat(p, key)
        if have !== nothing && want !== nothing &&
           !(length(have) == 2 && all(isapprox.(have, collect(want); atol = 1e-6)))
            return "The picks belong to a different profile ($key $have, loaded profile: $want)"
        end
    end
    return nothing
end

"""
    current_picks(session) -> Picks

The picks of the GUI as a [`Picks`](@ref) with the coordinates `(:x, :depth)`, the columns
`lon` and `lat` (interpolated from the profile, see [`pick_lonlat`](@ref)) and the metadata
`user` (the name in the user name field), `date`, `profile_file`, `profile_type` ("vertical" or
"horizontal") and the start / end coordinates of the profile. On a horizontal slice the picks
are made in the lon/lat plane: `x` is NaN, `depth` is the depth of the slice, `lon` and `lat`
are the picked position, and the metadata hold the `depth` of the slice instead of the start / end
coordinates.

# Arguments
- `session`: a `NamedTuple` (or any object with these properties); the `session` of the
  picker (see [`menu_selection`](@ref)) has them all:
  - `profile` (required): the `Observable` that holds the profile,
  - `picking` (required): the picking state of [`picking_state`](@ref),
  - `profile_file` (optional): `Observable` with the name of the profile file (default `""`),
  - `widgets.pick_name` (optional): the user name `Textbox` (default user: `""`).

A custom GUI only needs e.g. `session = (; profile, picking)`. Requires a
GeophysicalModelGenerator `ProfileData` (or `nothing`, then `lon` and `lat` are NaN).

Returns the [`Picks`](@ref).

# Example
```julia
fig = Figure()
area = profile_plot_area!(fig[1, 1])
pick_name = Textbox(fig[2, 1]; placeholder = "User name")
profile = Observable{Any}(nothing)
profile_file = Observable("")
picking = picking_state(fig, profile, area.profile)
session = (; profile, profile_file, picking, widgets = (; pick_name))
open_profile!(session, joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "Profile1.pgmg"))
set_pick_points!(picking, [(100.0, -50.0), (250.0, -120.0)])
set_text!(pick_name, "MT")
p = current_picks(session)          # columns x, depth, lon, lat; metadata user = "MT", ...
save_picks("picks.csv", p)
```
"""
function current_picks(session)
    profile = session.profile[]
    meta = Dict{String,Any}("user" => _user_name(session), "date" => string(Dates.now()),
                            "profile_file" => hasproperty(session, :profile_file) ? session.profile_file[] : "",
                            "profile_type" => is_vertical(profile) ? "vertical" : "horizontal")
    pts = [(Float64(p[1]), Float64(p[2])) for p in session.picking.picks[]]
    if !is_vertical(profile)
        # horizontal slice: the picks are (lon, lat) at the depth of the slice; x is NaN, so the
        # files have the same columns as those of vertical profiles
        depth = slice_depth(profile)
        meta["depth"] = depth
        return Picks([(NaN, depth) for _ in pts]; names = (:x, :depth),
                     columns = (; lon = first.(pts), lat = last.(pts)), metadata = meta)
    end
    if profile !== nothing
        meta["start_lonlat"] = profile.start_lonlat
        meta["end_lonlat"] = profile.end_lonlat
    end
    lon, lat = pick_lonlat(profile, first.(pts))
    return Picks(pts; names = (:x, :depth), columns = (; lon, lat), metadata = meta)
end

# the user name field of a session (`session.widgets.pick_name`), `nothing` if it has none
_pick_name(session) = hasproperty(session, :widgets) && hasproperty(session.widgets, :pick_name) ?
                      session.widgets.pick_name : nothing
# the user name typed in the user name field of a session, "" without one
_user_name(session) = (box = _pick_name(session);
                       box === nothing ? "" : string(something(box.stored_string[], "")))

# type of the profile the picks were made on ("vertical" for files that do not say)
_picks_type(p::Picks) = lowercase(string(get(p.metadata, "profile_type", "vertical")))

# horizontal picks as plotted: (lon, lat)
horizontal_xy(p::Picks) = haskey(p.columns, :lon) && haskey(p.columns, :lat) ?
                          [(Float64(lo), Float64(la)) for (lo, la) in zip(p.columns.lon, p.columns.lat)] :
                          [(q[1], q[2]) for q in points(p)]

"""
    set_picks!(session, picks::Picks) -> Bool

Show `picks` as the (editable) picks of the GUI. Picks that were made on the other type of
profile (vertical or horizontal, see the metadata `profile_type`; files that do not say are
vertical) are not loaded: the function warns and returns `false`, as it does without a loaded
profile. Picks of another profile of the same type (other start / end point or slice depth) are
taken over with a warning below the "Picking" label (`widgets.pick_warning`, if the session has
it) and in the log; saving them assigns them to the current profile, user and time (see
[`current_picks`](@ref)), on a horizontal slice also the depth of the loaded slice. Returns
`true` if the picks belong to the loaded profile, `false` if not (see [`picks_match_profile`](@ref)).
The user name of the picks is put into the user name field if that is empty. On a horizontal
slice the picks are shown at their `lon` / `lat` columns.

# Arguments
- `session`: as for [`current_picks`](@ref): `profile` and `picking` are required,
  `widgets.pick_name` is optional (without it the user name is not shown).
- `picks`: the [`Picks`](@ref), e.g. from [`load_picks`](@ref).

Requires a GeophysicalModelGenerator `ProfileData`.
"""
function set_picks!(session, p::Picks)
    profile = session.profile[]
    reason = _picks_mismatch(profile, p)
    # picks of a vertical profile are not loaded on a horizontal slice and vice versa
    if profile === nothing || _picks_type(p) != (is_vertical(profile) ? "vertical" : "horizontal")
        @warn "$reason, not loaded"
        return false
    end
    reason === nothing || @warn "$reason, check the picks before saving"
    _set_pick_warning!(session, reason === nothing ? "" : "Picks of another profile: $reason")
    xy = is_vertical(session.profile[]) ? [(q[1], q[2]) for q in points(p)] : horizontal_xy(p)
    set_pick_points!(session.picking, xy)
    user = string(get(p.metadata, "user", ""))
    box = _pick_name(session)
    box !== nothing && !isempty(user) && isempty(_user_name(session)) && set_text!(box, user)
    return reason === nothing
end

# the warning label below the "Picking" label of a session (`session.widgets.pick_warning`)
function _set_pick_warning!(session, text)
    hasproperty(session, :widgets) && hasproperty(session.widgets, :pick_warning) &&
        (session.widgets.pick_warning.text[] = text)
    return nothing
end
