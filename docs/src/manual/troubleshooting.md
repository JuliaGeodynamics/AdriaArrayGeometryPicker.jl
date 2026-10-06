# Troubleshooting

**The window does not open, or there is an OpenGL error.**
GLMakie needs OpenGL 3.3 or newer. Update the graphics driver. On a remote machine (SSH) you
need a display (for example X forwarding or a remote desktop). See the
[GLMakie troubleshooting](https://docs.makie.org/stable/explanations/backends/glmakie#Troubleshooting-OpenGL).

**The first start is very slow.**
Julia compiles GLMakie on the first start in a Julia session. This takes up to a minute or
two. Later starts in the same session are fast. To avoid waiting each time, keep the REPL open
and call `geometry_picker` again.

**The window closes right after it opens (script or `julia -e`).**
The script ended. `geometry_picker` waits for the window to be closed only when Julia is not
interactive, which is the default for scripts. If you set `wait = false`, set it back to
`true`.

**Nothing happens when I press A and click.**
- Is the **Picking** toggle on (green)?
- Is the mouse inside the profile axis?
- Does the picker window have the keyboard focus? Click once into the window.
- Is a text field still active (for example the user name field)? Press Enter or click
  elsewhere first.

**I moved a pick by accident.**
Switch picking off while you zoom and pan. There is no undo; drag the pick back, or remove it
(**D** + click) and add it again.

**Load Picks does nothing.**
Look at the REPL. The picks are only loaded if they belong to the loaded profile; the warning
says what does not match (type of profile, start and end coordinates, or depth). Use
**Load Compare Picks** to see them anyway.

**My user name is not in the saved file.**
The user name field only takes the name when you press Enter.

**The colour limits or contour levels do not change.**
Press Enter after typing into a text field. Contour levels must be numbers separated by
commas, semicolons or spaces; anything else is ignored and the automatic levels are used.

**Load State says the profile file does not exist.**
A state stores the full path of the profile file. Move the profile file back, or load the
profile with **Load Profile** and the picks from a pick file.

**Where do messages appear?**
All messages (what was loaded or saved, warnings and errors) are written to the REPL or
terminal from which the picker was started, not into the window.
