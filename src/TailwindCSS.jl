module TailwindCSS

using Artifacts

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

end # module TailwindCSS
