# ProjectAssistant.jl

- Created with Julia Version 1.3.1
- Uses [PkgTemplates.jl](https://github.com/invenia/PkgTemplates.jl) + additional scripts to create and run new projects.
- Additionally can use DrWatson dirs (see [DrWatson.jl](https://github.com/JuliaDynamics/DrWatson.jl)), but package is not required.

## Required
- [PkgTemplates.jl](https://github.com/invenia/PkgTemplates.jl) + additional scripts to create and run new projects.

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
