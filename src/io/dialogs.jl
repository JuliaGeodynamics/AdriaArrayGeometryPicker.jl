# Native file dialogs.
#
# Native dialogs block the thread they run on. When called from a GUI callback they are run
# in a spawned task, so the GLMakie window keeps rendering while the dialog is open.
#
# The dialog implementations are stored in Refs so that they can be replaced, e.g. in tests
# (there is no user to click on CI) or to use a different dialog package:
#
#     AdriaArrayGeometryPicker.OPEN_DIALOG[] = (; kwargs...) -> "picks.aagpp"

"File filter for pick files, in NativeFileDialog syntax."
const PICKS_FILTER = "aagpp,csv"
# for opening: also the .jld2 pick files of older versions
const PICKS_LOAD_FILTER = "aagpp,jld2,csv"
"File filter for screenshots, in NativeFileDialog syntax."
const IMAGE_FILTER = "png"

_native_open(; filter = "", dir = "") = NativeFileDialog.pick_file(dir; filterlist = filter)
_native_save(; filter = "", dir = "") = NativeFileDialog.save_file(dir; filterlist = filter)

"Function `(; filter, dir) -> path` used by [`open_dialog`](@ref). Return `\"\"` or `nothing` on cancel."
const OPEN_DIALOG = Ref{Function}(_native_open)
"Function `(; filter, dir) -> path` used by [`save_dialog`](@ref). Return `\"\"` or `nothing` on cancel."
const SAVE_DIALOG = Ref{Function}(_native_save)

_dialog_result(path) = (path === nothing || isempty(path)) ? nothing : String(path)

"""
    open_dialog(; filter = "", dir = "") -> Union{String,Nothing}

Show a native "open file" dialog and return the chosen path, or `nothing` if cancelled.
Generic, independent of any profile data.

# Keywords
- `filter`: file filter in NativeFileDialog syntax, e.g. `"aagpp,csv"` or `"png;jpg,jpeg"`.
- `dir`: directory the dialog starts in (default: the dialog's own choice).

This call blocks; inside GUI callbacks use [`with_open_dialog`](@ref). The dialog can be
replaced (e.g. in tests) by setting `AdriaArrayGeometryPicker.OPEN_DIALOG[]`.
"""
open_dialog(; filter::AbstractString = "", dir::AbstractString = "") = _dialog_result(OPEN_DIALOG[](; filter, dir))

"""
    save_dialog(; filter = "", dir = "") -> Union{String,Nothing}

Show a native "save file" dialog and return the chosen path, or `nothing` if cancelled.
Keywords as for [`open_dialog`](@ref). Generic, independent of any profile data.
This call blocks; inside GUI callbacks use [`with_save_dialog`](@ref).
"""
save_dialog(; filter::AbstractString = "", dir::AbstractString = "") = _dialog_result(SAVE_DIALOG[](; filter, dir))

"""
    with_open_dialog(f; filter = "", dir = "") -> Task

Show an "open file" dialog without blocking the GUI and call `f(path)` with the chosen path.
Nothing happens if the dialog is cancelled. Errors thrown by `f` are logged, not rethrown.
The task's result is the return value of `f` (or `nothing`). Keywords as for
[`open_dialog`](@ref). Generic.

# Example
```julia
with_open_dialog(path -> @info("chosen: \$path"); filter = "csv")
```
"""
with_open_dialog(f; kwargs...) = @async _run_dialog(f, open_dialog; kwargs...)

"""
    with_save_dialog(f; filter = "", dir = "") -> Task

Show a "save file" dialog without blocking the GUI and call `f(path)` with the chosen path.
Keywords as for [`open_dialog`](@ref); see [`with_open_dialog`](@ref). Generic.
"""
with_save_dialog(f; kwargs...) = @async _run_dialog(f, save_dialog; kwargs...)

function _run_dialog(f, dialog; kwargs...)
    try
        path = fetch(Threads.@spawn dialog(; kwargs...))
        path === nothing && return nothing
        return f(path)
    catch err
        err isa TaskFailedException && (err = err.task.exception)
        @error "File dialog action failed" exception = (err, catch_backtrace())
        return nothing
    end
end

# `picks` may be given as a zero-argument function, so that the GUI state at the moment the
# dialog is closed gets saved
_current(x::Function) = x()
_current(x) = x

"""
    save_picks_dialog(picks; extra = nothing, filter = "aagpp,csv", dir = "") -> Task

Ask for a file name and save `picks` there (see [`save_picks`](@ref)). `picks` can be a
[`Picks`](@ref), a vector of points, or a zero-argument function returning either (evaluated
when the dialog is closed, so the state at that moment is saved). Generic.

# Arguments
- `picks`: what to save, see above.

# Keywords
- `extra`: function `points -> NamedTuple` computing additional columns, see [`save_picks`](@ref).
- `filter`, `dir`: as for [`open_dialog`](@ref).

Returns the `Task` of [`with_save_dialog`](@ref); its result is the path written.
"""
function save_picks_dialog(picks; extra = nothing, filter::AbstractString = PICKS_FILTER, dir::AbstractString = "")
    return with_save_dialog(; filter, dir) do path
        saved = save_picks(path, _current(picks); extra)
        @info "Picks saved to $saved"
        return saved
    end
end

"""
    load_picks_dialog(f = identity; filter = "aagpp,jld2,csv", dir = "") -> Task

Ask for a pick file, load it with [`load_picks`](@ref) and call `f(picks)` with the
resulting [`Picks`](@ref). Generic.

# Arguments
- `f`: function called with the loaded picks (default `identity`).

# Keywords
- `filter`, `dir`: as for [`open_dialog`](@ref).

Returns the `Task` of [`with_open_dialog`](@ref); its result is the return value of `f`.

# Example
```julia
load_picks_dialog(p -> println(length(p), " picks loaded"))
```
"""
function load_picks_dialog(f = identity; filter::AbstractString = PICKS_LOAD_FILTER, dir::AbstractString = "")
    return with_open_dialog(; filter, dir) do path
        p = load_picks(path)
        @info "Loaded $(length(p)) picks from $path"
        return f(p)
    end
end
