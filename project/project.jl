#!/usr/bin/julia

using Pkg

installed() = Pkg.installed()

if !haskey(installed(),"ProjectAssistant")
    Pkg.add("ProjectAssistant")
    Pkg.update()
end

using ProjectAssistant
project_activate(abspath(@__DIR__,"../"))
