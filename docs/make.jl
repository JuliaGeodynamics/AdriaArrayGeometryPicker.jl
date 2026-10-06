# Build the documentation:
#
#     julia --project=docs -e "using Pkg; Pkg.instantiate()"    # once
#     julia --project=docs docs/make.jl
#
# The HTML pages are written to docs/build (open docs/build/index.html). The screenshots in
# docs/src/assets are made by docs/screenshots.jl and committed, so building the documentation
# needs no OpenGL.

using Documenter
using AdriaArrayGeometryPicker

DocMeta.setdocmeta!(AdriaArrayGeometryPicker, :DocTestSetup,
                    :(using AdriaArrayGeometryPicker; using AdriaArrayGeometryPicker: columns, metadata);
                    recursive = true)

makedocs(;
    sitename = "AdriaArrayGeometryPicker.jl",
    authors = "Marcel Thielmann",
    modules = [AdriaArrayGeometryPicker],
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        assets = ["assets/custom.css"],
        edit_link = nothing,
        repolink = nothing,
        size_threshold_warn = 200 * 1024,
        size_threshold = 400 * 1024,
    ),
    pages = [
        "Home" => "index.md",
        "Picker manual" => [
            "Getting started" => "manual/getting_started.md",
            "The window" => "manual/window.md",
            "Data panels" => "manual/panels.md",
            "Picking" => "manual/picking.md",
            "Files: picks, states, screenshots" => "manual/files.md",
            "Comparing picks" => "manual/compare.md",
            "Horizontal slices" => "manual/horizontal.md",
            "Using the picker from the REPL" => "manual/scripting.md",
            "Troubleshooting" => "manual/troubleshooting.md",
        ],
        "File formats" => "formats.md",
        "API reference" => [
            "Public API" => "api/public.md",
            "Building blocks" => "api/internals.md",
        ],
    ],
    checkdocs = :all,
    # no source links while the repository has no remote; remove once it has one
    remotes = nothing,
)

# Deploy to GitHub Pages once the repository has a remote, e.g.
# deploydocs(; repo = "github.com/<user>/AdriaArrayGeometryPicker.jl.git", devbranch = "main")
