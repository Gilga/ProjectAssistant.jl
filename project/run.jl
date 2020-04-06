project = Symbol(basename(pwd()))
@eval begin
    using $project
    $project.main()
end
