using Pkg # required
Pkg.activate(pwd()) # activate this project

using Documenter

get_pair(x::AbstractString) = split(replace(replace(x,r"\s*=\s*" => "="),"\"" => ""),"=")
filter_pairs(list::AbstractArray) = filter(x->!isnothing(match(r"=",x)),list)

# setup paths
@info "Setup paths..."
root = pwd()
source = abspath(root,"src")
docs = abspath(pwd(),"docs")
docs_source = abspath(docs, "src")
docs_files = abspath(docs_source, "files")
docs_manuals = abspath(docs_source, "manual")

#push!(LOAD_PATH,root)
#push!(LOAD_PATH,source)
#cd(root)

@info "Creating Docs started..."

file_path = abspath(root,"Project.toml")
config = Dict((get_pair).(filter_pairs(readlines(file_path))))
  
PROJECT = config["name"]
PROJECT_VERSION = config["version"]
AUTHORS = config["authors"]
GITHUB_REPO = get(config, "repo", "https://github.com/(User)/(Project)")
PRETTYURLS = get(config, "prettyurls", "false") == "true"

# ckeck folder
if !isdir(docs_source) mkdir(docs_source) end
if !isdir(docs_files) mkdir(docs_files) end
if !isdir(docs_manuals) mkdir(docs_manuals) end

# ckeck files
file_index = abspath(docs_source,"index.md")
if !isfile(file_index) write(file_index, "# $PROJECT $PROJECT_VERSION Documentation

Welcome to the documentation for $PROJECT $PROJECT_VERSION.

## Description
Here is the package description
LICENSE: See [LICENSE](../blob/master/LICENSE)

## Site
* [Manual](#Manual)
* [Developer Documentation](#Developer-Documentation)

## Manual
* [Start](@ref start)
* [Install](@ref install)

## Documentation

* [Algorithm](@ref algorithm)
* [Build](@ref build)
* [Optimization](@ref optimization)
* [References](@ref references)") end

# read files
@info "Create md files..."
include_modules = Any[]
md_manuals = Any[]
md_source_files = Any[]
md_modules = Any[]

# get manuals
@info "Find manuals..."
for (root, dirs, files) in walkdir(docs_manuals)
  @debug "Read $root"
  for file in files
    path = abspath(root, file)
    ext = last(splitext(file))
    if ext != ".md" continue end
    @debug "Found $file"
    name = replace(file,ext=>"")
    push!(md_manuals, titlecase(replace(name,r"^[0-9]+[^\w]*\s*"=>"")) => "manual/"*file)
  end
end

# get source files
@info "Find source files..."
for (root, dirs, files) in walkdir(source)
    @debug "Read $root"
    for file in files
        path = abspath(root, file)
        ext = last(splitext(file))
        if ext != ".jl" continue end
        name = replace(file,ext=>"")
        mdfile = name*".md"
        mdpath = abspath(docs_files, mdfile)

        @debug "Read $file"
        content = open(path) do f; read(f, String); end

        content = replace(content,"\r"=>"")
        content = replace(content,r"\#[^\n]+\n?"=>"")
        #content = replace(content,r"\#\=.*\=\#"=>"")

        hasmodule = match(r"module\s+([^\n\;]+)",content)
        modname = hasmodule == nothing ? "" : hasmodule.captures[1]*"."

        content = replace(content,r"([^\s\(]+\([^\)]*\)\s+\=)"=>s"function \1")

        functions = ""
        for m in eachmatch(r"function\s+([^\s\(]+\([^\)]*\))", content)
          functions*="```@docs\n"*modname*replace(m.captures[1],r"\:\:[^,]+"=>"")*"\n```\n\n"
        end

        #content = replace(content,r"function\s+([^\s\(]+\([^\)]*\))\s+\=\s+"=>s"")

        vars = ""
        #for m in eachmatch(r"([^\s]+)\s+\=", content)
        #  vars*="```@docs\n$modname"*m.captures[1]*"\n```\n\n"
        #end

        @debug "Create $mdfile"
        open(mdpath,"w+") do f; write(f,"# ["*(hasmodule == nothing ? file : modname[1:end-1])*"](@id $file)\n"*"\n## Variables/Constants\n\n"*vars*"\n## Functions\n\n"*functions); end
        if hasmodule == nothing
          push!(md_source_files, "files/"*mdfile)
        else
          push!(md_modules, "files/"*mdfile)
          push!(include_modules,Symbol(modname[1:end-1]))
        end
    end
end

@info "Include custom packages..."
for pkg_name in include_modules
  @info "Bind $pkg_name..."
  pkg_symbol = Symbol(pkg_name)
  @eval using $pkg_symbol
end

# create docs
@info "Create docs..."
makedocs(
  root      = docs,
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
  #html_canonical = GITHUB_REPO,
  pages = Any[ # Compat: `Any` for 0.4 compat
      "Home" => "index.md",
      "Manual" => md_manuals,
      "Modules" => md_modules,
      "Source Files" => md_source_files,
  ],
)

@info "Creating Docs finished."
