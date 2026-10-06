using AdriaArrayGeometryPicker
using Test

@testset "AdriaArrayGeometryPicker" begin
    include("test_picks.jl")
    include("test_io.jl")
    include("test_dialogs.jl")
    include("test_gui.jl")
end
