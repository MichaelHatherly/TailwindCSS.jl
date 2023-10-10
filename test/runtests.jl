using TailwindCSS
using Test

@testset "TailwindCSS" begin
    @test TailwindCSS.version() isa VersionNumber
    @test !isempty(sprint(TailwindCSS.help))
    mktempdir() do dir
        cd(dir) do
            # Initialize the config.
            TailwindCSS.init()
            @test isfile("tailwind.config.js")

            # Update the config.
            write(
                "tailwind.config.js",
                """
                /** @type {import('tailwindcss').Config} */
                module.exports = {
                  content: ["./src/**/*.{html,js}"],
                  theme: {
                    extend: {},
                  },
                  plugins: [],
                }
                """,
            )

            mkdir("src")

            # Add the base css
            write(
                "src/input.css",
                """
                @tailwind base;
                @tailwind components;
                @tailwind utilities;
                """,
            )

            # Add a test html file.
            write(
                "src/index.html",
                """
                <!doctype html>
                <html>
                <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <link href="/dist/output.css" rel="stylesheet">
                </head>
                <body>
                  <h1 class="text-3xl font-bold underline">
                    Hello world!
                  </h1>
                </body>
                </html>
                """,
            )

            @test !isfile("dist/output.css")

            TailwindCSS.build(; input = "src/input.css")

            @test isfile("dist/output.css")

            # Check that the output css contains the expected class.
            let output_css = read("dist/output.css", String)
                @test occursin("--tw", output_css)
                @test occursin("text-3xl", output_css)
                @test occursin("font-bold", output_css)
                @test occursin("underline", output_css)
            end
        end
    end
end
