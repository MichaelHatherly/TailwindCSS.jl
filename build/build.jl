import Pkg
import Base.Sys
import SHA
import URIs

pkgname = "tailwindcss"
build = 0

tailwind_url_latest = "https://github.com/tailwindlabs/tailwindcss/releases/latest/download"

sha256sums = "$(tailwind_url_latest)/sha256sums.txt"

sha256sums_file = download(sha256sums)

function host_platform()
    OS =
        Sys.isapple() ? Pkg.BinaryPlatforms.MacOS :
        Sys.islinux() ? Pkg.BinaryPlatforms.Linux :
        Sys.iswindows() ? Pkg.BinaryPlatforms.Windows : error("unknown host platform.")
    return OS(Sys.ARCH)
end

function platform_mapping(file::AbstractString)
    platform_regex = r"(linux|macos|windows)-(arm64|armv7|x64)"
    m = match(platform_regex, file)
    m === nothing && error("unknown platform '$file'.")

    os = Symbol(m[1])
    arch = Symbol(m[2])

    arch_aliases = (x64 = :x86_64,)

    arch = get(arch_aliases, arch, arch)

    os === :windows && return Pkg.BinaryPlatforms.Windows(arch)
    os === :macos && return Pkg.BinaryPlatforms.MacOS(arch)
    os === :linux && return Pkg.BinaryPlatforms.Linux(arch)

    error("unknown platform '$file'.")
end

function find_version()
    host = host_platform()
    version = nothing
    for line in eachline(sha256sums_file)
        sha, file = strip.(split(line, ' '; limit = 2))
        platform = platform_mapping(file)
        if platform == host
            @info "Downloading binary" file
            url = "$(tailwind_url_latest)/$file"
            downloaded_file = download(url)
            @info "Verifying binary" file
            downloaded_sha = bytes2hex(SHA.sha256(open(downloaded_file)))
            @info "SHA256" downloaded_sha sha
            if downloaded_sha != sha
                error("SHA256 mismatch for $file, expected $sha, got $downloaded_sha.")
            end
            chmod(downloaded_file, 0o777)
            help_string = readchomp(`$downloaded_file --help`)
            version_regex = r"tailwindcss v([0-9]+\.[0-9]+\.[0-9]+)"
            m = match(version_regex, help_string)
            m === nothing && error("Could not parse version from help string '$help_string'.")
            version_string = m[1]
            version = VersionNumber(version_string)
            break
        end
    end

    if version === nothing
        error("No binary found for platform $host.")
    end

    # Write to github actions outputs
    name = "tailwindcss_version"
    value = "tailwindcss-$(version)+$(build)"
    if haskey(ENV, "GITHUB_OUTPUT")
        @info "Writing to GitHub Actions output" name value
        open(strip(ENV["GITHUB_OUTPUT"]), "a") do io
            println(io, "$(name)=$(value)")
        end
    else
        @warn "GITHUB_OUTPUT not set, not writing to output." name value
    end

    return version
end


versioned_url(version::VersionNumber, file::AbstractString) =
    "https://github.com/tailwindlabs/tailwindcss/releases/download/v$(version)/$(file)"

function create_artifacts()
    version = find_version()
    build_path = joinpath(@__DIR__, "artifacts")

    ispath(build_path) && rm(build_path; recursive = true, force = true)

    mkpath(build_path)

    artifact_toml = joinpath(@__DIR__, "..", "Artifacts.toml")
    isfile(artifact_toml) && rm(artifact_toml)
    touch(artifact_toml)

    for line in eachline(sha256sums_file)
        sha, file = strip.(split(line, ' '; limit = 2))

        platform = platform_mapping(file)
        url = versioned_url(version, file)

        product_hash = Pkg.Artifacts.create_artifact() do artifact_dir
            _, ext = splitext(file)
            downloaded_file = joinpath(artifact_dir, "tailwindcss$ext")

            @info "Downloading binary" downloaded_file
            download(url, downloaded_file)

            @info "Verifying binary" file
            downloaded_sha = bytes2hex(SHA.sha256(open(downloaded_file)))

            @info "SHA256" downloaded_sha sha
            downloaded_sha == sha ||
                error("SHA256 mismatch for $file, expected $sha, got $downloaded_sha.")

            @info "Setting permissions to 777" downloaded_file
            chmod(downloaded_file, 0o777)

            files = readdir(artifact_dir)
            @show files
        end
        archive_filename = "$pkgname-$version+$build-$(Pkg.BinaryPlatforms.triplet(platform)).tar.gz"
        download_hash =
            Pkg.Artifacts.archive_artifact(product_hash, joinpath(build_path, archive_filename))
        @info "product hash" product_hash

        @info "binding" archive_filename
        Pkg.Artifacts.bind_artifact!(
            artifact_toml,
            "tailwindcss",
            product_hash,
            platform = platform,
            force = true,
            download_info = Tuple[(
                "https://github.com/MichaelHatherly/TailwindCSS.jl/releases/download/tailwindcss-$(URIs.escapeuri("$(version)+$(build)"))/$archive_filename",
                download_hash,
            )],
        )
    end
end

create_artifacts()
