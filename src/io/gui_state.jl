# the part `key` of a session (a plot state, `picking`, ...), `nothing` if the session has none
_part(session, key::Symbol) = hasproperty(session, key) ? getproperty(session, key) : nothing
# the widget `name` in `session.widgets`, `nothing` if there is none
_widget(session, name::Symbol) =
    (w = _part(session, :widgets); w !== nothing && hasproperty(w, name) ? getproperty(w, name) : nothing)

# the panels whose expand / collapse toggle (`session.widgets.<name>_panel_toggle`) is stored
const SETTINGS_PANELS = (:volume, :surface, :point, :topography, :compare, :map, :screenshot)

"""
    gui_settings(session) -> Dict{String,Any}

The settings of the GUI that can be restored together with the profile (see
[`apply_settings!`](@ref), [`save_gui_state`](@ref)). Only the parts that the session has are
read; a custom GUI without e.g. a map overview or compared picks simply has no such entries.
Requires a GeophysicalModelGenerator `ProfileData` to be loaded.

# Arguments
- `session`: a `NamedTuple` (or any object with these properties). The session of the picker
  (see [`menu_selection`](@ref)) has all of them; a custom GUI passes those it has, with these
  names (all optional except `profile`):

| session field | entries of the settings |
|:--|:--|
| `profile` (required) | – (the profile type decides how compared picks are stored) |
| `volume` ([`volume_plot_state`](@ref)) | `"volume_field"`, `"volume_limits"`, `"volume_cmap"`, `"volume_cmap_reverse"`; with contour widgets also `"contour_field"`, `"contour_visible"`, `"contour_limits"`, `"contour_cmap"`, `"contour_cmap_reverse"`, `"contour_levels"` |
| `surface` ([`surface_plot_state`](@ref)) | `"surface_visible"`: label => toggle state of each surface |
| `points` ([`point_plot_state`](@ref)) | `"point_visible"`: label => toggle state of each point data set |
| `topography` ([`topography_panel_state`](@ref)) | `"topography_controls"`: `"dataset"` (if there are several), `"show"` and `"fill"` (vertical profile) or `"mode"`, `"opacity"` and `"levels"` (horizontal slice); empty without topography data |
| `topomap` ([`map_plot_state`](@ref)) | `"topography_path"`: the topography file of the map overview (`""` if none) |
| `picking` ([`picking_state`](@ref)) | `"picks"`: the editable picks as `x` and `depth` vectors (longitude and latitude on a horizontal slice) |
| `compare` ([`compare_plot_state`](@ref)) | `"compare_picks"`: one `Dict` per file shown for comparison with its `label`, `path`, the picks (`x`, `depth`), `other_profile` and `visible` (its toggle); `"compare_visible"`: the `compare_toggle` of the state, if it has one |
| `widgets.pick_name` (a `Textbox`) | `"user_name"` |
| `widgets.<name>_panel_toggle` (`Toggle`s, `<name>` one of `volume`, `surface`, `point`, `topography`, `compare`, `map`, `screenshot`) | `"expanded_panels"`: name => toggle state |

The picks themselves are stored (not only the paths of their files), so that a state can be
restored even if the pick files have been moved or deleted.

# Returns
The settings as a `Dict{String,Any}` of plain values (strings, numbers, vectors, dictionaries),
so that it can be stored in a JLD2 file.

# Example
```julia
fig = Figure()
area = profile_plot_area!(fig[1, 2])
volume_panel = control_panel!(fig[1, 1], "Volume data"; width = 340)
volume = volume_plot_state(area.profile, volume_panel!(volume_panel; contours = false), area.colorbar)
profile = Observable{Any}(nothing)
connect_profile!(profile, (; volume); axes = area)
picking = picking_state(fig, profile, area.profile)
load_profile!(profile, joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "Profile1.pgmg"))
session = (; profile, volume, picking)
settings = gui_settings(session)      # "volume_field", "volume_limits", ..., "picks"
apply_settings!(session, settings)
```
"""
function gui_settings(session)
    horizontal = !is_vertical(session.profile[])
    visibility(state) = Dict{String,Bool}(label => toggle.active[]
                                          for (label, toggle) in zip(state.labels, state.toggles))
    settings = Dict{String,Any}()

    volume = _part(session, :volume)
    if volume !== nothing
        w = volume.widgets
        settings["volume_field"] = selected_label(w.volume_menu)
        settings["volume_limits"] = collect(w.volume_cbar_slider.interval[])
        settings["volume_cmap"] = selected_label(w.volume_cmap_menu)
        settings["volume_cmap_reverse"] = w.volume_cmap_reverse.checked[]
        if volume.contours
            settings["contour_field"] = selected_label(w.volume_contour_menu)
            settings["contour_visible"] = w.volume_contour_toggle.active[]
            settings["contour_limits"] = collect(w.volume_contour_cbar_slider.interval[])
            settings["contour_cmap"] = selected_label(w.volume_contour_cmap_menu)
            settings["contour_cmap_reverse"] = w.volume_contour_cmap_reverse.checked[]
            settings["contour_levels"] = string(something(w.volume_contour_levels.stored_string[], ""))
        end
    end
    surface = _part(session, :surface)
    surface === nothing || (settings["surface_visible"] = visibility(surface))
    points = _part(session, :points)
    points === nothing || (settings["point_visible"] = visibility(points))
    topography = _part(session, :topography)
    topography === nothing || (settings["topography_controls"] = _topography_settings(topography))
    topomap = _part(session, :topomap)
    topomap === nothing || (settings["topography_path"] = topomap.path[])

    panel_toggles = Dict{String,Bool}()
    for name in SETTINGS_PANELS
        toggle = _widget(session, Symbol(name, "_panel_toggle"))
        toggle === nothing || (panel_toggles[string(name)] = toggle.active[])
    end
    isempty(panel_toggles) || (settings["expanded_panels"] = panel_toggles)
    pick_name = _widget(session, :pick_name)
    pick_name === nothing || (settings["user_name"] = string(something(pick_name.stored_string[], "")))

    picking = _part(session, :picking)
    picking === nothing || (settings["picks"] = _pick_columns(picking.picks[]))
    compare = _part(session, :compare)
    if compare !== nothing
        compare.compare_toggle === nothing || (settings["compare_visible"] = compare.compare_toggle.active[])
        settings["compare_picks"] = [merge(_pick_columns(compare_xy(p, horizontal)),
                                           Dict{String,Any}("label" => label, "path" => path,
                                                            "other_profile" => other, "visible" => toggle.active[]))
                                     for (p, label, path, other, toggle) in
                                         zip(compare.picks, compare.labels, compare.paths,
                                             compare.other_profile, compare.toggles)]
    end
    return settings
