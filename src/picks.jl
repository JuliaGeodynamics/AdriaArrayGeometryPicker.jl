# Container for one set of picked points.
# This type is independent of Makie observables, so that it can be used for file IO,
# tests and post-processing without a GUI.

const PickPoint = Point2{Float64}

"""
    Picks(points; names = (:x, :y), columns = (;), metadata = Dict{String,Any}())
    Picks(x, y; kwargs...)

A single set of picked points. Generic: independent of Makie and of the profile data, so it
can be used for file IO ([`save_picks`](@ref), [`load_picks`](@ref)), tests and post-processing
without a GUI.

# Arguments
- `points`: vector of 2D points. Anything with at least two indexable coordinates is
  accepted (`Point2f`, `Point3f`, `Point3d` as in the picks of the GUI, tuples, vectors); only
  the first two coordinates are kept.
- `x`, `y`: alternatively, the two coordinates as vectors of equal length.

# Keywords
- `names`: names of the two coordinates, used as column names in files (e.g. `(:x, :depth)`).
- `columns`: additional per-point columns as a `NamedTuple` of vectors of the same length as
  `points` (e.g. `(lat = ..., lon = ...)`); their names must differ from `names`.
- `metadata`: free-form information such as user name, date, units or profile information
  (keys are converted to strings).

`Picks` supports `length`, `isempty`, `collect` (a copy of the points), `==` and the accessors
[`points`](@ref), [`columns`](@ref) and [`metadata`](@ref).

# Example
```jldoctest; setup = :(using AdriaArrayGeometryPicker)
julia> p = Picks([(0.0, -10.0), (50.0, -35.0)]; names = (:x, :depth),
                 columns = (lat = [45.0, 45.5],), metadata = Dict("user" => "MT"))
Picks(2 points, names = (:x, :depth), columns = (:lat,))

julia> length(p)
2

julia> Picks([0.0, 50.0], [-10.0, -35.0]; names = (:x, :depth)) == Picks([(0.0, -10.0), (50.0, -35.0)]; names = (:x, :depth))
true
```
"""
struct Picks
    points::Vector{PickPoint}
    names::NTuple{2,Symbol}
    columns::NamedTuple
    metadata::Dict{String,Any}

    function Picks(points::Vector{PickPoint}, names::NTuple{2,Symbol}, columns::NamedTuple, metadata::Dict{String,Any})
        n = length(points)
        for (k, v) in pairs(columns)
            k in names && throw(ArgumentError("extra column `$k` clashes with a coordinate name"))
            length(v) == n || throw(DimensionMismatch("column `$k` has length $(length(v)), expected $n"))
        end
        names[1] == names[2] && throw(ArgumentError("coordinate names must differ, got $names"))
        return new(points, names, columns, metadata)
    end
end

function Picks(points::AbstractVector = PickPoint[]; names = (:x, :y), columns::NamedTuple = (;),
               metadata::AbstractDict = Dict{String,Any}())
    pts = PickPoint[PickPoint(p[1], p[2]) for p in points]
    cols = map(v -> collect(Float64, v), columns)
    meta = Dict{String,Any}(string(k) => v for (k, v) in metadata)
    return Picks(pts, (Symbol(names[1]), Symbol(names[2])), cols, meta)
end

Picks(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}; kwargs...) =
    length(x) == length(y) ? Picks(PickPoint.(x, y); kwargs...) :
    throw(DimensionMismatch("x and y must have the same length"))

"""
    points(p::Picks) -> Vector{Point2{Float64}}

The picked points as a vector of 2D points (the stored vector, not a copy).

# Example
```jldoctest; setup = :(using AdriaArrayGeometryPicker)
julia> p = Picks([(0.0, -10.0), (50.0, -35.0)]);

julia> [Tuple(q) for q in points(p)]
2-element Vector{Tuple{Float64, Float64}}:
 (0.0, -10.0)
 (50.0, -35.0)
```
"""
points(p::Picks) = p.points

"""
    metadata(p::Picks) -> Dict{String,Any}

The metadata dictionary (the stored one, so it can be modified in place).

# Example
```jldoctest; setup = :(using AdriaArrayGeometryPicker)
julia> p = Picks([(0.0, -10.0)]; metadata = Dict("user" => "MT"));

julia> metadata(p)["date"] = "2024-01-01";

julia> metadata(p)["user"], metadata(p)["date"]
("MT", "2024-01-01")
```
"""
metadata(p::Picks) = p.metadata

"""
    columns(p::Picks) -> NamedTuple

All per-point data as a table-like `NamedTuple`: the two coordinates (named according to
`p.names`) followed by the extra columns. This is what is written to files.

# Example
```jldoctest; setup = :(using AdriaArrayGeometryPicker)
julia> p = Picks([(0.0, -10.0), (50.0, -35.0)]; names = (:x, :depth), columns = (lat = [45.0, 45.5],));

julia> columns(p)
(x = [0.0, 50.0], depth = [-10.0, -35.0], lat = [45.0, 45.5])
```
"""
function columns(p::Picks)
    xy = NamedTuple{p.names}(([q[1] for q in p.points], [q[2] for q in p.points]))
    return merge(xy, p.columns)
end

Base.length(p::Picks) = length(p.points)
Base.isempty(p::Picks) = isempty(p.points)
Base.collect(p::Picks) = copy(p.points)

function Base.:(==)(a::Picks, b::Picks)
    return isequal(a.points, b.points) && a.names == b.names &&
           isequal(a.columns, b.columns) && isequal(a.metadata, b.metadata)
end

function Base.show(io::IO, p::Picks)
    print(io, "Picks(", length(p), " points, names = ", p.names)
    isempty(p.columns) || print(io, ", columns = ", keys(p.columns))
    return print(io, ")")
end
