# 81_projection_overview_tests.jl — the projection() overview must not fall behind the code.
#
# `projection()` with no arguments prints the list of variables you can ask a projection for,
# and the docs treat it as the current list. It is hand-written, so it drifts: it once omitted
# every spherical velocity dispersion, and printed the dispersions without the leading colon
# that the rest of the same output uses, so a reader copying one wrote `σx` instead of `:σx`.
#
# `getvar()` has had this guard since the same thing happened there (80_getvar_overview_tests).

@testset "projection() overview lists every projectable variable" begin
    text = mktemp() do path, io
        redirect_stdout(projection, io)
        flush(io)
        read(path, String)
    end
    printed = Set(m.captures[1] for m in eachmatch(r":([A-Za-z_αβγθϕσΣρ][A-Za-z0-9_αβγθϕσΣρ²]*)", text))

    # every dispersion the projection code knows how to build
    for v in Mera._SIGMA_NAMES
        @test String(v) in printed
    end
    # the camera-frame kinematics, which exist off-axis only
    for v in Mera._CAM_KINEMATICS
        @test String(v) in printed
    end
    # the two counters
    @test "ncell" in printed
    @test "npart" in printed

    # EVERY dispersion must be written with its colon, like the rest of the output. Without it a
    # reader copies a bare name that is not a symbol.
    for v in Mera._SIGMA_NAMES
        @test occursin(":$(v)", text)
    end

    # and the output must say the box-frame set is box-frame, since that is the trap
    @test occursin("BOX", text) || occursin("box axes", text)
end
