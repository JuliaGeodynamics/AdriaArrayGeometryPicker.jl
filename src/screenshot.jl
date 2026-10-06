# Screenshots of a figure (or of any Makie scene / block)

"""
    save_screenshot(path, fig; px_per_unit = 2, kwargs...) -> String

Save `fig` as an image and return the path written. A path without extension gets `.png`
appended. Generic: works for any Makie `Figure` (or scene).

# Arguments
- `path`: output file; the format follows the extension (e.g. `.png`).
- `fig`: the figure to save.

# Keywords
- `px_per_unit`: resolution scaling, 2 by default (twice the window resolution).
- `kwargs...`: passed to `Makie.save`.

# Example
```julia
fig = Figure()
lines(fig[1, 1], 1:10)
save_screenshot(joinpath(tempdir(), "window.png"), fig)
```
"""
function save_screenshot(path::AbstractString, fig; px_per_unit = 2, kwargs...)
    path = isempty(splitext(path)[2]) ? string(path, ".png") : String(path)
    Makie.save(path, fig; px_per_unit, kwargs...)
    return path
end

"""
    save_screenshot_dialog(fig; filter = "png", dir = "", kwargs...) -> Task

Ask for a file name and save a screenshot of `fig` there (see [`save_screenshot`](@ref)).
Generic. Keywords `filter` and `dir` are as for [`open_dialog`](@ref); the remaining
`kwargs...` are passed to `save_screenshot`. Returns the `Task` of [`with_save_dialog`](@ref).
"""
function save_screenshot_dialog(fig; filter::AbstractString = IMAGE_FILTER, dir::AbstractString = "", kwargs...)
    return with_save_dialog(; filter, dir) do path
        saved = save_screenshot(path, fig; kwargs...)
        @info "Screenshot saved to $saved"
        return saved
    end
end
