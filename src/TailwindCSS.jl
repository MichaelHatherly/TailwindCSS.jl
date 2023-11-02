module TailwindCSS

using Artifacts

export tailwindcss

"""
    tailwindcss(; kws...) -> Cmd

Return a `Cmd` object that can be used to run the `tailwindcss` executable.

`kws` are passed to the `Cmd` as keywords.

# Examples

```julia
julia> run(`$(tailwindcss()) --help`)

```
"""
function tailwindcss(; kws...)
    path = joinpath(artifact"tailwindcss", "tailwindcss$(Sys.iswindows() ? ".exe" : "")")
    return Cmd(Cmd([path]); env = copy(ENV), kws...) # Somewhat replicating JLLWrapper behavior.
end

"""
    version() -> VersionNumber

Return the version of the `tailwindcss` executable.
"""
function version()
    help_string = readchomp(`$(tailwindcss()) --help`)
    m = match(r"tailwindcss v([0-9]+\.[0-9]+\.[0-9]+)", help_string)
    m === nothing && error("Could not parse version from help string:\n'$help_string'.")
    return VersionNumber(m[1])
end

"""
    help()

Print the help string for the `tailwindcss` executable.
"""
function help(io::IO = stdout)
    init = readchomp(`$(tailwindcss()) init --help`)
    build = readchomp(`$(tailwindcss()) build --help`)
    println(io, init, build)
end

"""
    init(dir::AbstractString = pwd(); full::Bool = false)

Initialize a new TailwindCSS project in the given directory.

# Examples

```julia
julia> TailwindCSS.init()

julia> TailwindCSS.init("myproject")

julia> TailwindCSS.init("my-project-all-config"; full = true)

```
"""
function init(root::AbstractString = pwd(); full::Bool = false)
    if isdir(root)
        cd(root) do
            if full
                run(`$(tailwindcss()) init --full`)
            else
                run(`$(tailwindcss()) init`)
            end
        end
    else
        error("'$root' is not a directory.")
    end
end

"""
    build(root::AbstractString = pwd(), input::AbstractString = "input.css", output::AbstractString = joinpath("dist", "output.css"))

Build the TailwindCSS output file from the given input file.
"""
function build(;
    root::AbstractString = pwd(),
    input::AbstractString = "input.css",
    output::AbstractString = joinpath("dist", "output.css"),
)
    if isdir(root)
        config = joinpath(root, "tailwind.config.js")
        if isfile(config)
            cd(root) do
                if isfile(input)
                    if !isdir(dirname(output))
                        @info "'$(dirname(output))' directory does not exist. Creating..."
                        mkpath(dirname(output))
                    end
                    bin = tailwindcss()
                    @info "running tailwind build"
                    run(`$(bin) build --input $(input) --output $(output)`)
                    return nothing
                else
                    error("'$input' is not a file.")
                end
            end
        else
            error("Could not find 'tailwind.config.js' in '$root'.")
        end
    else
        error("'$root' is not a directory.")
    end
end

function default_on_change()
    @debug "tailwind build finished"
end

# Wrapper for better printing and user interaction with the watcher object.
struct Watcher
    f::Function
end

function Base.show(io::IO, w::Watcher)
    running = istaskstarted(w.f.task) && !istaskdone(w.f.task)
    print(io, "$(Watcher)(running = $running)")
end

Base.close(w::Watcher) = w.f()

"""
    watch(;
        root::AbstractString = pwd(),
        input::AbstractString = "input.css",
        output::AbstractString = joinpath("dist", "output.css"),
        after_rebuild::Function,
    ) -> Watcher

Runs `tailwindcss build --watch` in the given `root` directory, watching the
`input` file and writing to the `output` file in a similar fashion to the
`build` function. `after_rebuild` is called whenever the build finishes.  This
is a zero-argument function that can be used to run any code after the rebuild
finishes, such as browser auto-reloaders.

The returned `Watcher` object can be `close`d to stop the watcher.
"""
function watch(;
    root::AbstractString = pwd(),
    input::AbstractString = "input.css",
    output::AbstractString = joinpath("dist", "output.css"),
    after_rebuild::Function = default_on_change,
)
    if isdir(root)
        config = joinpath(root, "tailwind.config.js")
        if isfile(config)
            cd(root) do
                if isfile(input)
                    if !isdir(dirname(output))
                        @info "'$(dirname(output))' directory does not exist. Creating..."
                        mkpath(dirname(output))
                    end

                    bin = tailwindcss(; dir = pwd())

                    inp = Base.PipeEndpoint()
                    out = Base.PipeEndpoint()
                    err = Base.PipeEndpoint()

                    process = run(
                        `$(bin) build --watch --input $(input) --output $(output)`,
                        inp,
                        out,
                        err;
                        wait = false,
                    )

                    closed = Ref(false)
                    task = @async begin
                        @info "running tailwind watcher"
                        while !closed[] && process_running(process)
                            msg = strip(String(readavailable(err)))
                            if !isempty(msg)
                                if startswith(msg, "Done in ")
                                    after_rebuild()
                                elseif msg == "Rebuilding..."
                                    @debug "$msg"
                                else
                                    printstyled("\n$msg\n"; color = :red)
                                end
                            end
                        end
                        @info "tailwind watcher exited"
                    end

                    return Watcher() do
                        if closed[]
                            error("tailwind watcher already closed.")
                        else
                            closed[] = true
                            @info "closing tailwind watcher"
                            process_running(process) || Base.close(process)
                            Base.close(inp)
                            Base.close(out)
                            Base.close(err)
                            return wait(task)
                        end
                    end
                else
                    error("'$input' is not a file.")
                end
            end
        else
            error("Could not find 'tailwind.config.js' in '$root'.")
        end
    else
        error("'$root' is not a directory.")
    end
end

end # module TailwindCSS
