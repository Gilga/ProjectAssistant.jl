module ProjectAssistant

using Pkg, Dates, Logging, REPL.TerminalMenus, LibGit2

export project_initialize, project_activate

##################################################

pkgs_essential = ["PkgTemplates","LoggingExtras","Documenter"]
pkgs_project_essential = []

##################################################

julia = "%LOCALAPPDATA%/Julia-$(string(VERSION))/bin/julia.exe --color=yes"

##################################################

#using Pkg # required
#Pkg.activate(pwd()) # activate this project

script_env = """file_env = abspath(pwd(),"ENV") # set environment variables
if !isfile(file_env) write(file_env,"") end
for line in readlines(file_env)
    len = length(line)
    if iszero(len) || line[1] == '#' continue end
    env=split(replace(line,"\""=>""),'=')
    ENV[env[1]] = length(env)>1 ? env[2] : ""
end
"""

script_start = """project = Symbol(basename(pwd()))
include(abspath(@__DIR__,"envs.jl")) # for environments (similiar to startup.jl)
file_run = abspath(@__DIR__,"run.jl")
@info "start project \x1b[33m$project\x1b[39m..."
run(`$(Sys.BINDIR)/julia.exe --color=yes --startup-file=no --project $file_run $ARGS`)
@info "end project \x1b[33m$project\x1b[39m."
"""

script_docs = """file_make = abspath(pwd(),"docs","make.jl")
isfile(file_make) ? include(file_make) : @warn "docs/make.jl does not exist!"  # docs
"""

script_run = """project = Symbol(basename(pwd()))
@eval begin
    using $project
    $project.main()
end
"""

script_project = """#!/usr/bin/julia
installed() = Pkg.installed()

if !haskey(installed(),"ProjectAssistant")
    Pkg.add("ProjectAssistant")
    Pkg.update()
end

using ProjectAssistant
project_initalize()
"""

batch_project = """@echo off
$julia project.jl
pause"""

##################################################

dirs_project = [
    "tmp",
    "logs",
    "assets",
    "data",
    "papers",
    "scripts",
]

# DrWatson dirs, see https://juliadynamics.github.io/DrWatson.jl/dev/project/
dirs_DrWatson = [
    "_research",
    "_research/tmp",
    "data/exp_pro",
    "data/exp_raw",
    "plots",
    "notebooks",
    "papers",
]

files_project = [
  ("REQUIRE", ""),
  ("ENV", ""),
  ("project/startup.jl", ""),
  ("project/env.jl", script_env),
  ("project/start.jl", script_start),
  ("project/docs.jl", script_docs),
  ("project/run.jl", script_run),
  ("project.bat",batch_project)
]

##################################################

printError(ex) = @error sprint(showerror, ex, catch_backtrace())

# if VERSION.major > 1 || (VERSION.major == 1 && VERSION.minor > 3)
#     function installed() # since Julia 1.4: Pkg.installed() is deprecated
#         deps = Pkg.dependencies()
#         installs = Dict{String, VersionNumber}()
#         for (uuid, dep) in deps
#             dep.is_direct_dep || continue
#             dep.version === nothing && continue
#             installs[dep.name] = dep.version
#         end
#         return installs
#     end
# else
#     installed() = Pkg.installed()
# end

# will change when project is updated to Julia 1.4
installed() = Pkg.installed()

is_pkgs_missing(pkgs::AbstractArray) = length(filter(x->!haskey(installed(),x),pkgs))>0

  # update when some packages are not added
function install_missing_pkgs(pkgs::AbstractArray)
    missing = filter(x->!haskey(installed(),x),pkgs)
    if length(missing)>0
        for pkg in missing Pkg.add(pkg) end
        Pkg.update()
    end
end

# update when some packages are not added
install_missing_pkgs(pkgs_essential)

using PkgTemplates

#if isfile(abspath(pwd(),"Project.toml")) @goto project
#else @goto create_project
#end

##################################################

function project_initialize()
    LOGGER = ConsoleLogger(stdout, Logging.Debug)

    ##################################################
    #@label create_project # default section if Project.toml does not exists

    PATH_OLD = pwd() # root dir (all projects)
    PROJECT = length(ARGS) > 0 ? ARGS[1] : ""
    USERNAME = length(ARGS) > 1 ? ARGS[2] : ""
    PATH_PROJECT = nothing
    SKIP = true
    TEMPLATE = nothing
    DrWatsonDirs = false

    with_logger(LOGGER) do
        while true
            global PATH_OLD, PROJECT, USERNAME, PATH_PROJECT, SKIP, TEMPLATE

            try
                if isempty(PROJECT)
                    print("Project: "); PROJECT = readline()
                    if isempty(PROJECT) throw(ArgumentError("Project name is required")) end

                    print("Skip questions and use default settings? [yes]: "); input = readline()
                    if input == "n" || input == "no" SKIP=false end
                end

                if !SKIP
                    TEMPLATE = interactive_template()

                    print("Create additional DrWatson dirs? [no]: "); input = readline()
                    if input == "y" || input == "yes" DrWatsonDirs=true end
                else
                    if isempty(USERNAME)
                        USERNAME = LibGit2.getconfig("github.user", "")
                        if isempty(USERNAME) print("Username: "); USERNAME = readline() end
                        if isempty(USERNAME) throw(ArgumentError("Username is required")) end
                    end
                end

            catch ex
                printError(ex)
                @info "Retry..."
                continue
            end

            break
        end
    end

    if isnothing(TEMPLATE) # default
        TEMPLATE = Template(;
            user=USERNAME,
            #host="https://github.com",
            #license="MIT",
            authors=[USERNAME],
            #dir=Pkg.devdir() #abspath(pwd())
            #julia_version=VERSION,
            #ssh=false,
            dev=false, # true
            #manifest=false,
            plugins=[
                GitHubPages(),
                AppVeyor(),
                Codecov(), #; config_file=nothing
                #Coveralls(),
                TravisCI()
            ],
            #git=true
        )
    end

    generate(TEMPLATE, PROJECT)
    PATH_PROJECT = abspath(TEMPLATE.dir,PROJECT)

    if !isdir(PATH_PROJECT) throw(ArgumentError("Cannot write dir $(PATH_PROJECT)!")) end

    # copy this file
    file_project = abspath(PATH_PROJECT,basename(@__FILE__))
    if !isfile(file_project) cp(@__FILE__,file_project) end

    cd(PATH_PROJECT) # go to project dir
