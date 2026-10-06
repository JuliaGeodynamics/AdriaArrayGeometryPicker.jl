using AdriaArrayGeometryPicker: AdriaArrayGeometryPicker, Picks, points, open_dialog, save_dialog, with_open_dialog,
                      save_picks_dialog, load_picks_dialog, save_screenshot_dialog
import GLMakie

# replace the native dialogs by functions returning fixed paths (no user on CI)
function with_fake_dialogs(f, open_path, save_path)
    old_open, old_save = AdriaArrayGeometryPicker.OPEN_DIALOG[], AdriaArrayGeometryPicker.SAVE_DIALOG[]
    AdriaArrayGeometryPicker.OPEN_DIALOG[] = (; kwargs...) -> open_path
    AdriaArrayGeometryPicker.SAVE_DIALOG[] = (; kwargs...) -> save_path
    try
        f()
    finally
        AdriaArrayGeometryPicker.OPEN_DIALOG[], AdriaArrayGeometryPicker.SAVE_DIALOG[] = old_open, old_save
    end
end

@testset "dialogs" begin
    dir = mktempdir()
    p = Picks([(1, 2), (3, 4)]; metadata = Dict("user" => "MT"))

    @testset "cancel" begin
        with_fake_dialogs("", nothing) do
            @test open_dialog() === nothing
            @test save_dialog() === nothing
            called = Ref(false)
            @test fetch(with_open_dialog(path -> (called[] = true))) === nothing
            @test !called[]
        end
    end

    @testset "save and load picks" begin
        path = joinpath(dir, "dialog.aagpp")
        with_fake_dialogs(path, path) do
            # picks given as a function: evaluated when the dialog returns
            @test fetch(save_picks_dialog(() -> p)) == path
            loaded = Ref{Any}(nothing)
            fetch(load_picks_dialog(q -> (loaded[] = q)))
            @test loaded[] == p
        end
        # dialog path without extension -> .aagpp appended
        with_fake_dialogs("", joinpath(dir, "noext")) do
            @test fetch(save_picks_dialog(p)) == joinpath(dir, "noext.aagpp")
        end
    end

    @testset "errors are logged, not thrown" begin
        with_fake_dialogs(joinpath(dir, "does_not_exist.csv"), "") do
            # the task inherits the test logger; fetch inside @test_logs to capture its log
            result = @test_logs (:error, r"File dialog action failed") match_mode = :any fetch(load_picks_dialog())
            @test result === nothing
        end
    end

    @testset "screenshot" begin
        fig = GLMakie.Figure(size = (100, 100))
        with_fake_dialogs("", joinpath(dir, "dialogshot.png")) do
            @test fetch(save_screenshot_dialog(fig; px_per_unit = 1)) == joinpath(dir, "dialogshot.png")
        end
        @test isfile(joinpath(dir, "dialogshot.png"))
    end
end