end

# the controls of the topography panel as plain values (empty without topography data)
function _topography_settings(topography)
    c = topography.controls[]
    c === nothing && return Dict{String,Any}()
    d = Dict{String,Any}()
    c.menu === nothing || (d["dataset"] = selected_label(c.menu))
    if haskey(c, :show)
        d["show"] = c.show.active[]
        d["fill"] = c.fill.checked[]
    else
        d["mode"] = selected_label(c.mode)
        d["opacity"] = Float64(c.opacity.value[])
        d["levels"] = string(something(c.levels.stored_string[], ""))
    end
    return d
end

# restore `_topography_settings`; keys that are absent or do not fit the panel are skipped
function _apply_topography_settings!(topography, d)
    c = topography.controls[]
    (c === nothing || !(d isa AbstractDict)) && return
    get(d, "dataset", nothing) isa AbstractString && c.menu !== nothing && select_label!(c.menu, d["dataset"])
    if haskey(c, :show)
        get(d, "show", nothing) isa Bool && (c.show.active[] = d["show"])
        get(d, "fill", nothing) isa Bool && (c.fill.checked[] = d["fill"])
    else
        select_label!(c.mode, get(d, "mode", nothing))
        get(d, "opacity", nothing) isa Real && set_close_to!(c.opacity, d["opacity"])
        get(d, "levels", nothing) isa AbstractString && set_text!(c.levels, d["levels"])
    end
    return
end

# coordinates of picks as plain vectors, so that the state file does not depend on Makie types
_pick_columns(pts) = Dict{String,Any}("x" => Float64[p[1] for p in pts], "depth" => Float64[p[2] for p in pts])

