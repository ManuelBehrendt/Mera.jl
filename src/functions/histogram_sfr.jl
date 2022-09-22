
# trange "Myr"
# tbins "Myr"
function sfr_histogram(dataobject::PartDataType;

                        trange::Array{<:Any,1}=[0., missing],
                        tbinsize::Any=missing,
                        tbins::Any=missing,
                        closed::Symbol=:left,
                        mask=[false],
                        mode::Symbol=:none,

                        verbose::Bool=true)

        verbose = checkverbose(verbose)
        massweight = map(row->particle_selection(row.birth, row.mass, dataobject.scale.Msol), dataobject.data);
        birth = getvar(dataobject, :birth, :Myr)

        if trange[2] === missing trange[2] = maximum(birth) end # Myr

        if tbins === missing # dominates over tbinsize
            if tbinsize === missing tbinsize = 2. end #Myr
            timerange = trange[1]:tbinsize:trange[2]
        else
            timerange = range(trange[1], stop=trange[2], length=tbins)
        end

        if verbose
            if closed == :left
                println("bin interval left-closed [a,b)  (default):")
            elseif closed == :right
                println("bin interval right-closed (a,b]:")
            end

            println("trange: ", timerange, " [Myr]\t -> bins:",length(timerange))
            println()
        end



        if length(mask) > 1
            rows = length(dataobject.data)
            if length(mask) !== rows
                error("[Mera] ",now()," : array-mask length: $(length(mask)) does not match with data-table length: $(rows)")

            else
                h = StatsBase.fit(Histogram, birth, weights(massweight .* mask), closed=closed, timerange)
            end
        else
            h = StatsBase.fit(Histogram, birth, weights(massweight), closed=closed, timerange)
        end

        h = StatsBase.normalize(h; mode=mode)
        sfh = h.weights
        xaxis = collect(h.edges[1])[1:end-1]
        hstep = timerange[2]-timerange[1]

        return xaxis, sfh ./ 1e6 ./ hstep   #[Myr], [Msol/yr]
end




function particle_selection(birth, mass, Msol)
    if birth > 0. #id == 0
        return mass * Msol
    else
        return 0.
    end
end
