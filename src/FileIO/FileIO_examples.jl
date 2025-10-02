
using GLMakie, NativeFileDialog
#=
fig = Figure(size=(200, 200), backgroundcolor=RGBf(0.7, 0.8, 1))
btn_RUN  = Button(fig, label = " Open file... ")
on(btn_RUN.clicks) do c;
    @async begin 
        filename = fetch(Threads.@spawn pick_file(""))
        println(filename)
    end
end
fig
=#

#=
save("hires.png", fig, px_per_unit = 2)    # 1600 × 1200 px png
save("lores.png", fig, px_per_unit = 0.5)  #  400 × 300 px png
=#