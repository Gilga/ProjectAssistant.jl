#!/usr/bin/julia
installed() = Pkg.installed()

if !haskey(installed(),"JuliaProjectTemplate")
    Pkg.add(PackageSpec(url="https://github.com/Gilga/JuliaProjectTemplate.jl"))
    Pkg.update()
end

using JuliaProjectTemplate
project_initalize()
