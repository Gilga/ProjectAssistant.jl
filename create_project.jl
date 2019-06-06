using Pkg

name = length(ARGS) > 0 ? ARGS[1] : "Example"
author = length(ARGS) > 1 ? ARGS[2] : "Author"

##################################################

files = [
("REQUIRE", ""),

("show_packages.jl", raw"using Pkg
pkg\"activate .\"

@info \"Installed packages:\"
show(stdout, \"text/plain\", sort(collect(Pkg.installed())))
println(\"\n---------------------------------------------------\")"),

("show_packages.bat", raw"@echo off
\"C:/Users/%username%/AppData/Local/Julia-1.1.0/bin/julia.exe\" \"show_packages.jl\"
pause"),

("install_packages.jl", raw"@info \"Adding Packges...\"

# required
using Pkg

# activate this project
pkg\"activate .\"

# helper
function install_pkgs(pkgs;extern=true)
  installed = false
  pkg_list = Pkg.installed()

  for (pkg_name,use) in pkgs
    pkg_symbol = Symbol(pkg_name)

    if extern && !haskey(pkg_list,pkg_name)
      @debug \"Install $pkg_name...\"
      @eval Pkg.add($pkg_name)
      installed = true
    end

    if use @eval using $pkg_symbol end

    @debug \"$pkg_symbol is ready\"
    #exit(0)# exit, cannot create documentations!
  end
  installed
end

# install packages
@info \"Install packages...\"
pkgs = (x->(x,false)).(readlines(joinpath(root,\"REQUIRE\")))
if install_pkgs(pkgs) Pkg.update() end

@info \"Installed packages:\"
show(stdout, \"text/plain\", sort(collect(Pkg.installed())))
println(\"\n---------------------------------------------------\")"),

("install_packages.bat", raw"@echo off
\"C:/Users/%username%/AppData/Local/Julia-1.1.0/bin/julia.exe\" \"install_packages.jl\"
pause"),

("docs/make.jl",raw"@info \"Creating Docs started...\"

PROJECT = ARGS[1]
AUTHORS = ARGS[2]
GITHUP_REPO = ARGS[3] #https://github.com/(User)/(Project)
PRETTYURLS = length(ARGS)>=4 ? ARGS[4] == \"true\" : false

# required
using Pkg

# helper
function install_pkgs(pkgs;extern=true)
  installed = false
  pkg_list = Pkg.installed()

  for (pkg_name,use) in pkgs
    pkg_symbol = Symbol(pkg_name)

    if extern && !haskey(pkg_list,pkg_name)
      @debug \"Install $pkg_name...\"
      @eval Pkg.add($pkg_name)
      installed = true
    end

    if use @eval using $pkg_symbol end

    @debug \"$pkg_symbol is ready\"
    #exit(0)# exit, cannot create documentations!
  end
  installed
end

# setup paths
@info \"Setup paths...\"
root = joinpath(@__DIR__,\"../\")
source = joinpath(root,\"src/\")
docs = @__DIR__
docs_source = joinpath(docs, \"src/\")
docs_files = joinpath(docs_source, \"files/\")
docs_manuals = joinpath(docs_source, \"manual/\")

push!(LOAD_PATH,root)
push!(LOAD_PATH,source)

# ckeck folder
if !isdir(docs_source) mkdir(docs_source) end
if !isdir(docs_files) mkdir(docs_files) end
if !isdir(docs_manuals) mkdir(docs_manuals) end

# install packages
@info \"Install packages...\"
pkgs = (x->(x,false)).(readlines(joinpath(root,\"REQUIRE\")))
push!(pkgs, (\"Documenter\",true)) # add Documenter
if install_pkgs(pkgs) Pkg.update() end

# read files
@info \"Create md files...\"
include_modules = Any[]
md_manuals = Any[]
md_source_files = Any[]
md_modules = Any[]

# get manuals
@info \"Find manuals...\"
for (root, dirs, files) in walkdir(docs_manuals)
  @debug \"Read $root\"
  for file in files
    path = joinpath(root, file)
    ext = last(splitext(file))
    if ext != \".md\" continue end
    @debug \"Found $file\"
    name = replace(file,ext=>\"\")
    push!(md_manuals, titlecase(replace(name,r\"^[0-9]+[^\w]*\s*\"=>\"\")) => \"manual/\"*file)
  end
end

# get source files
@info \"Find source files...\"
for (root, dirs, files) in walkdir(source)
    @debug \"Read $root\"
    for file in files
        path = joinpath(root, file)
        ext = last(splitext(file))
        if ext != \".jl\" continue end
        name = replace(file,ext=>\"\")
        mdfile = name*\".md\"
        mdpath = joinpath(docs_files, mdfile)

        @debug \"Read $file\"
        content = open(path) do f; read(f, String); end

        content = replace(content,\"\r\"=>\"\")
        content = replace(content,r\"\#[^\n]+\n?\"=>\"\")
        #content = replace(content,r\"\#\=.*\=\#\"=>\"\")

        hasmodule = match(r\"module\s+([^\n\;]+)\",content)
        modname = hasmodule == nothing ? \"\" : hasmodule.captures[1]*\".\"

        content = replace(content,r\"([^\s\(]+\([^\)]*\)\s+\=)\"=>s\"function \1\")

        functions = \"\"
        for m in eachmatch(r\"function\s+([^\s\(]+\([^\)]*\))\", content)
          functions*=\"```@docs\n\"*modname*replace(m.captures[1],r\"\:\:[^,]+\"=>\"\")*\"\n```\n\n\"
        end

        #content = replace(content,r\"function\s+([^\s\(]+\([^\)]*\))\s+\=\s+\"=>s\"\")

        vars = \"\"
        #for m in eachmatch(r\"([^\s]+)\s+\=\", content)
        #  vars*=\"```@docs\n$modname\"*m.captures[1]*\"\n```\n\n\"
        #end

        @debug \"Create $mdfile\"
        open(mdpath,\"w+\") do f; write(f,\"# [\"*(hasmodule == nothing ? file : modname[1:end-1])*\"](@id $file)\n\"*\"\n## Variables/Constants\n\n\"*vars*\"\n## Functions\n\n\"*functions); end
        if hasmodule == nothing
          push!(md_source_files, \"files/\"*mdfile)
        else
          push!(md_modules, \"files/\"*mdfile)
          push!(include_modules,Symbol(modname[1:end-1]))
        end
    end
end

# include package
@info \"Include custom packages...\"
install_pkgs((x->(x,true)).(md_modules);extern=false)

# create docs
@info \"Create docs...\"
makedocs(
  #root      = root,
  #build     = build,
  #source    = source,
  modules   = (x->@eval $x).(include_modules),
  clean     = true,
  doctest   = true, # :fix
  #linkcheck = true,
  strict    = false,
  checkdocs = :none,
  format    = Documenter.HTML(prettyurls = PRETTYURLS),
  sitename  = PROJECT,
  authors   = AUTHORS,
  #html_canonical = GITHUP_REPO,
  pages = Any[ # Compat: `Any` for 0.4 compat
      \"Home\" => \"index.md\",
      \"Manual\" => md_manuals,
      \"Modules\" => md_modules,
      \"Source Files\" => md_source_files,
  ],
)

@info \"Creating Docs finished.\"
"),

("make_docs.bat","@echo off
\"C:/Users/%username%/AppData/Local/Julia-1.1.0/bin/julia.exe\" \"docs/make.jl\" \"$name\" \"$author\"
pause")
]

##################################################

# create project
if !isdir(name)
  @info "Create Project $name..."
  eval(Meta.parse("pkg\"generate $name\""))
  println()
end

cd(name)

# activate project
pkg"activate ."

# show Project.toml
@info "Project.toml"
"Project.toml" |> read |> String |> println

# setup paths
@info "Setup paths..."
root = pwd()
source = joinpath(root,"src/")
docs = joinpath(root,"docs/")
docs_source = joinpath(docs,"src/")

# create folder
@info "Create Folders and Files..."
if !isdir(source) mkdir(source) end
if !isdir(docs) mkdir(docs) end
if !isdir(docs_source) mkdir(docs_source) end

#push!(LOAD_PATH,root)

# write files
for file in files 
  if !isfile(file[1])
    println("Create $(file[1])...")
    write(file[1], file[2])
  end
end

println("\n---------------------------------------------------")