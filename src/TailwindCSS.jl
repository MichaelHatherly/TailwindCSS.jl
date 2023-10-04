module TailwindCSS

using Artifacts
import BetterFileWatching

export tailwindcss

"""
    tailwindcss() -> Cmd

Return a `Cmd` object that can be used to run the `tailwindcss` executable.

# Examples

```julia
julia> run(`$(tailwindcss()) --help`)

```
"""
function tailwindcss()
    path = joinpath(artifact"tailwindcss", "tailwindcss$(Sys.iswindows() ? ".exe" : "")")
    return Cmd(Cmd([path]); env = copy(ENV)) # Somewhat replicating JLLWrapper behavior.
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
function help()
    init = readchomp(`$(tailwindcss()) init --help`)
    build = readchomp(`$(tailwindcss()) build --help`)
    println(stdout, init, build)
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

function watch(;
    root::AbstractString,
    input::AbstractString,
    output::AbstractString,
    refresh::Function,
)
    BetterFileWatching.watch_folder(root) do event
        @debug "file watch event" event
        if output ∉ event.paths
            # Only rebuild the tailwind output file if it isn't what triggered
            # the event. If we did then we'd get stuck in a loop of rebuilding
            # the output file.
            TailwindCSS.build(; root, input, output)
        end
        refresh()
    end
end

end # module TailwindCSS
