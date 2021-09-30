#!/usr/bin/env python

#
# Details popup animation path generator for Shock Lobster
#
# Copyright 2021 Dave VanEe
#
# This software is provided 'as-is', without any express or implied
# warranty.  In no event will the authors be held liable for any damages
# arising from the use of this software.
# 
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
# 
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#

import math

output = 'res/details_animation_path_generated.asm'

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

with open(output, 'w') as f:
    f.write('SECTION "Details Animation Path", ROMX, ALIGN[8]\n')
    f.write('; List of X coordiantes for each frame of the details popup animation\n')
    f.write('DetailsAnimationPath:\n')

    ANIMATION_FRAMES = 35
    ZERO_OFFSET = 0x40

    # Based on: https://physics.stackexchange.com/a/333436

    h0 = 80        # px
    v = 0          # px/s, current velocity
    g = 1          # px/s/s
    t = 0          # starting time
    #dt = 0.001     # time step
    dt = 1
    rho = 0.75     # coefficient of restitution
    tau = 0.10     # contact time for bounce
    hmax = h0      # keep track of the maximum height
    h = h0
    hstop = 1      # stop when bounce is less than 1 px
    freefall = True # state: freefall or in contact
    
    t_last = -math.sqrt(2*h0/g) # time we would have launched to get to h0 at t=0
    vmax = math.sqrt(2 * hmax * g)
    H = []
    T = []
    while(hmax > hstop):
        if(freefall):
            hnew = h + v*dt - 0.5*g*dt*dt
            if(hnew<0):
                t = t_last + 2*math.sqrt(2*hmax/g)
                freefall = False
                t_last = t + tau
                h = 0
            else:
                t = t + dt
                v = v - g*dt
                h = hnew
        else:
            t = t + tau
            vmax = vmax * rho
            v = vmax
            freefall = True
            h = 0
        hmax = 0.5*vmax*vmax/g
        H.append(ZERO_OFFSET + h)
        T.append(t)

    # Written out in reverse so we can use the pointer low byte as an active flag as well
    print(len(H))
    for chunk in chunks(list(reversed(H)), 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))

    f.write('.end')

    import matplotlib.pyplot as plt
    import numpy as np

    fix, ax = plt.subplots()
    frames = [item for item in range(ANIMATION_FRAMES)]
    ax.plot(T, H, 'o-')
    plt.show()