#!/usr/bin/env python

#
# Logo animation path generator for Shock Lobster
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

output = 'res/logo_animation_paths_generated.asm'

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

with open(output, 'w') as f:
    f.write('SECTION "Logo Animation Paths", ROMX, ALIGN[7]\n')
    f.write('; List of X coordiantes for each frame of the logo animation\n')
    f.write('SpriteAnimationPath:\n')

    ANIMATION_FRAMES = 35
    ORIGIN_X = 0x88

    x = []
    lookupValues = []
    for frame in range(ANIMATION_FRAMES):
        x.append(int(ORIGIN_X + (frame/3.0-4)**2) - 16)
        lookupValues.append(x[-1])

    print(len(lookupValues))
    for chunk in chunks(lookupValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))

    f.write('.end')

    f.write('\n\n; List of SCX coordiantes for each frame of the logo animation\n')
    f.write('SplitAnimationPath:\n')

    START_DELAY = 16
    END_CLIP = 22
    ANIMATION_FRAMES = int(144/2) - START_DELAY - 22

    x = []
    lookupValues = []
    for frame in range(ANIMATION_FRAMES):
        x.append(int((16*(math.sin(frame/4.0-math.pi/2)+1))+frame/0.6))
        lookupValues.append(x[-1])

    print(len(lookupValues))
    for chunk in chunks(lookupValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))

    f.write('.end')

    # import matplotlib.pyplot as plt
    # import numpy as np

    # fix, ax = plt.subplots()
    # frames = [item for item in range(ANIMATION_FRAMES)]
    # ax.plot(x, frames, 'o-')
    # plt.show()