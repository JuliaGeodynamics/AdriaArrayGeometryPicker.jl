using AdriaArrayGeometryPicker
using Test
import GLMakie

# Tests that render with OpenGL (GLMakie) need a display or a software OpenGL driver. The
# environment variable ADA_GUI_TESTS selects whether they run:
#   "true"  - run them, a missing OpenGL context is an error (CI on Linux with xvfb)
#   "false" - skip them (e.g. on a headless server without OpenGL)
#   "auto"  - (default) run them if an OpenGL context can be created, otherwise skip them
function gui_tests_enabled()
    mode = lowercase(get(ENV, "ADA_GUI_TESTS", "auto"))
    mode in ("true", "1") && return true
    mode in ("false", "0") && return false
    try
        GLMakie.activate!(; visible = false)
        screen = GLMakie.Screen(; visible = false)
        close(screen)
        return true
    catch err
        @info "No OpenGL context available, the GUI tests are skipped: $(sprint(showerror, err))"
        return false
    end
end
const GUI_TESTS = gui_tests_enabled()

@testset "AdriaArrayGeometryPicker" begin
    include("test_picks.jl")
    include("test_io.jl")
    include("test_dialogs.jl")
    if GUI_TESTS
        include("test_gui.jl")
    else
        @warn "Skipping the GUI tests (no OpenGL, see ADA_GUI_TESTS)"
    end
end
