using AdriaArrayGeometryPicker: Picks, points, columns, metadata
using GeometryBasics: Point2, Point2f, Point3f

@testset "Picks" begin
    @testset "construction" begin
        p = Picks([Point2f(1, 2), (3.0, 4.0), [5, 6], Point3f(7, 8, 1000)])
        @test length(p) == 4
        @test points(p)[4] == Point2(7.0, 8.0)   # third coordinate dropped
        @test p.names == (:x, :y)
        @test isempty(Picks())

        q = Picks([1.0, 2.0], [3.0, 4.0]; names = (:x, :depth), metadata = Dict(:user => "MT"))
        @test columns(q) == (x = [1.0, 2.0], depth = [3.0, 4.0])
        @test metadata(q)["user"] == "MT"          # Symbol keys converted to String
    end

    @testset "extra columns" begin
        p = Picks([(0, 0), (1, 1)]; columns = (lat = [45, 46],))
        @test columns(p) == (x = [0.0, 1.0], y = [0.0, 1.0], lat = [45.0, 46.0])
        @test_throws DimensionMismatch Picks([(0, 0)]; columns = (lat = [1, 2],))
        @test_throws ArgumentError Picks([(0, 0)]; columns = (x = [1],))
    end

    @testset "invalid input" begin
        @test_throws DimensionMismatch Picks([1.0], [1.0, 2.0])
        @test_throws ArgumentError Picks([(0, 0)]; names = (:x, :x))
    end
end
