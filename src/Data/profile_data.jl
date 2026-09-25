# this is profile_data.jl
# It contains functions that extract the data to plot from a GMG ProfileData structure.
# They don't depend on the GUI, so they can be reused (and tested) independently.
# IMPORTANT: FOR NOW, ONLY VERTICAL PROFILES WORK

# fields that GMG adds to the volume data of a profile, which are not data to plot
const PROFILE_HELPER_FIELDS = (:x_profile, :FlatCrossSection)

"""
    volume_field_names(profile)

Names of the volume data fields (tomographies etc.) of `profile` that can be plotted.
"""
volume_field_names(profile) = [name for name in keys(profile.VolData.fields) if name ∉ PROFILE_HELPER_FIELDS]

"""
    surface_names(profile)

Names of the surface data sets (Moho etc.) that intersect the profile. The topography is
not included, as it is plotted separately.
"""
function surface_names(profile)
    isnothing(profile.SurfData) && return Symbol[]
    names = [name for name in keys(profile.SurfData) if name != :Topography]
    # remove all datasets that only contain NaN values, this means that this surface does not intersect with the profile
    return filter(name -> !all(isnan, profile.SurfData[name].depth.val), names)
end

"""
    point_names(profile)

Names of the point data sets (seismicity etc.) that contain points close to the profile.
"""
function point_names(profile)
    isnothing(profile.PointData) && return Symbol[]
    return [name for name in keys(profile.PointData) if !isempty(profile.PointData[name].fields)]
end

"""
    x, y = topography(profile)

Topography along the profile. Both `x` (distance along the profile) and `y` are in km.
"""
function topography(profile)
    topo = profile.SurfData.Topography.fields
    return topo.x_profile, Vector(ustrip.(topo.Topography))
end

"""
    x, y = profile_grid(profile)

Coordinates of the (regular) grid of the volume data: distance along the profile and depth, in km.
"""
function profile_grid(profile)
    x = profile.VolData.fields.x_profile[:, 1, 1]
    y = profile.VolData.depth.val[1, :, 1]
    return x, y
end

"""
    volume_slice(profile, name)

2D matrix (without units) of the volume data field `name`, to be plotted as heatmap.
"""
volume_slice(profile, name) = ustrip.(profile.VolData.fields[Symbol(name)][:, :, 1])

"""
    x, y = surface_line(profile, name)

Distance along the profile and depth of the surface data set `name`.
"""
function surface_line(profile, name)
    surf = profile.SurfData[name]
    return surf.fields.x_profile, surf.depth.val
end

"""
    x, y = point_coordinates(profile, name)

Distance along the profile and depth of the points of point data set `name`, projected on the profile.
"""
function point_coordinates(profile, name)
    points = profile.PointData[name]
    return points.fields.x_profile, points.fields.depth_proj
end

"""
    finite_extrema(A)

Minimum and maximum of `A`, ignoring NaN values.
"""
finite_extrema(A) = extrema(filter(!isnan, A))
