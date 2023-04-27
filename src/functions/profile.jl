



function profile(  dataobject::DataSetType,
                    vars::Array{Symbol,1},
                    units::Array{Symbol,1},
                    hrange::AbstractRange{<:Number};
                    closed::Symbol=:left,
                    weighting::Symbol=:mass,
                    mapping::Symbol=:cell, #projection
                    center::Array{<:Any,1}=[0., 0., 0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    checkbins::Bool=false,
                    verbose::Bool=true)

    center = Mera.center_in_standardnotation(dataobject.info, center, center_unit)

    
    xquantity = getvar(dataobject, vars[1], units[1], center=center, mask=mask)
    yquantity = getvar(dataobject, vars[2], units[2], center=center, mask=mask)  
    
    if weighting != :missing
        wquantity = getvar(dataobject, weighting, center=center, mask=mask) 
        xhist = fit(Histogram, xquantity, weights(yquantity .* wquantity),  hrange )
        whist = fit(Histogram, xquantity, weights(wquantity),  hrange )
    else
        xhist = fit(Histogram, xquantity, weights(yquantity),  hrange )
        whist = fit(Histogram, xquantity, hrange )
    end

    profile = xhist.weights ./ whist.weights # average

    if closed==:left
        radius = hrange[1:end-1]
    elseif closed==:right
        radius = hrange[2:end]
    end

    if checkbins==true
        Nhist = fit(Histogram, xquantity,  hrange )
        return radius, profile, Nhist.weights
    else
        return radius, profile
    end
end