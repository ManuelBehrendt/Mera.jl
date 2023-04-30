


function checktypes_error(output, path, datatype)
    info = getinfo(output, path, verbose=false)
    
    info.hydro      = false
    info.particles  = false
    info.gravity    = false
    info.amr        = false
    info.rt         = false
    info.clumps     = false
    info.sinks      = false

    if datatype == :hydro
        @test gethydro(info)
    elseif datatype == :particles
        @test getparticles(info)
    elseif datatype == :gravity
        @test getgravity(info)
    elseif datatype == :clumps
        @test getclumps(info)
    elseif datatype == :amr
        @test Mera.checkfortype(info, :amr)
    elseif datatype == :rt
        @test Mera.checkfortype(info, :rt)
    elseif datatype == :sinks
        @test Mera.checkfortype(info, :sinks)
    end

    return true
end




function checklevelmax_error(output, path)
    info = getinfo(output, path, verbose=false)
    gas = gethydro(info, lmax=10)
    return true
end

function checklevelmin_error(output, path)
    info = getinfo(output, path, verbose=false)
    gas = gethydro(info, lmax=1)
    return true
end