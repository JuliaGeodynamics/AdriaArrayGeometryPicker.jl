
<h1> <img src="./assets/AdA_Picker_logo.png" alt="AdriaArrayPicker.jl" width="50"> AdriaArrayPicker.jl </h1>

<p align="center"><img src="./assets/AdA_Picker_logo_tr.png" alt="AdriaArrayPicker.jl" width="400"></p>

The **Ad**ria**A**rray Picker is a graphical user interface (GUI) designed to facilitate the visualization and comparison of geophysical datasets. The name stems from the [*AdriaArray*](https://orfeus.readthedocs.io/en/latest/adria_array_main.html) initiative, which focuses on invesitgating the Adria region with seismological methods.

The AdA Picker employs [GLMakie](https://docs.makie.org/stable/explanations/backends/glmakie.html) for high-performance graphics rendering. It builds on [GeophysicalModelGenerator.jl](https://github.com/JuliaGeodynamics/GeophysicalModelGenerator.jl) for data handling. To use the AdA Picker, it is therefore necessary to be familiar with GeophysicalModelGenerator.jl.

### Contents
  - [Main features](#main-features)
  - [System requirements](#system-requirements)
  - [Dependencies](#dependencies)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Troubleshooting](#troubleshooting)
  - [Contributing](#contributing)
  - [Funding](#funding)

### Main features
Some of the key features of the AdA Picker are:
  - compare different geophysical datasets (e.g. seismic tomographies, Moho topographies, seismicity etc.) that have been projected on vertical profiles
  - manually pick locations in these profiles and save these picks.

More features are still in development.

### System requirements
This package heavily relies on GLMakie, therefore it requires an OpenGL enabled graphics card with OpenGL version 3.3 or higher as well as a recent julia installation.

### Dependencies
AdriaArrayPicker relies on several other packages, which are all installed automatically. The most notable ones are:
- [Makie.jl](https://github.com/MakieOrg/Makie.jl), in particular [GLMakie](https://docs.makie.org/stable/explanations/backends/glmakie.html)
- [GeophysicalModelGenerator.jl](https://github.com/JuliaGeodynamics/GeophysicalModelGenerator.jl)

If you are opting to use the AdriaArrayPicker, we strongly recommend to have a look at the GeophysicalModelGenerator first.

### Installation
As a first step, you need to install *julia*. See the installation instructions [here](https://julialang.org/install/). Next, start julia and switch to the julia package manager using `]`, after which you can add the package.
```julia-repl
julia> ]
(@v1.11) pkg> add AdriaArrayPicker
```

This will install the package and all its dependencies.

### Usage
When the installation is done, the package can be used with:
```julia-repl
julia> using AdriaArrayPicker
```
To start the GUI, enter 
```julia-repl
julia> start_AdA_Picker()
```
This will open the GUI. You can find the manual of this GUI [here](). 

### Troubleshooting
If you encounter any issues, don't hesitate to hesitate to open an issue or to as a question in the forum. 

### Contributing
You are very welcome to contribute to AdriaArrayPicker by reporting bugs or by implementing new functionality.

### Funding
Early versions of this GUI have been developed with support from different DFG projects (DFG grants TH2076/7-1 and KA3367/10-1), which were part of the [SPP 2017 4DMB project](http://www.spp-mountainbuilding.de) project and the DFG Emmy Noether grant TH 2076/8-1.

This current version is being developed as part of the DFG funded Priority Program DEFORM under project number TH 2076/10-1.