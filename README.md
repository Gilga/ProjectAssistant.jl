# ProjectAssistant.jl

- Created with Julia Version 1.3.1.
- Uses [PkgTemplates.jl](https://github.com/invenia/PkgTemplates.jl).
- Additionally can use DrWatson dirs (see [DrWatson.jl](https://github.com/JuliaDynamics/DrWatson.jl)), but package is not required.
- Uses additional scripts to create and run new projects.

## Required
- [PkgTemplates.jl](https://github.com/invenia/PkgTemplates.jl)

## Optional
- [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl)

## Run script on Linux

Change permission on the **project.jl** using:
```
chmod a+x project.jl
```
Run the script using **./project.jl**.

### Notice
The path to the julia binary at the top line in **project.jl** invokes binary execution:
```
#!/usr/bin/julia
```

## Run script on Windows
Execute **project.bat**.
