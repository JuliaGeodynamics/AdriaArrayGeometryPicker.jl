# this is picks_io.jl
# It contains functions to convert, save and load picks. They don't depend on the GUI.
#
# Picks are saved as jld2 files, which contain:
#   picks:        named tuple with x, depth, lat and lon of each pick
#   pick_info:    name of the user who created the picks, date of creation and units
#   profile_info: start and end lonlat of the profile

# the z-value of the picks, which ensures that they are always plotted on top
const PICK_Z = 1000

"""
    pick_table(picks, profile)

Converts the picked points into a named tuple with `x`, `depth`, `lat` and `lon` of each
pick. The lat and lon of the picks are interpolated from the start and end points of the profile.
"""
function pick_table(picks, profile)
    xtmp   = [minimum(profile.VolData.fields.x_profile), maximum(profile.VolData.fields.x_profile)]
    lontmp = [profile.start_lonlat[1], profile.end_lonlat[1]]
    lattmp = [profile.start_lonlat[2], profile.end_lonlat[2]]

    interp_linear_lon = linear_interpolation(xtmp, lontmp)
    interp_linear_lat = linear_interpolation(xtmp, lattmp)

    x_pick = [pick[1] for pick in picks]
    y_pick = [pick[2] for pick in picks]

    return (x = x_pick, depth = y_pick, lat = interp_linear_lat(x_pick), lon = interp_linear_lon(x_pick))
end

"""
    save_picks(filename, pick_data, profile; user_name = nothing)

Saves the picks `pick_data` (see `pick_table`) that belong to `profile`. Picks can only be
saved as jld2 files for now. Returns `true` if the file was written.
"""
function save_picks(filename, pick_data, profile; user_name = nothing)
    filetype = file_extension(filename)
    if filetype == "jld2"
        pick_info    = (user_name = user_name, date = now(), units = (x = "km", depth = "km", lat = "deg", lon = "deg"))
        profile_info = (start_lonlat = profile.start_lonlat, end_lonlat = profile.end_lonlat)
        jldsave(filename; picks = pick_data, pick_info = pick_info, profile_info = profile_info)
        println("... " * filename * " saved")
        return true
    elseif filetype == "csv"
        println("Saving as csv is not implemented yet")
    else
        println("This is not a valid pick file format. Picks should be saved as jld2 files.")
    end
    return false
end

"""
    load_picks(filename)

Loads a pick file created with `save_picks`. Returns `nothing` if this is not a valid pick file.
"""
function load_picks(filename)
    filetype = file_extension(filename)
    if filetype == "jld2"
        data_picks = load(filename)
        println(filename * " loaded")
        return data_picks
    else
        # csv files are not implemented yet
        println("This is not a valid pick file at the moment. Feel free to add this functionality :)")
        return nothing
    end
end

"""
    pick_points(pick_data; z = PICK_Z)

Converts loaded picks (a named tuple with `x` and `depth`) into points that can be plotted and modified.
"""
pick_points(pick_data; z = PICK_Z) = [Point3f(x, depth, z) for (x, depth) in zip(pick_data.x, pick_data.depth)]

"""
    picks_belong_to_profile(data_picks, profile)

Checks if the loaded picks were created on `profile`, by comparing the start and end points.
"""
function picks_belong_to_profile(data_picks, profile)
    info = data_picks["profile_info"]
    return info.start_lonlat == profile.start_lonlat && info.end_lonlat == profile.end_lonlat
end

# everything after the last dot in the filename
file_extension(filename) = split(filename, ".")[end]