# picks from the coordinate vectors of `_pick_columns`
_picks_from_columns(d) = Picks(Vector{Float64}(d["x"]), Vector{Float64}(d["depth"]); names = (:x, :depth))

"""
    apply_settings!(session, settings) -> session

Restore `settings` (see [`gui_settings`](@ref)) in the GUI. A profile has to be loaded already
(requires a GeophysicalModelGenerator `ProfileData`). Only the parts that the session has are
restored: entries for parts it does not have (e.g. contour settings for a volume state without
contour widgets, or a map overview) are skipped, as are settings that do not fit the profile
(e.g. a field that it does not contain; a warning is logged).

# Arguments
- `session`: as for [`gui_settings`](@ref); the same fields are read (and written).
- `settings`: a `Dict` as returned by [`gui_settings`](@ref), e.g. from a state file.

Returns `session`. The topography of the map overview is loaded again from its file (if the
session has a `topomap` and the file still exists).
"""
function apply_settings!(session, settings)
    get_setting(key) = get(settings, key, nothing)

    volume = _part(session, :volume)
    if volume !== nothing
        w = volume.widgets
        field = get_setting("volume_field")
        field === nothing || select_label!(w.volume_menu, field) ||
            @warn "Volume field $field not found, keeping the default"
        select_label!(w.volume_cmap_menu, get_setting("volume_cmap"))
        get_setting("volume_cmap_reverse") isa Bool && (w.volume_cmap_reverse.checked[] = get_setting("volume_cmap_reverse"))
        set_limits!(w.volume_cbar_slider, get_setting("volume_limits"))
        if volume.contours
            field = get_setting("contour_field")
            field === nothing || select_label!(w.volume_contour_menu, field) ||
                @warn "Contour field $field not found, keeping the default"
            select_label!(w.volume_contour_cmap_menu, get_setting("contour_cmap"))
            get_setting("contour_cmap_reverse") isa Bool && (w.volume_contour_cmap_reverse.checked[] = get_setting("contour_cmap_reverse"))
            set_limits!(w.volume_contour_cbar_slider, get_setting("contour_limits"))
            get_setting("contour_levels") isa AbstractString && set_text!(w.volume_contour_levels, get_setting("contour_levels"))
            get_setting("contour_visible") isa Bool && (w.volume_contour_toggle.active[] = get_setting("contour_visible"))
        end
    end

    for (key, part) in (("surface_visible", :surface), ("point_visible", :points))
        state = _part(session, part)
        visible = get_setting(key)
        (state === nothing || !(visible isa AbstractDict)) && continue
        for (label, toggle) in zip(state.labels, state.toggles)
            haskey(visible, label) && (toggle.active[] = visible[label])
        end
    end

    # the topography of the map overview, loaded again from its file
    topomap = _part(session, :topomap)
    topography_path = get_setting("topography_path")
    if topomap !== nothing && topography_path isa AbstractString && !isempty(topography_path) &&
       topography_path != topomap.path[]
        if isfile(topography_path)
            @info "Loading topography $topography_path ..."
            load_topography!(topomap, topography_path)
        else
            @warn "The topography file of this state does not exist (any more): $topography_path"
        end
    end

    topography = _part(session, :topography)
    topography === nothing || _apply_topography_settings!(topography, get_setting("topography_controls"))

    expanded = get_setting("expanded_panels")
    if expanded isa AbstractDict
        # collapse first, then expand: expanding one panel collapses the others
        for want in (false, true), (name, value) in expanded
            toggle = _widget(session, Symbol(name, "_panel_toggle"))
            value == want && toggle !== nothing && (toggle.active[] = value)
        end
    end
    pick_name = _widget(session, :pick_name)
    pick_name !== nothing && get_setting("user_name") isa AbstractString && set_text!(pick_name, get_setting("user_name"))

    # picks: loading the profile has removed those of the previous profile
    picking = _part(session, :picking)
    saved = get_setting("picks")
    if picking !== nothing && saved isa AbstractDict
        set_pick_points!(picking, points(_picks_from_columns(saved)))
    end
    compare = _part(session, :compare)
    saved = get_setting("compare_picks")
    if compare !== nothing && saved isa AbstractVector
        clear_compare_picks!(compare)
        for entry in saved
            add_compare_picks!(compare, _picks_from_columns(entry), entry["label"];
                               other_profile = get(entry, "other_profile", false),
                               horizontal = !is_vertical(session.profile[]))
            push!(compare.paths, get(entry, "path", ""))
            compare.toggles[end].active[] = get(entry, "visible", true)
        end
    end
    if compare !== nothing && compare.compare_toggle !== nothing && get_setting("compare_visible") isa Bool
        compare.compare_toggle.active[] = get_setting("compare_visible")
    end
    return session
