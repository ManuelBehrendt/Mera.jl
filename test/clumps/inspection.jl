function clumps_dataoverview(output, path)
    info =getinfo(output, path)
    clumps = getclumps(info)
    dataoverview(clumps)
    return true
end

function clumps_gettime(output, path)
    info =getinfo(output, path)
    clumps = getclumps(info)
    return gettime(info, :Myr) == gettime(clumps, :Myr)
end