end

function project_activate(dir=pwd())
    cd(dir) # go to project dir

    ##################################################
    #@label project # go here only if Project.toml exists

    Pkg.activate(pwd()) # activate this project

    ##################################################

    PROJECT = basename(pwd())
    PATH_PROJECTFILES = abspath(pwd(),"project")

    if !isdir(PATH_PROJECTFILES)
        @info "create dir project."
        mkdir(PATH_PROJECTFILES)
    end

    # write dirs
    dir_lists = [dirs_project]
    if DrWatsonDirs push!(dir_lists,dirs_DrWatson) end

    for dirs in dir_lists
        for name in dirs
            path_dir = abspath(name)
            if !isdir(path_dir)
                @info "create dir $(basename(name))."
                mkdir(path_dir)
            end
        end
    end

    # write files
    for file in files_project
        name = file[1]
        content = file[2]
        path_file = abspath(name) #replace(name,"\$DIR_PROJECT"=>PATH_PROJECTFILES)
        if !isfile(path_file)
            @info "create file $(basename(name))."
            write(path_file, replace(content,"\$PROJECT"=>PROJECT))
        end
    end

    ##################################################

    julia = `$(Sys.BINDIR)/julia.exe --color=yes --startup-file=no --project`
    pkgs_essential = []

    ##################################################

    function show_menu()
        if is_pkgs_missing(pkgs_project_essential) update() end # this needs to be done before we use essential packages

        options = ["info", "start", "test", "make docs", "update packages", "exit"]
        menu = RadioMenu(options) #, pagesize=6
        selected = 1

        while true
            write(stdin.buffer, repeat("[B",max(selected-1,0))) # simulate input

            choice = request("Choose option:", menu)

            if choice != -1
                selected = choice
                option = options[choice]
                println("Choosed: ", option)

                try
                    if choice == length(options) break
                    elseif choice == 1 get_project_info()
                    elseif choice == 2 include(abspath(PATH_PROJECTFILES,"start.jl"))
                    elseif choice == 3 Pkg.test()
                    elseif choice == 4 include(abspath(PATH_PROJECTFILES,"docs.jl"))
                    elseif choice == 5 update()
                    end
                catch ex
                    printError(ex)
                end
            else
                println("Menu canceled.")
                break
            end
        end
    end

    ##################################################

    function get_project_info()
        file_path = abspath(pwd(),"Project.toml")
            packages = join(sort((x->Pair(x.first,isnothing(x.second) ? "" : string(x.second))).(collect(installed()))),"
        ")

        println()
        @info "Project.toml\n" * read(file_path, String)
        println()
        @info "Installed packages\n" * packages
        println()
    end

    ##################################################

    is_pkgs_missing(pkgs::AbstractArray) = length(filter(x->!haskey(installed(),x),pkgs))>0

    function update()
        file_path = abspath(pwd(),"REQUIRE")

        pkgs_require = filter(x->isnothing(match(r"^#",x)),readlines(file_path))
        @info "Check update..." pkgs_require

        pkgs_list = [x.first for x in installed()]
        pkgs_install = filter(x->!in(x,pkgs_list),pkgs_require)
        pkgs_remove = filter(x->!in(x,pkgs_require),pkgs_list)

        for pkg_name in pkgs_install
            @info "Install $pkg_name..."

            try
                Pkg.add(pkg_name)
                @info "$pkg_name installed"
            catch e
                dump(e)
            end
        end

        for pkg_name in pkgs_remove
            if in(pkg_name,pkgs_project_essential) continue end # skip if package is marked as "essential"

            @info "Remove $pkg_name..."

            try
                Pkg.rm(pkg_name)
                @info "$pkg_name removed"
            catch e
                dump(e)
            end
        end

        # update when some packages are not added
        pkgs_essential_missing = filter(x->!haskey(installed(),x),pkgs_project_essential)
        if length(pkgs_essential_missing)>0
            for pkg in pkgs_essential_missing Pkg.add(pkg) end
        end

        Pkg.update()
    end

    ##################################################

    #include(abspath(PATH_PROJECTFILES,"log.jl")) # logger

    with_logger(LOGGER) do
        show_menu()
    end
end

end #module
