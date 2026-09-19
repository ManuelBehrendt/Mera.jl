# getvar support for the sink catalogue.
#
# Sinks are point masses: there is no cell geometry, no AMR level, no volume. So this is much
# shorter than the hydro/gravity/RT paths — every stored column is returned with its unit applied,
# plus the few derived quantities that make sense for a point mass (speed, kinetic energy, radius
# from a chosen centre, specific angular momentum magnitude).
#
# RAMSES writes the sink positions in code units, like the cell positions, so `center` behaves the
# same way here as elsewhere: it shifts the origin.

function get_data(dataobject::SinkDataType,
                  vars::Array{Symbol,1},
                  units::Array{Symbol,1},
                  direction::Symbol,
                  center::CenterType,
                  mask::MaskType,
                  ref_time::Real)

    vars_dict = Dict()
    boxlen = dataobject.boxlen
    cols   = propertynames(dataobject.data.columns)

    # the direction convention matches the other readers: :z is the identity
    apos, bpos, cpos = direction == :z ? (:x, :y, :z) :
                       direction == :y ? (:z, :x, :y) : (:z, :y, :x)
    avel, bvel, cvel = direction == :z ? (:vx, :vy, :vz) :
                       direction == :y ? (:vz, :vx, :vy) : (:vz, :vy, :vx)

    has(c) = in(c, cols)

    for i in vars
        if has(i)
            selected_unit = getunit(dataobject, i, vars, units)
            if     i == :x;  vars_dict[i] = (select(dataobject.data, apos) .- boxlen * center[1]) .* selected_unit
            elseif i == :y;  vars_dict[i] = (select(dataobject.data, bpos) .- boxlen * center[2]) .* selected_unit
            elseif i == :z;  vars_dict[i] = (select(dataobject.data, cpos) .- boxlen * center[3]) .* selected_unit
            elseif i == :vx; vars_dict[i] =  select(dataobject.data, avel) .* selected_unit
            elseif i == :vy; vars_dict[i] =  select(dataobject.data, bvel) .* selected_unit
            elseif i == :vz; vars_dict[i] =  select(dataobject.data, cvel) .* selected_unit
            else             vars_dict[i] =  select(dataobject.data, i)    .* selected_unit
            end

        # `:mass` is the generic name the rest of Mera uses; RAMSES calls the column `msink`.
        elseif i == :mass && has(:msink)
            selected_unit = getunit(dataobject, :mass, vars, units)
            vars_dict[:mass] = select(dataobject.data, :msink) .* selected_unit

        elseif i == :v && has(:vx)
            selected_unit = getunit(dataobject, :v, vars, units)
            vars_dict[:v] = sqrt.(select(dataobject.data, :vx).^2 .+
                                  select(dataobject.data, :vy).^2 .+
                                  select(dataobject.data, :vz).^2) .* selected_unit

        elseif i == :ekin && has(:vx) && has(:msink)
            selected_unit = getunit(dataobject, :ekin, vars, units)
            vars_dict[:ekin] = 0.5 .* select(dataobject.data, :msink) .*
                               (select(dataobject.data, :vx).^2 .+
                                select(dataobject.data, :vy).^2 .+
                                select(dataobject.data, :vz).^2) .* selected_unit

        # distance of each sink from `center`
        elseif (i == :r_sphere || i == :r_cylinder) && has(:x)
            selected_unit = getunit(dataobject, i, vars, units)
            dx = select(dataobject.data, :x) .- boxlen * center[1]
            dy = select(dataobject.data, :y) .- boxlen * center[2]
            vars_dict[i] = if i == :r_cylinder
                sqrt.(dx.^2 .+ dy.^2) .* selected_unit
            else
                dz = select(dataobject.data, :z) .- boxlen * center[3]
                sqrt.(dx.^2 .+ dy.^2 .+ dz.^2) .* selected_unit
            end

        # magnitude of the spin RAMSES accumulates on each sink
        elseif i == :l && has(:lx)
            selected_unit = getunit(dataobject, :l, vars, units)
            vars_dict[:l] = sqrt.(select(dataobject.data, :lx).^2 .+
                                  select(dataobject.data, :ly).^2 .+
                                  select(dataobject.data, :lz).^2) .* selected_unit
        end
    end

    if length(mask) > 1
        for i in keys(vars_dict)
            vars_dict[i] = vars_dict[i][mask]
        end
    end

    for v in vars
        haskey(vars_dict, v) || _unknown_var_error(dataobject, v)
    end

    return length(vars) == 1 ? vars_dict[vars[1]] : vars_dict
end
