using AdriaArrayGeometryPicker: Picks, points, columns, metadata, save_picks, load_picks, save_screenshot
using Dates
using JLD2
import GLMakie

@testset "file IO" begin
    dir = mktempdir()
    meta = Dict("user" => "MT", "date" => DateTime(2026, 9, 30, 12), "units" => (x = "km", depth = "km"))
    p = Picks([(0.0, -10.0), (12.5, -33.25), (100.0, -40.125)]; names = (:x, :depth),
              columns = (lat = [45.0, 45.5, 46.0],), metadata = meta)

    @testset "JLD2 round trip" begin
        path = save_picks(joinpath(dir, "picks.aagpp"), p)
        q = load_picks(path)
        @test q == p                                    # all Julia types preserved
        @test q.metadata["date"] isa DateTime
    end

    @testset "CSV round trip" begin
        path = save_picks(joinpath(dir, "picks.csv"), p)
        text = read(path, String)
        @test startswith(text, "# AdriaArrayGeometryPicker.Picks v1")
        @test occursin("# units.x = km", text)
        @test occursin("x,depth,lat", text)

        q = load_picks(path)
        @test points(q) == points(p)
        @test q.names == p.names
        @test columns(q) == columns(p)
        @test q.metadata["user"] == "MT"
        @test q.metadata["date"] == "2026-09-30T12:00:00"  # CSV metadata comes back as text
        @test q.metadata["units"] == Dict("x" => "km", "depth" => "km")
    end

    @testset "extra columns computed at save time" begin
        lon_at(x) = 10 + x / 100
        for ext in (".aagpp", ".jld2", ".csv")
            path = save_picks(joinpath(dir, "extra" * ext), p; extra = pts -> (lon = lon_at.(first.(pts)),))
            q = load_picks(path)
            @test keys(q.columns) == (:lat, :lon)
            @test q.columns.lon ≈ [10.0, 10.125, 11.0]
        end
    end

    @testset "format selection" begin
        @test save_picks(joinpath(dir, "noext"), p) == joinpath(dir, "noext.aagpp")
        @test load_picks(joinpath(dir, "noext.aagpp")) == p
        path = save_picks(joinpath(dir, "picks.txt"), p; format = :csv)
        @test load_picks(path; format = :csv).names == (:x, :depth)
        @test_throws ArgumentError load_picks(path)                 # unknown extension
        @test_throws ArgumentError save_picks(joinpath(dir, "picks.xyz"), p)
        @test_throws ArgumentError load_picks(joinpath(dir, "missing.csv"))
    end

    @testset "plain vectors and empty picks" begin
        path = save_picks(joinpath(dir, "vec.csv"), [(1, 2), (3, 4)])
        @test points(load_picks(path)) == points(Picks([(1, 2), (3, 4)]))
        for ext in (".aagpp", ".jld2", ".csv")
            q = load_picks(save_picks(joinpath(dir, "empty" * ext), Picks()))
            @test isempty(q)
            @test q.names == (:x, :y)
        end
    end

    @testset "foreign CSV files" begin
        path = joinpath(dir, "noheader.csv")
        write(path, "1.0,2.0,7\n3.0,4.0,8\n")
        q = load_picks(path)
        @test columns(q) == (x = [1.0, 3.0], y = [2.0, 4.0], col3 = [7.0, 8.0])

        path = joinpath(dir, "semicolon.csv")
        write(path, "dist;z\n1;2\n3;4\n")
        q = load_picks(path; delim = ';')
        @test q.names == (:dist, :z)
        @test points(q) == points(Picks([(1, 2), (3, 4)]))

        path = joinpath(dir, "bad.csv")
        write(path, "x,y,z\n1,2\n")
        @test_throws ArgumentError load_picks(path)
    end

    @testset "MakiePickerGUI pick files" begin
        # same layout as the files of this package, with the format tag of MakiePickerGUI.jl
        path = joinpath(dir, "mpg.jld2")
        jldsave(path; format = "MakiePickerGUI.Picks", version = 1, names = ["x", "depth"],
                picks = columns(p), metadata = p.metadata)
        @test load_picks(path) == p
    end

    @testset "original AdriaArrayGeometryPicker pick files" begin
        # layout written by the "Save Picks..." of the original AdriaArrayGeometryPicker.jl
        path = joinpath(dir, "ada.jld2")
        jldsave(path;
                picks = (x = [10.0, 20.0], depth = [-5.0, -7.5], lat = [44.0, 44.5], lon = [12.0, 12.5]),
                pick_info = (user_name = "someone", date = DateTime(2025, 1, 1),
                             units = (x = "km", depth = "km", lat = "deg", lon = "deg")),
                profile_info = (start_lonlat = (12.0, 44.0), end_lonlat = (14.0, 46.0)))
        q = load_picks(path)
        @test q.names == (:x, :depth)
        @test points(q) == points(Picks([(10, -5), (20, -7.5)]))
        @test keys(q.columns) == (:lat, :lon)
        @test q.metadata["user"] == "someone"
        @test q.metadata["units"].lat == "deg"
        @test q.metadata["profile_info"].end_lonlat == (14.0, 46.0)
    end

    GUI_TESTS && @testset "screenshot" begin
        GLMakie.activate!(; visible = false)
        fig = GLMakie.Figure(size = (200, 150))
        GLMakie.heatmap(fig[1, 1], rand(5, 5))
        path = save_screenshot(joinpath(dir, "shot"), fig; px_per_unit = 1)
        @test path == joinpath(dir, "shot.png")
        @test filesize(path) > 0
    end
end
