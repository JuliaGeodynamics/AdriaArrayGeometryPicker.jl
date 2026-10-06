# Render the screenshots of the picker window used in the manual (docs/src/assets/*.png).
# They are committed to the repository, so the documentation can be built without OpenGL.
# Re-run this script after changes of the window layout:
#
#     julia --project=docs docs/screenshots.jl

using AdriaArrayGeometryPicker
using AdriaArrayGeometryPicker: set_pick_points!, set_text!, load_compare_picks!, select_label!,
                                load_topography!
import GLMakie
const Makie = GLMakie.Makie

const PROFILE = joinpath(pkgdir(AdriaArrayGeometryPicker), "assets", "Profile1.pgmg")
const OUT = mkpath(joinpath(@__DIR__, "src", "assets"))
# a horizontal slice and a topography for the map overview are not part of this package; they
# are used if the GeometryPicker repository is next to this one
const GEOMETRYPICKER = joinpath(dirname(pkgdir(AdriaArrayGeometryPicker)), "GeometryPicker", "assets")
const HORIZONTAL = joinpath(GEOMETRYPICKER, "Profile_horizontal.pgmg")
const ETOPO = joinpath(GEOMETRYPICKER, "etopo1.jld2")
const PICKS = [(60.0, -35.0), (180.0, -45.0), (300.0, -80.0), (420.0, -140.0), (520.0, -210.0)]
const OTHER = [(60.0, -40.0), (200.0, -55.0), (330.0, -95.0), (450.0, -160.0), (540.0, -230.0)]

# render the current state of the offscreen window of `session` into `name`; `panel = true`
# keeps only the left column with the data panels (as a fraction of the window size)
function shot(session, name; panel = false)
    sleep(1.5)                           # let the animations (e.g. of toggles) finish
    GLMakie.colorbuffer(session.screen)
    sleep(0.5)
    path = joinpath(OUT, name)
    img = GLMakie.colorbuffer(session.screen)
    if panel
        h, w = size(img)
        img = img[round(Int, 0.09h):round(Int, 0.84h), 1:round(Int, 0.335w)]
        # cut the empty background below the panels
        background = img[end, end]
        last_row = something(findlast(r -> any(!=(background), view(img, r, :)), axes(img, 1)), size(img, 1))
        img = img[1:min(last_row + 20, size(img, 1)), :]
    end
    Makie.save(path, img)
    @info "Wrote $path"
end

tmp = mktempdir()

# empty window
geometry_picker(; save = joinpath(OUT, "window_empty.png"))
GLMakie.closeall()

# a profile right after loading
session = geometry_picker(PROFILE; save = joinpath(OUT, "window_profile.png"))

# volume data panel with another colormap and contour levels
select_label!(session.widgets.volume_cmap_menu, "roma")
set_text!(session.widgets.volume_contour_levels, "-4, -2, 0, 2, 4")
shot(session, "panel_volume.png"; panel = true)
select_label!(session.widgets.volume_cmap_menu, "viridis")
set_text!(session.widgets.volume_contour_levels, "")

# picks of another user, shown for comparison
other = Picks(OTHER; names = (:x, :depth),
              metadata = Dict("user" => "AB", "profile_type" => "vertical",
                              "start_lonlat" => session.profile[].start_lonlat,
                              "end_lonlat" => session.profile[].end_lonlat))
other_file = save_picks(joinpath(tmp, "picks_AB.aagpp"), other)

# picking: picks, user name, picking switched on, point data panel expanded
session.widgets.pick_toggle.active[] = true
set_text!(session.widgets.pick_name, "MT")
set_pick_points!(session.picking, PICKS)
session.widgets.point_panel_toggle.active[] = true
shot(session, "window_picks.png")

# compare picks
load_compare_picks!(session, other_file)
session.widgets.compare_panel_toggle.active[] = true
shot(session, "window_compare.png")
shot(session, "panel_compare.png"; panel = true)

# topography panel
session.widgets.topography_panel_toggle.active[] = true
shot(session, "panel_topography.png"; panel = true)

# surface data panel
session.widgets.surface_panel_toggle.active[] = true
shot(session, "panel_surface.png"; panel = true)

# point data panel
session.widgets.point_panel_toggle.active[] = true
shot(session, "panel_points.png"; panel = true)

# map overview
session.widgets.map_panel_toggle.active[] = true
isfile(ETOPO) && load_topography!(session.topomap, ETOPO)
shot(session, "panel_map.png"; panel = true)
GLMakie.closeall()

# horizontal slice
if isfile(HORIZONTAL)
    session = geometry_picker(HORIZONTAL; save = joinpath(OUT, "window_horizontal.png"))
    session.widgets.topography_panel_toggle.active[] = true
    shot(session, "panel_topography_horizontal.png"; panel = true)
    GLMakie.closeall()
else
    @warn "$HORIZONTAL not found, no screenshots of a horizontal slice"
end
