"""
    menu_selection(menu::Menu, session) -> ObserverFunction

Connect the entries of the dropdown `menu` (`widgets.menu` of [`picker_layout`](@ref), or a
`Menu` of your own with some of these entries) to their actions. Requires a
GeophysicalModelGenerator profile GUI.

Each entry reads only the fields of `session` it needs. If a field is missing, choosing the
entry logs a warning that names it and does nothing else; so a custom GUI can use the menu with
the parts it has. Unknown entries are ignored.

| entry | action | session fields |
|:--|:--|:--|
| "Load Profile" | choose a `.pgmg` file and load it (see [`open_profile!`](@ref)) | `profile`; optional `profile_file`, `profile_path` |
| "Save State" | save the path of the loaded profile and the settings of the GUI to a `.aagps` file (a JLD2 file, see [`save_gui_state`](@ref)) | `profile`, `profile_path`; the parts listed in [`gui_settings`](@ref) |
| "Load State" | restore them from a `.aagps` file (or a `.jld2` state file of MakiePickerGUI.jl; see [`load_gui_state!`](@ref)) | as "Save State" |
| "Save Picks" | save the picks to a `.aagpp` (JLD2) or `.csv` file (see [`current_picks`](@ref)) | `profile`, `picking`; optional `profile_file`, `widgets.pick_name` |
| "Load Picks" | load picks (editable) from a file if they belong to the loaded profile (see [`set_picks!`](@ref)) | as "Save Picks" |
| "Load Compare Picks" | show the picks of a file (e.g. of another user) as a dashed line for comparison, not editable (see [`load_compare_picks!`](@ref)) | `profile`, `compare` |
| "Save Screenshot" | choose a file name and save an image of the whole window (see [`save_screenshot_dialog`](@ref)) | `fig` |
| "Close" | close the window | `fig` |

The session of the ready-made picker has all of them (see the example below).

Dialogs run in a background task, so the window keeps rendering while they are open; errors
are logged and the GUI keeps running.

# Arguments
- `menu`: the `Menu`; create it with `default = nothing`, so that no entry is preselected.
- `session`: a `NamedTuple` (or any object with these properties) with the fields above.

Returns the listener, which can be removed with `off`.

# Example
```julia
profile = Observable{Any}(nothing)
profile_file = Observable("")
profile_path = Observable("")
fig, panels, axis, widgets = picker_layout(; profile)
states = on_profile_loaded(profile, profile_file, axis, panels, widgets)
picking = picking_state(fig, profile, axis, widgets)
session = (; fig, profile, profile_file, profile_path, panels, axes = axis, widgets, picking, states...)
menu_selection(widgets.menu, session)
```
"""
function menu_selection(menu::Menu, session)
    # whether the session has the fields an entry needs; warns otherwise
    function has(entry, keys...)
        missing_keys = [k for k in keys if !hasproperty(session, k)]
        isempty(missing_keys) && return true
        @warn "Menu entry \"$entry\" needs the session field(s) $(join(missing_keys, ", ")), which this GUI does not have"
        return false
    end
    return on(menu.selection) do entry
        entry === nothing && return
        # Menu only reacts to a *changed* selection: reset it, so that the same entry
        # can be chosen again and the menu shows its prompt
        menu.i_selected[] = 0

        if entry == "Load Profile"
            has(entry, :profile) || return
            with_open_dialog(; filter = "pgmg") do path
                @info "Loading $path ..."
                data = open_profile!(session, path)
                if is_vertical(data)
                    @info "Loaded profile from $(round.(data.start_lonlat; digits=2)) to $(round.(data.end_lonlat; digits=2))"
                else
                    @info "Loaded horizontal slice at depth $(slice_depth(data))"
                end
            end
        elseif entry == "Save State"
            has(entry, :profile, :profile_path) || return
            with_save_dialog(; filter = STATE_SAVE_FILTER) do path
                saved = save_gui_state(path, session)
                saved === nothing || @info "GUI state saved to $saved"
            end
        elseif entry == "Load State"
            has(entry, :profile) || return
            with_open_dialog(; filter = STATE_OPEN_FILTER) do path
                load_gui_state!(session, path)
            end
        elseif entry == "Save Picks"
            has(entry, :profile, :picking) || return
            save_picks_dialog() do
                p = current_picks(session)
                _set_pick_warning!(session, "")   # saved picks belong to the current profile
                return p
            end
        elseif entry == "Load Picks"
            has(entry, :profile, :picking) || return
            load_picks_dialog(p -> set_picks!(session, p))
        elseif entry == "Load Compare Picks"
            has(entry, :profile, :compare) || return
            with_open_dialog(; filter = PICKS_LOAD_FILTER) do path
                load_compare_picks!(session, path)
            end
        elseif entry == "Save Screenshot"
            has(entry, :fig) || return
            save_screenshot_dialog(session.fig)
        elseif entry == "Close"
            has(entry, :fig) || return
            screen = Makie.getscreen(session.fig.scene)
            screen === nothing || close(screen)
        end
    end
end
