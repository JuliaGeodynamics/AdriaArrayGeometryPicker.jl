# Build the documentation with DocumenterVitepress.jl. Run in the docs folder:
#
#     julia --startup-file=no --project=. -e "using Pkg; Pkg.instantiate()"   # once
#     npm install                                                             # once (needs Node.js)
#     julia --startup-file=no --project=. make.jl                             # Markdown for VitePress
#     npm run docs:build                                                      # HTML in docs/build/1
#
# View the site with `npm run docs:dev` (live preview, http://localhost:5173) or, after the build,
# `npm run docs:preview`. Opening the HTML files directly does not work. On Linux / macOS
# `julia make.jl` runs the npm steps itself. The screenshots in docs/src/assets are made by
# docs/screenshots.jl and committed, so building the documentation needs no OpenGL. The style of
# the screenshots is in src/.vitepress/theme/style.css.

using Documenter
using DocumenterVitepress
using AdriaArrayGeometryPicker

DocMeta.setdocmeta!(AdriaArrayGeometryPicker, :DocTestSetup,
                    :(using AdriaArrayGeometryPicker; using AdriaArrayGeometryPicker: columns, metadata);
                    recursive = true)

makedocs(;
    sitename = "AdriaArrayGeometryPicker.jl",
    authors = "Marcel Thielmann",
    modules = [AdriaArrayGeometryPicker],
    format = DocumenterVitepress.MarkdownVitepress(;
        repo = "https://github.com/JuliaGeodynamics/AdriaArrayGeometryPicker.jl",
        devbranch = "main",
        devurl = "dev",
    ),
    pages = [
        "Home" => "index.md",
        "Introduction" => "introduction.md",
        "Picker manual" => [
            "Getting started" => "manual/getting_started.md",
            "The window" => "manual/window.md",
            "Data panels" => "manual/panels.md",
            "Picking" => "manual/picking.md",
            "Files: picks, states, screenshots" => "manual/files.md",
            "Comparing picks" => "manual/compare.md",
            "Horizontal slices" => "manual/horizontal.md",
            # "Using the picker from the REPL" => "manual/scripting.md",   # hidden from the navigation; the page is still built and reachable by its URL
            "Troubleshooting" => "manual/troubleshooting.md",
        ],
        "File formats" => "formats.md",
        "API reference" => [
            "Public API" => "api/public.md",
            "Building blocks" => "api/internals.md",
        ],
    ],
    checkdocs = :all,
)

# Deploy to GitHub Pages (only on CI, e.g. a GitHub Actions workflow that runs this file)
DocumenterVitepress.deploydocs(;
    repo = "github.com/JuliaGeodynamics/AdriaArrayGeometryPicker.jl.git",
    devbranch = "main",
    push_preview = true,
)
