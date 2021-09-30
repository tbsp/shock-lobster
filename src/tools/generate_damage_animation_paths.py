#!/usr/bin/env python

#
# Damage animation path generator for Shock Lobster
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

output = 'res/damage_animation_paths_generated.asm'

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

ANIMATION_FRAMES = 40
ANIMATION_PATH_TERMINATOR = 0xFF

LABEL = 'DAMAGE_TEXT_ANIMATIONS'

with open(output, 'w') as f:
    f.write('DEF ANIMATION_PATH_TERMINATOR EQU $FF\n')
    f.write('SECTION "Damage Text Animation Tables", ROMX, ALIGN[8]\n')
    f.write('; Lists of Y/X offsets for each frame of damage text display (DAMAGE_TEXT_FRAMES*2)\n')
    f.write(f'{LABEL}:\n')

    # hits
    dx = []
    dy = []
    lookupValues = []
    for frame in range(ANIMATION_FRAMES):
        dy.append(int((frame/4-4)**2+16))
        dx.append(int(frame/ANIMATION_FRAMES * 16))
        lookupValues.append(dy[-1])
        lookupValues.append(dx[-1])

    print(len(lookupValues))
    f.write('.hit\n')
    for chunk in chunks(lookupValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))

    # crits
    ANIMATION_FRAMES = 13 # the function we use stabalizes after this many frames
    dx = []
    dy = []
    lookupValues = []
    for frame in range(ANIMATION_FRAMES):
        dy.append(8)
        dx.append(int(8*math.exp(-(1/6*frame))*math.cos(2*frame)))
        lookupValues.append(dy[-1])
        lookupValues.append(dx[-1])

    print(len(lookupValues))
    f.write('.crit\n')
    for chunk in chunks(lookupValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
    f.write(f'    db ANIMATION_PATH_TERMINATOR\n')

    # buffs
    ANIMATION_FRAMES = 15 # the function we use stabalizes after this many frames
    dx = []
    dy = []
    lookupValues = []
    for frame in range(ANIMATION_FRAMES):
        dy.append(int(16*math.exp(-(0.2*frame))))
        dx.append(0)
        lookupValues.append(dy[-1])
        lookupValues.append(dx[-1])

    print(len(lookupValues))
    f.write('.buff\n')
    for chunk in chunks(lookupValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
    f.write(f'    db ANIMATION_PATH_TERMINATOR\n')

    # skill activation
    lookupValues = [0, 0]
    print(len(lookupValues))
    f.write('.skillActivation\n')
    for chunk in chunks(lookupValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
    f.write(f'    db ANIMATION_PATH_TERMINATOR\n')

    f.write('.end\n')
    f.write(f'ASSERT({LABEL}.end - {LABEL} <= 256)\n')

    #import matplotlib.pyplot as plt
    #import numpy as np

    #fix, ax = plt.subplots()
    #ax.plot(dx, dy, 'o-')
    #plt.show()