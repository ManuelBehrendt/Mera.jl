function btest(i::Int,pos::Int)
  return  (((i)>>(pos)) & 1)  == 1
end

function hilbert3d(x::Int,y::Int,z::Int,bit_length::Int,npoint::Int)


state_diagram = [  1, 2, 3, 2, 4, 5, 3, 5,
                   0, 1, 3, 2, 7, 6, 4, 5,
                   2, 6, 0, 7, 8, 8, 0, 7,
                   0, 7, 1, 6, 3, 4, 2, 5,
                   0, 9,10, 9, 1, 1,11,11,
                   0, 3, 7, 4, 1, 2, 6, 5,
                   6, 0, 6,11, 9, 0, 9, 8,
                   2, 3, 1, 0, 5, 4, 6, 7,
                   11,11, 0, 7, 5, 9, 0, 7,
                   4, 3, 5, 2, 7, 0, 6, 1,
                   4, 4, 8, 8, 0, 6,10, 6,
                   6, 5, 1, 2, 7, 4, 0, 3,
                   5, 7, 5, 3, 1, 1,11,11,
                   4, 7, 3, 0, 5, 6, 2, 1,
                   6, 1, 6,10, 9, 4, 9,10,
                   6, 7, 5, 4, 1, 0, 2, 3,
                   10, 3, 1, 1,10, 3, 5, 9,
                   2, 5, 3, 4, 1, 6, 0, 7,
                   4, 4, 8, 8, 2, 7, 2, 3,
                   2, 1, 5, 6, 3, 0, 4, 7,
                   7, 2,11, 2, 7, 5, 8, 5,
                   4, 5, 7, 6, 3, 2, 0, 1,
                   10, 3, 2, 6,10, 3, 4, 4,
                   6, 1, 7, 0, 5, 2, 4, 3 ]
state_diagram = reshape(state_diagram, 8 ,2, 12)

x_bit_mask = falses(bit_length)
y_bit_mask = falses(bit_length)
z_bit_mask = falses(bit_length)

i_bit_mask = falses(3*bit_length)


order=0.     #zeros(npoint); npoint=1, therefore no array

#for ip=1:npoint
  # convert to binary
  for i=1:bit_length
    x_bit_mask[i]=btest(x,i-1)
    y_bit_mask[i]=btest(y,i-1)
    z_bit_mask[i]=btest(z,i-1)
  end

  # interleave bits
  for i=0:(bit_length-1)
    i_bit_mask[3*i+2+1]=x_bit_mask[i+1]
    i_bit_mask[3*i+1+1]=y_bit_mask[i+1]
    i_bit_mask[3*i+1]=z_bit_mask[i+1]

  end

  # build Hilbert ordering using state diagram
  cstate=0
  staterange = range(bit_length-1, stop=0, step=-1)
  for i in staterange
    #println(i)

    if i_bit_mask[3*i+2+1] b2=1 else b2=0 end
    if i_bit_mask[3*i+1+1] b1=1 else b1=0 end
    if i_bit_mask[3*i+1]   b0=1 else b0=0 end

    sdigit=b2*4+b1*2+b0
    nstate=state_diagram[sdigit+1,1,cstate+1]
    hdigit=state_diagram[sdigit+1,2,cstate+1]
    #println("nstate: ", nstate)
    #println("hdigit: ", hdigit)
    i_bit_mask[3*i+2+1]=btest(hdigit,2)
    i_bit_mask[3*i+1+1]=btest(hdigit,1)
    i_bit_mask[3*i+1]  =btest(hdigit,0)
    #println("i_bit_mask: ", i_bit_mask[3*i+2+1])
    #println("i_bit_mask: ", i_bit_mask[3*i+1+1])
    #println("i_bit_mask: ", i_bit_mask[3*i+1])
    cstate=nstate
  end

  # save Hilbert key as double precision real
  #order[ip]=0.
  order=0.     #zeros(npoint); npoint=1, therefore no array
  for i=1:(3*bit_length)
    if i_bit_mask[i] b0=1 else b0=0 end
    #order[ip]=order[ip]+b0*2^i
    order=order+b0*2^(i-1)
    #println(i-1, " ", order[ip])
  end

#end
    return order
end
