# Creates a small synthetic vertical profile with GeophysicalModelGenerator, containing
# the same kind of data the GUI expects: volume data (tomographies), surface data
# (topography + Moho) and point data (seismicity)
using GeophysicalModelGenerator, JLD2

const START_LONLAT = (11.0, 45.0)
const END_LONLAT   = (19.0, 45.0)

function create_synthetic_profile(; npoints = 200)
    # volume data
    lon, lat, z = lonlatdepth_grid(10:0.5:20, 40:0.5:50, -300:10:0)
    dVs = @. 0.5 * sin(lon / 2) * cos(z / 50)
    dVp = @. 2 * dVs
    Vol = GeoData(lon, lat, z, (dVs = dVs, dVp = dVp))

    # surface data
    lon2, lat2, z2 = lonlatdepth_grid(10:0.5:20, 40:0.5:50, 0)
    topo = @. 1.0 * sin(lon2)
    moho = @. -35 + 3 * cos(lat2)
    Topo = GeoData(lon2, lat2, z2 .+ topo, (Topography = topo * km,))
    Moho = GeoData(lon2, lat2, z2 .+ moho, (MohoDepth = moho * km,))

    # point data, located close to the profile
    elon = collect(range(10.5, 19.5, length = npoints))
    elat = 45.0 .+ 0.2 .* sin.(1:npoints)
    ez   = -100.0 .* (0.5 .+ 0.5 .* cos.(1:npoints))
    Seis = GeoData(elon, elat, ez, (Magnitude = 3.0 .+ sin.(1:npoints),))

    Profile = ProfileData(start_lonlat = START_LONLAT, end_lonlat = END_LONLAT)
    extract_ProfileData!(Profile, Vol, (Topography = Topo, Moho = Moho), (Seismicity = Seis,);
        DimsVolCross = (50, 40), Depth_extent = (-300, 0))

    return Profile
end

# the GUI loads the variable `Profile` from the jld2 file
function save_synthetic_profile(filename)
    jldsave(filename; Profile = create_synthetic_profile())
    return filename
end
