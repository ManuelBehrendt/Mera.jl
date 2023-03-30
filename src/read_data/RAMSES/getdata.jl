# - wrapper for read_merafile, gethydro, getgravity, getparticles, getclumps, get....

# Wrapper for read_merafile ================================================
function getdata(filename::String, datatype::Symbol;

                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,

                        printfields::Bool=false,
                        verbose::Bool=verbose_mode)

        return read_merafile(filename=filename,
                        datatype=datatype,
                        xrange=xrange,
                        yrange=yrange,
                        zrange=zrange,
                        center=center,
                        range_unit=range_unit,
                        printfields=printfields,
                        verbose=verbose)
end


function getdata(filename::String;
                        datatype::Symbol=:hydro,

                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,

                        printfields::Bool=false,
                        verbose::Bool=verbose_mode)

        return read_merafile(filename=filename,
                        datatype=datatype,
                        xrange=xrange,
                        yrange=yrange,
                        zrange=zrange,
                        center=center,
                        range_unit=range_unit,
                        printfields=printfields,
                        verbose=verbose)
end



function getdata(;
                        filename::String="",
                        datatype::Symbol=:hydro,

                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,

                        printfields::Bool=false,
                        verbose::Bool=verbose_mode)


        return read_merafile(filename=filename,
                        datatype=datatype,
                        xrange=xrange,
                        yrange=yrange,
                        zrange=zrange,
                        center=center,
                        range_unit=range_unit,
                        printfields=printfields,
                        verbose=verbose)
end
# ==========================================================================


# Wrapper for gethydro =====================================================
function getdata( dataobject::InfoType, datatype::Symbol,  var::Symbol;
                    lmax::Real=dataobject.levelmax,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    check_negvalues::Bool=false,
                    print_filenames::Bool=false,
                    verbose::Bool=verbose_mode )
                    #, progressbar::Bool=show_progressbar)

    if datatype == :hydro
        return gethydro(dataobject, vars=[var],
                        lmax=lmax,
                        xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                        range_unit=range_unit,
                        smallr=smallr,
                        smallc=smallc,
                        check_negvalues=check_negvalues,
                        print_filenames=print_filenames,
                        verbose=verbose)
    end
end


function getdata( dataobject::InfoType, datatype::Symbol, vars::Array{Symbol,1};
                    lmax::Real=dataobject.levelmax,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    check_negvalues::Bool=false,
                    print_filenames::Bool=false,
                    verbose::Bool=verbose_mode )
                    #, progressbar::Bool=show_progressbar)

    if datatype == :hydro
        return gethydro(dataobject,
                        vars=vars,
                        lmax=lmax,
                        xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                        range_unit=range_unit,
                        smallr=smallr,
                        smallc=smallc,
                        check_negvalues=check_negvalues,
                        print_filenames=print_filenames,
                        verbose=verbose)
    end
end



function getdata( dataobject::InfoType, datatype::Symbol;
                    lmax::Real=dataobject.levelmax,
                    vars::Array{Symbol,1}=[:all],
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    check_negvalues::Bool=false,
                    print_filenames::Bool=false,
                    verbose::Bool=verbose_mode )

    if datatype == :hydro
        return gethydro(dataobject,
                        vars=vars,
                        lmax=lmax,
                        xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                        range_unit=range_unit,
                        smallr=smallr,
                        smallc=smallc,
                        check_negvalues=check_negvalues,
                        print_filenames=print_filenames,
                        verbose=verbose)
    end
end
# ==========================================================================



# Wrapper for getinfo and gethydro =====================================================
