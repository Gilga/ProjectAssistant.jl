module ProjectAssistant

using Pkg, Dates, Logging, REPL.TerminalMenus, LibGit2
using PkgTemplates

export project_initialize, project_activate

##################################################

dirs_project = [
    "tmp",
    "logs",
    "assets",
    "data",
    "papers",
    "scripts",
    "project",
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
  ("project.bat","@echo off\n%LOCALAPPDATA%/Julia-$(string(VERSION))/bin/julia.exe --color=yes project/project.jl\n"*"pause\n")
]

copy_files_project = [
  "project/run.jl",
  "project/project.jl",
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

##################################################

function project_initialize()
    PATH_OLD = pwd() # root dir (all projects)
    PROJECT = length(ARGS) > 0 ? ARGS[1] : ""
    USERNAME = length(ARGS) > 1 ? ARGS[2] : ""
    PATH_PROJECT = nothing
    SKIP = true
    TEMPLATE = nothing
    DrWatsonDirs = false

    LOGGER = ConsoleLogger(stdout, Logging.Debug)

    with_logger(LOGGER) do
        while true
            try
                if isempty(PROJECT)
                    print("New project name: "); PROJECT = readline()
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
                print("Retry? [yes]: "); input = readline()
                if input == "n" || input == "no" break end
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

    cd(PATH_PROJECT) # go to project dir

    path_project_files = abspath(PATH_PROJECT,"project")

    if !isdir(path_project_files)
        @info "create dir project."
        mkdir(path_project_files)
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

    git_files = String[]

    # write files
    for file in files_project
        name = file[1]
        content = file[2]
        path_file = abspath(name)
        if !isfile(path_file)
            @info "create file $(basename(name))."
            write(path_file, content)
            push!(git_files,path_file)
        end
    end

    # copy files
    for name in copy_files_project
        path_file = abspath(name)
        if !isfile(path_file)
            @info "copy file $(basename(name))."
            cp(abspath(@__DIR__,"../",name), path_file)
            push!(git_files,path_file)
        end
    end

    # TODO: add files to existing git repo...
    # repo = LibGit2.init(PATH_PROJECT) # wrong?
    # LibGit2.add!(repo,git_files...)
end

function project_activate(dir=pwd())

    cd(dir) # go to project dir
    Pkg.activate(pwd()) # activate this project
    ENV_backup = ENV # backup ENV

    ##################################################

    function show_menu()
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
                    elseif choice == 2 runProject()
                    elseif choice == 3 Pkg.test()
                    elseif choice == 4 createDocs()
                    elseif choice == 5 update()
                    end
                catch ex
                    printError(ex)
                finally
                    resetENV()
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

    function resetENV()
        for (k,v) in ENV
            if haskey(ENV_backup, k)
                ENV[k] = ENV_backup[k]
            end
        end
    end

     # set environment variables
    function readsetENV(file::String = abspath(pwd(),"ENV"))
        if !isfile(file) write(file,"") end
        for line in readlines(file)
            len = length(line)
            if iszero(len) || line[1] == '#' continue end
            env=split(replace(line,"\""=>""),'=')
            ENV[env[1]] = length(env)>1 ? env[2] : ""
        end
    end

    ##################################################

    function runProject()
        project = Symbol(basename(pwd()))
        path_project = abspath(pwd(),"project")
        readsetENV()
        include(abspath(path_project,"startup.jl"))
        file_run = abspath(path_project,"run.jl")
        @info "start project \x1b[33m$project\x1b[39m..."
        run(`$(Sys.BINDIR)/julia.exe --color=yes --startup-file=no --project $file_run $ARGS`)
        @info "end project \x1b[33m$project\x1b[39m."
    end

    ##################################################

    function createDocs()
        file_docs_make = abspath(pwd(),"docs","make.jl")
        !isfile(file_docs_make) && error("docs/make.jl does not exist!")
        include(file_docs_make)
    end

    ##################################################

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
        #pkgs_essential_missing = filter(x->!haskey(installed(),x),pkgs_project_essential)
        #if length(pkgs_essential_missing)>0
        #   for pkg in pkgs_essential_missing Pkg.add(pkg) end
        #end

        Pkg.update()
    end

    ##################################################

    LOGGER = ConsoleLogger(stdout, Logging.Debug)

    with_logger(LOGGER) do
        show_menu()
    end
end

end #module
