layout: home

hero:
  name: AdriaArrayGeometryPicker.jl
  text: Picking geometries on geophysical profiles
  tagline: A graphical user interface to view GeophysicalModelGenerator.jl profiles and to pick geometries on them.
  image:
    src: /logo.png
    alt: AdriaArrayGeometryPicker.jl
  actions:
    - theme: brand
      text: Getting started
      link: /manual/getting_started
    - theme: alt
      text: Introduction
      link: /introduction
    - theme: alt
      text: View on GitHub
      link: https://github.com/JuliaGeodynamics/AdriaArrayGeometryPicker.jl

features:
  - icon: 🗺️
    title: Profiles and slices
    details: Vertical cross-sections and horizontal slices with volume data, surface data, point data, topography and a map overview.
    link: /manual/window
  - icon: ✍️
    title: Picking
    details: Add, move and remove picks with the mouse, with the user name and profile stored with the picks.
    link: /manual/picking
  - icon: 💾
    title: Pick and state files
    details: Save picks as JLD2 or CSV, restore the whole state of the window and load files of earlier versions.
    link: /manual/files
  - icon: 👥
    title: Comparing picks
    details: Show the picks of other people next to your own and make them editable.
    link: /manual/compare
---