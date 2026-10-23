# Saving and loading picks as JLD2 or CSV files.
#
# JLD2 layout (written by this package):
#   "format"   => "AdriaArrayGeometryPicker.Picks"
#   "version"  => 1
#   "names"    => ["x", "y"]                 coordinate names
#   "picks"    => (x = [...], y = [...], ...) all columns as NamedTuple
#   "metadata" => Dict{String,Any}
#
# CSV layout:
#   # AdriaArrayGeometryPicker.Picks v1
#   # user = MT                              metadata, nested keys joined with '.'
#   # units.x = km
#   x,y,lat,lon                              header row
#   0.0,-10.0,45.1,13.2                      one row per pick

const FORMAT_TAG = "AdriaArrayGeometryPicker.Picks"
# tag of the pick files written by MakiePickerGUI.jl (the package this one is derived from),
# same layout; still accepted by `load_picks`
const LEGACY_FORMAT_TAG = "MakiePickerGUI.Picks"
const FORMAT_VERSION = 1

"""
    save_picks(path, picks; extra = nothing, format = nothing, delim = ',') -> String

Save `picks` (a [`Picks`](@ref) or a vector of points) to `path` and return the path written.

The file format is taken from the extension (`.aagpp`, a JLD2 file, or `.csv`) unless `format`
(`:jld2` or `:csv`) is given. A path without extension gets `.aagpp` appended. `.jld2` is
accepted as well (pick files of older versions).

`extra` is an optional function `points -> NamedTuple` that computes additional columns at
save time, e.g. geographic coordinates of points picked on a profile:

```julia
p = Picks([(0.0, -10.0), (50.0, -35.0)]; names = (:x, :depth))
lon_at(x) = 10 + x / 100          # e.g. an interpolation along the profile
save_picks("picks.csv", p; extra = pts -> (lon = lon_at.(first.(pts)),))
```

CSV files store metadata as text in `#` comment lines, so non-string metadata values come
back as strings from [`load_picks`](@ref). JLD2 files keep all Julia types. Generic.

# Arguments
- `path`: output file.
- `picks`: a [`Picks`](@ref), or a vector of points (which is converted with `Picks(points)`).

# Keywords
- `extra`: function `points -> NamedTuple` that returns additional columns (vectors with one
  value per point), see above.
- `format`: `:jld2` or `:csv` (default: from the extension of `path`).
- `delim`: column delimiter of CSV files.

# Example
Round trip through a JLD2 and a CSV file:

```jldoctest; setup = :(using AdriaArrayGeometryPicker)
julia> p = Picks([(0.0, -10.0), (50.0, -35.0)]; names = (:x, :depth),
                 metadata = Dict("user" => "MT"));

julia> mktempdir() do dir
           [load_picks(save_picks(joinpath(dir, name), p)) == p for name in ("picks.aagpp", "picks.csv")]
       end
2-element Vector{Bool}:
 1
 1
```
"""
function save_picks(path::AbstractString, p::Picks; extra = nothing, format::Union{Nothing,Symbol} = nothing,
                    delim::Char = ',')
    fmt, path = _save_format(path, format)
    p = _with_extra(p, extra)
    if fmt === :jld2
        _save_jld2(path, p)
    else
        _save_csv(path, p, delim)
    end
    return path
end

save_picks(path::AbstractString, pts::AbstractVector; kwargs...) = save_picks(path, Picks(pts); kwargs...)

"""
    load_picks(path; format = nothing, delim = ',') -> Picks

Load picks from a `.aagpp` (JLD2) or `.csv` file; `.jld2` files of older versions are read too.

Supported inputs:
- files written by [`save_picks`](@ref) (also those of MakiePickerGUI.jl)
- pick files of the original AdriaArrayGeometryPicker.jl (JLD2 with `picks`, `pick_info`, `profile_info`);
  `pick_info` entries become metadata (`user_name` is stored as `"user"`), all other entries
  are stored under their own key
- plain CSV files with or without header row; the first two columns are the coordinates

# Arguments
- `path`: the file to read; an `ArgumentError` is thrown if it does not exist.

# Keywords
- `format`: `:jld2` or `:csv` (default: from the extension of `path`).
- `delim`: column delimiter of CSV files.

Returns a [`Picks`](@ref). Generic.

# Example
```jldoctest; setup = :(using AdriaArrayGeometryPicker)
julia> p = Picks([(0.0, -10.0), (50.0, -35.0)]; names = (:x, :depth),
                 columns = (lat = [45.0, 45.5],));

julia> q = mktempdir() do dir
           load_picks(save_picks(joinpath(dir, "picks.csv"), p))
       end
Picks(2 points, names = (:x, :depth), columns = (:lat,))

julia> q == p
true
```
"""
function load_picks(path::AbstractString; format::Union{Nothing,Symbol} = nothing, delim::Char = ',')
    isfile(path) || throw(ArgumentError("file not found: $path"))
    fmt = something(format, _format_from_extension(path))
    fmt === :jld2 && return _load_jld2(path)
    fmt === :csv && return _load_csv(path, delim)
    throw(ArgumentError("cannot determine the file format of $path; pass `format = :jld2` or `format = :csv`"))
end

# ---------------------------------------------------------------------------------------------
# format handling

function _format_from_extension(path)
    ext = lowercase(splitext(path)[2])
    ext in (".aagpp", ".jld2") && return :jld2
    ext == ".csv" && return :csv
    return nothing
end

function _save_format(path, format)
    if format !== nothing
        format in (:jld2, :csv) || throw(ArgumentError("unsupported format `$format`, use :jld2 or :csv"))
        return format, String(path)
    end
    isempty(splitext(path)[2]) && return :jld2, string(path, ".aagpp")
    fmt = _format_from_extension(path)
    fmt === nothing && throw(ArgumentError("unsupported file extension in $path, use .aagpp or .csv"))
    return fmt, String(path)
