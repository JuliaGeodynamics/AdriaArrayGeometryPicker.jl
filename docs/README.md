# Building the documentation

The documentation is built with [Documenter.jl](https://documenter.juliadocs.org) and
[DocumenterVitepress.jl](https://luxdl.github.io/DocumenterVitepress.jl/stable/). The source is
in `docs/src`, the build is configured in `docs/make.jl`.

## Requirements

- Julia (the version of the package)
- [Node.js](https://nodejs.org) 22 or newer, with `npm`
- an internet connection for the first build (npm packages of VitePress)

## Build

Run all commands in the `docs` folder.

```
cd docs

# once: install the Julia and npm dependencies
julia --startup-file=no --project=. -e "using Pkg; Pkg.instantiate()"
npm install

# every time: build the documentation
julia --startup-file=no --project=. make.jl     # converts the pages to Markdown for VitePress
npm run docs:build                              # builds the HTML site into docs/build/1
```

`--startup-file=no` keeps a personal `~/.julia/config/startup.jl` from activating another
project. On Linux and macOS `julia make.jl` also runs the npm build itself; on Windows
`npm run docs:build` is always needed as a second step.

The screenshots in `docs/src/assets` are made by `docs/screenshots.jl` and are committed, so
building the documentation needs no OpenGL. Run `docs/screenshots.jl` only if the window
changed.

## View

The built site cannot be opened by double-clicking the HTML files; it has to be served:

```
npm run docs:dev        # live preview of the sources, opens http://localhost:5173
npm run docs:preview    # serves the built site (after npm run docs:build)
```

`docs:dev` is the more convenient one while writing: after changing a Markdown file in
`docs/src`, run `julia --startup-file=no --project=. make.jl` again and the page updates.
Stop the server with `Ctrl + C`.

## Customizing

- Pages and their order: `pages` in `docs/make.jl`.
- Style: `docs/src/.vitepress/theme/style.css` (also holds the size of the panel screenshots).
- Repository and deployment: `repo`, `devbranch` and `deploydocs` in `docs/make.jl`. Deployment
  only runs on CI (e.g. a GitHub Actions workflow that runs `docs/make.jl`); locally it is
  skipped with a warning.

## Troubleshooting

- `Package Documenter not found`: the wrong project is active; use `--project=.` in the `docs`
  folder together with `--startup-file=no`.
- `Did not find docs/package.json` or missing `vitepress`: run `npm install` in `docs`.
- Warnings about a missing `favicon.ico` or about deployment are harmless for a local build.
- Generated folders (`docs/build`, `docs/node_modules`) are not committed.
