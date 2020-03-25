#!/usr/bin/julia

using Pkg, Dates # required

##################################################

pkgs_essential = ["PkgTemplates","LoggingExtras","Documenter"]
pkgs_project_essential = []

##################################################

julia = "%LOCALAPPDATA%/Julia-$(string(VERSION))/bin/julia.exe --color=yes"

##################################################

#using Pkg # required
#Pkg.activate(pwd()) # activate this project

script_precode = """include(abspath(@__DIR__,"log.jl"))"""

script_logger = """using Logging, LoggingExtras, Dates 

timestamp_logger(logger) = TransformerLogger(logger) do log
  merge(log, (; message = "\$(Dates.format(now(), "yyyy-mm-dd HH:MM:ss:SSS")) \$(log.message)"))
end

path_logs = abspath(pwd(),"logs")
if !isdir(path_logs) mkdir(path_logs) end

session = Dates.format(now(), "yyyy-mm-dd_HH-MM-ss")

logger = TeeLogger(
  ConsoleLogger(stdout, Logging.Debug) |> timestamp_logger,
  #MinLevelLogger(FileLogger(abspath(path_logs,"info_\$session.log")), Logging.Info) |> timestamp_logger,
  MinLevelLogger(FileLogger(abspath(path_logs,"debug_\$session.log")), Logging.Debug) |> timestamp_logger,
  #MinLevelLogger(FileLogger(abspath(path_logs,"warn_\$session.log")), Logging.Warn) |> timestamp_logger,
  #MinLevelLogger(FileLogger(abspath(path_logs,"error_\$session.log")), Logging.Error) |> timestamp_logger,
)

logger_old = global_logger(logger)
"""

script_start = """$script_precode
include(abspath(@__DIR__,"startup.jl")) # environment variables
file_run = abspath(@__DIR__,"run.jl")
run(`\$(Sys.BINDIR)/julia.exe --color=yes --project \$file_run \$ARGS`)# run with changed envs
"""

script_docs = """$script_precode
file_make = abspath(pwd(),"docs","make.jl")
isfile(file_make) ? include(file_make) : @warn "docs/make.jl does not exist!"  # docs
"""

script_run = """$script_precode
@info "Start \$PROJECT..."
using \$PROJECT
\$PROJECT.greet()
@info "End \$PROJECT."
"""

batch_project = """@echo off
$julia project.jl
pause"""

##################################################

files = [
  ("REQUIRE", ""),
  ("\$DIR_PROJECT/startup.jl", ""),
  ("\$DIR_PROJECT/log.jl", script_logger),
  ("\$DIR_PROJECT/start.jl", script_start),
  ("\$DIR_PROJECT/docs.jl", script_docs),
  ("\$DIR_PROJECT/run.jl", script_run),
  ("project.bat",batch_project)
]

##################################################

if VERSION.major > 1 || (VERSION.major == 1 && VERSION.minor > 3)
  function installed() # since Julia 1.4: Pkg.installed() is deprecated
    deps = Pkg.dependencies()
    installs = Dict{String, VersionNumber}()
    for (uuid, dep) in deps
        dep.is_direct_dep || continue
        dep.version === nothing && continue
        installs[dep.name] = dep.version
    end
    return installs
  end
else
  installed() = Pkg.installed()
end

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

##################################################

begin
  if isfile(abspath(pwd(),"Project.toml")) @goto project
  else @goto create_project
  end
  
  ##################################################
  @label create_project # default section if Project.toml does not exists

  using PkgTemplates, LibGit2
  
  PATH_OLD = pwd() # root dir (all projects)
  PROJECT = length(ARGS) > 0 ? ARGS[1] : ""
  USERNAME = length(ARGS) > 1 ? ARGS[2] : ""
  PATH_PROJECT = nothing
  SKIP = true
  TEMPLATE = nothing

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
      else
        if isempty(USERNAME)
          USERNAME = LibGit2.getconfig("github.user", "")
          if isempty(USERNAME) print("Username: "); USERNAME = readline() end
          if isempty(USERNAME) throw(ArgumentError("Username is required")) end
        end
      end
      
    catch ex
      @error ex
      @info "Retry..."
      continue
    end
    
    break
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

  ##################################################
  @label project # go here only if Project.toml exists
  
  Pkg.activate(pwd()) # activate this project
  
  ##################################################
  
  PROJECT = basename(pwd())
  PATH_PROJECTFILES = abspath(pwd(),"project")
  
  if !isdir(PATH_PROJECTFILES)
     @info "create dir project."
    mkdir(PATH_PROJECTFILES)
  end
  
  # write files
  for file in files
    name = file[1]
    content = file[2]
    path_file = abspath(replace(name,"\$DIR_PROJECT"=>PATH_PROJECTFILES))
    if !isfile(path_file)
      @info "create file $(replace(name,"\$DIR_PROJECT/"=>""))."
      write(path_file, replace(content,"\$PROJECT"=>PROJECT))
    end
  end
  
  include(abspath(PATH_PROJECTFILES,"log.jl")) # logger
  
  ##################################################

  julia = `$(Sys.BINDIR)/julia.exe --color=yes --project`

  pkgs_essential = []

  ##################################################

  using REPL.TerminalMenus

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
            elseif choice == 2 run(`$julia $(abspath(PATH_PROJECTFILES,"start.jl"))`)
            elseif choice == 3 Pkg.test()
            elseif choice == 4 run(`$julia $(abspath(PATH_PROJECTFILES,"docs.jl"))`)
            elseif choice == 5 update()
            end
          catch ex
            @error ex
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
    @info "Project.toml
  " * read(file_path, String)
    println()
    @info "Installed packages
  " * packages
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
    
    global pkgs_project_essential
    
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

  show_menu()
end