end

# extension of the state files written by `save_gui_state` (the content is a JLD2 file)
const STATE_EXTENSION = ".aagps"
# file filters of the state dialogs of the menu, in NativeFileDialog syntax: new state files,
# and for loading also the `.jld2` state files of MakiePickerGUI.jl
const STATE_SAVE_FILTER = "aagps"
const STATE_OPEN_FILTER = "aagps,jld2"
# "format" entry of the state files written by `save_gui_state`
const STATE_FORMAT = "AdriaArrayGeometryPicker state"
# formats accepted by `load_gui_state!`: also the state files of MakiePickerGUI.jl (the package
# this one is derived from), which have the same layout
const STATE_FORMATS = (STATE_FORMAT, "MakiePickerGUI state")

"""
    save_gui_state(path, session) -> Union{String,Nothing}

Save the state of the GUI to the file `path` (`.aagps` is appended if there is no extension;
the content is a JLD2 file, written with `jldopen`, which accepts any extension): the path of the loaded profile file and the settings (see [`gui_settings`](@ref)).
The profile data itself is not stored, it is loaded again from its file by
[`load_gui_state!`](@ref). Requires a GeophysicalModelGenerator `ProfileData` to be loaded.

# Arguments
- `path`: output file.
- `session`: as for [`gui_settings`](@ref), plus the field `profile_path` (an
  `Observable{String}` with the path of the loaded profile file, set by
  [`open_profile!`](@ref)).

Returns the path written, or `nothing` (and warns) if no profile file is known
(`session.profile_path[]` is empty, e.g. because the profile was loaded with
[`load_profile!`](@ref) instead of [`open_profile!`](@ref)).
"""
function save_gui_state(path::AbstractString, session)
    if isempty(session.profile_path[])
        @warn "No profile loaded, there is no state to save"
        return nothing
    end
    path = isempty(splitext(path)[2]) ? string(path, STATE_EXTENSION) : String(path)
    settings = gui_settings(session)
    jldopen(path, "w") do file
        file["format"] = STATE_FORMAT
        file["version"] = 1
        file["profile_path"] = session.profile_path[]
        file["settings"] = settings
    end
    return path
end

"""
    load_gui_state!(session, path) -> Union{typeof(session),Nothing}

Restore a GUI state saved by [`save_gui_state`](@ref): load the profile file it refers to
with [`open_profile!`](@ref) and apply the saved settings with [`apply_settings!`](@ref) (only
the parts that the session has). Requires a GeophysicalModelGenerator `ProfileData` file.

# Arguments
- `session`: as for [`gui_settings`](@ref); `profile` is required, `profile_file` and
  `profile_path` are set if present (see [`open_profile!`](@ref)).
- `path`: a file written by [`save_gui_state`](@ref) (`.aagps`; or a `.jld2` state file of
  MakiePickerGUI.jl, format `"MakiePickerGUI state"`). The file is recognised by its content,
  not by its extension.

Returns `session`; nothing is changed (and `nothing` is returned) if the profile file no
longer exists. Throws an error if `path` is not a state file.
"""
function load_gui_state!(session, path::AbstractString)
    # `jldopen` instead of `JLD2.load`: works with any extension (`.aagps`)
    state = try
        jldopen(file -> Dict{String,Any}(k => file[k] for k in keys(file)), path, "r")
    catch
        error("$path is not an AdriaArrayGeometryPicker state file")
    end
    get(state, "format", nothing) in STATE_FORMATS ||
        error("$path is not an AdriaArrayGeometryPicker state file")
    profile_path = state["profile_path"]
    if !isfile(profile_path)
        @error "The profile file of this state does not exist (any more): $profile_path"
        return nothing
    end
    @info "Loading $profile_path ..."
    open_profile!(session, profile_path)
    apply_settings!(session, state["settings"])
    @info "State loaded from $path"
    return session
end