end

function _with_extra(p::Picks, extra)
    extra === nothing && return p
    cols = extra(points(p))
    cols isa NamedTuple || throw(ArgumentError("`extra` must return a NamedTuple of vectors, got $(typeof(cols))"))
    return Picks(points(p); names = p.names, columns = merge(p.columns, cols), metadata = p.metadata)
end

# build Picks from a table (NamedTuple or Dict of columns)
function _picks_from_table(table, names::NTuple{2,Symbol}, meta::Dict{String,Any})
    t = table isa AbstractDict ? (; (Symbol(k) => v for (k, v) in table)...) : table
    for n in names
        haskey(t, n) || throw(ArgumentError("picks table has no column `$n`; found $(keys(t))"))
    end
    extras = Base.structdiff(t, NamedTuple{names})
    return Picks(collect(Float64, t[names[1]]), collect(Float64, t[names[2]]);
                 names, columns = extras, metadata = meta)
end

# ---------------------------------------------------------------------------------------------
# JLD2

function _save_jld2(path, p::Picks)
    jldsave(path; format = FORMAT_TAG, version = FORMAT_VERSION,
            names = [string(n) for n in p.names], picks = columns(p), metadata = p.metadata)
    return nothing
end

function _load_jld2(path)
    d = JLD2.load(path)
    if get(d, "format", nothing) in (FORMAT_TAG, LEGACY_FORMAT_TAG)
        names = (Symbol(d["names"][1]), Symbol(d["names"][2]))
        return _picks_from_table(d["picks"], names, Dict{String,Any}(d["metadata"]))
    elseif haskey(d, "picks")
        return _load_adriaarray(d)
    end
    throw(ArgumentError("$path contains no picks (expected an entry \"picks\")"))
end

# pick files written by the original AdriaArrayGeometryPicker.jl:
#   picks = (x, depth, lat, lon), pick_info = (user_name, date, units), profile_info = (start_lonlat, end_lonlat)
function _load_adriaarray(d)
    t = d["picks"]
    names = haskey(t, :depth) ? (:x, :depth) : (:x, :y)
    meta = Dict{String,Any}()
    for (k, v) in pairs(get(d, "pick_info", (;)))
        meta[k === :user_name ? "user" : string(k)] = v
    end
    for (k, v) in d
        k in ("picks", "pick_info") || (meta[k] = v)
    end
    return _picks_from_table(t, names, meta)
end

# ---------------------------------------------------------------------------------------------
# CSV

function _save_csv(path, p::Picks, delim)
    open(path, "w") do io
        println(io, "# ", FORMAT_TAG, " v", FORMAT_VERSION)
        for (k, v) in _flatten_metadata(p.metadata)
            println(io, "# ", k, " = ", _csv_text(v))
        end
        t = columns(p)
        println(io, join(string.(keys(t)), delim))
        isempty(p) || writedlm(io, reduce(hcat, values(t)), delim)
    end
    return nothing
end

function _load_csv(path, delim)
    lines = readlines(path)
    meta = Dict{String,Any}()
    i = 1
    # comment block: metadata lines of the form "# key = value"
    while i <= length(lines) && (startswith(lines[i], '#') || isempty(strip(lines[i])))
        s = strip(lstrip(lines[i], '#'))
        r = findfirst(" = ", s)
        r === nothing || _unflatten!(meta, strip(s[1:prevind(s, first(r))]), strip(s[nextind(s, last(r)):end]))
        i += 1
    end
    body = filter(!isempty ∘ strip, lines[i:end])
    isempty(body) && throw(ArgumentError("$path contains no header or data"))

    tokens = strip.(split(body[1], delim))
    if all(t -> tryparse(Float64, t) !== nothing, tokens)   # no header row
        colnames = [Symbol(:x), Symbol(:y), (Symbol("col", j) for j in 3:length(tokens))...]
    else
        colnames = Symbol.(tokens)
        body = body[2:end]
    end
    length(colnames) >= 2 || throw(ArgumentError("$path needs at least two columns"))

    data = isempty(body) ? zeros(0, length(colnames)) : readdlm(IOBuffer(join(body, '\n')), delim, Float64)
    size(data, 2) == length(colnames) ||
        throw(ArgumentError("$path: header has $(length(colnames)) columns but data has $(size(data, 2))"))
    table = NamedTuple{Tuple(colnames)}(Tuple(data[:, j] for j in axes(data, 2)))
    return _picks_from_table(table, (colnames[1], colnames[2]), meta)
end

# nested dictionaries / NamedTuples become dotted keys: units.x = km
function _flatten_metadata(meta, prefix = "")
    out = Pair{String,Any}[]
    ks = meta isa NamedTuple ? collect(keys(meta)) : sort!(collect(keys(meta)); by = string)
    for k in ks
        v = meta[k]
        key = string(prefix, k)
        if v isa AbstractDict || v isa NamedTuple
            append!(out, _flatten_metadata(v, key * "."))
        else
            push!(out, key => v)
        end
    end
    return out
end

function _unflatten!(meta::Dict{String,Any}, key::AbstractString, value::AbstractString)
    parts = split(key, '.')
    d = meta
    for part in parts[1:end-1]
        d = get!(() -> Dict{String,Any}(), d, String(part))
        d isa Dict{String,Any} || return meta   # key collision (a.b vs a), keep the first value
    end
    d[String(parts[end])] = String(value)
    return meta
end

_csv_text(v) = replace(string(v), r"[\r\n]+" => " ")
