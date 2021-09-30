#!/usr/bin/env python

#
# Enemy animation path generator for Shock Lobster
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

output = 'res/enemy_animation_paths_generated.asm'

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

# Values to show the enemy in the top-left-most position
BASE_LY = 12
BASE_WX = 128+7

LY_RANGE = 24 # Full vertical range of movement
WX_RANGE = 30 # Due to a window bug we must leave at least 2 pixels on screen!

TERMINATOR = 'ENEMY_PATH_TERMINATED'
LOOP = 'ENEMY_PATH_LOOP'

LABEL = 'EnemyAnimationPaths'

with open(output, 'w') as f:
    f.write(f'DEF {TERMINATOR} EQU $FF\n')
    f.write(f'DEF {LOOP} EQU $FE\n')
    f.write('SECTION "Enemy Animation Paths", ROMX\n')
    f.write('; Lookup tables of LY/WX pairs which are stepped through in order to animate\n')
    f.write(';  the position of the enemy.\n')
    f.write(f'{LABEL}:\n')

    # spawning
    ANIMATION_FRAMES = 15
    wx = []
    ly = []
    lookupValues = []
    for frame in range(ANIMATION_FRAMES+1):
        if frame < 10:
            # Slow start
            ly.append(BASE_LY + 6 + ((frame - 10) / 4)**2)
        else:
            # Faster end
            ly.append(BASE_LY + 6 + ((frame - 10) / 2)**2)

        wx.append(BASE_WX + (ANIMATION_FRAMES - frame) / ANIMATION_FRAMES * WX_RANGE)

        lookupValues.append(ly[-1])
        lookupValues.append(wx[-1])

    f.write('.spawning\n')
    print('spawning')
    print(len(lookupValues))
    for chunk in chunks(lookupValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))

    # None state terminated path doubling as spawning terminator
    f.write('.terminated\n')
    f.write(f'    db {TERMINATOR}\n')
    print('.terminated')
    print(f'    db {TERMINATOR}')

    # despawning
    # Include a "super recoil" on death, since the recoil from the killing blow
    #  will be overwritten anyways, and it makes death more epic. Note that since
    #  enemy animations are updated every 3 frames, this also gives us 6*3-2 (16)
    #  safe laser frames before vertical movement could cause raster issues.
    ANIMATION_FRAMES = 6
    wx = []
    ly = []
    lookupValues = []
    for frame in range(ANIMATION_FRAMES+1):
        ly.append(BASE_LY + LY_RANGE/2.0) # vertically centered
        wx.append(BASE_WX - math.sin(2*frame-3.2)*math.exp(-0.5*frame+3.2))
        lookupValues.append(ly[-1])
        lookupValues.append(wx[-1])

    ANIMATION_FRAMES = 20
    for frame in range(ANIMATION_FRAMES+1):
        ly.append(BASE_LY - 8 * math.sin(frame) * math.exp(-frame/8) + 10 + frame/7.0)
        wx.append(BASE_WX + frame / ANIMATION_FRAMES * WX_RANGE)
        lookupValues.append(ly[-1])
        lookupValues.append(wx[-1])

    f.write('.despawning\n')
    print('despawning')
    print(len(lookupValues))
    for chunk in chunks(lookupValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
    f.write(f'    db {TERMINATOR}\n')

    # idle float (static for now until I find a way to make idle paths not annoying)
    ANIMATION_FRAMES = 0
    wx = []
    ly = []
    lookupValues = []
    for frame in range(ANIMATION_FRAMES+1):
        #ly.append(BASE_LY + LY_RANGE/2.0 + LY_RANGE/6.0 * math.sin(frame * math.pi/(ANIMATION_FRAMES/4.0)))
        #wx.append(BASE_WX + WX_RANGE/16.0 * math.sin(frame * math.pi/(ANIMATION_FRAMES/2.0)))
        ly.append(BASE_LY + LY_RANGE/2.0)
        wx.append(BASE_WX)
        lookupValues.append(ly[-1])
        lookupValues.append(wx[-1])
    loopOffset = 0xFF & (-len(lookupValues) - 1)

    f.write('.idleFloat\n')
    print('idleFloat')
    print(len(lookupValues))
    for chunk in chunks(lookupValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
    f.write(f'    db {LOOP}, ${loopOffset:02X}\n')

    # recoil large
    ANIMATION_FRAMES = 3
    wx = []
    ly = []
    lookupValues = []
    for frame in range(ANIMATION_FRAMES+1):
        ly.append(BASE_LY + LY_RANGE/2.0) # vertically centered
        wx.append(BASE_WX - math.sin(frame-3.2)*math.exp(-frame+3.2))
        lookupValues.append(ly[-1])
        lookupValues.append(wx[-1])

    f.write('.recoilLarge\n')
    print('recoilLarge')
    print(len(lookupValues))
    for chunk in chunks(lookupValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
    f.write(f'    db {TERMINATOR}\n')

    # recoil small
    ANIMATION_FRAMES = 3
    wx = []
    ly = []
    lookupValues = []
    for frame in range(ANIMATION_FRAMES+1):
        ly.append(BASE_LY + LY_RANGE/2.0) # vertically centered
        #ly.append(frame)
        wx.append(BASE_WX - 0.5 * math.sin(frame-3.2) * math.exp(-frame+3.2))
        lookupValues.append(ly[-1])
        lookupValues.append(wx[-1])

    f.write('.recoilSmall\n')
    print('recoilSmall')
    print(len(lookupValues))
    for chunk in chunks(lookupValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
    f.write(f'    db {TERMINATOR}\n')

    f.write('.end\n')
    #f.write(f'ASSERT({LABEL}.end - {LABEL} <= 256)\n')

    # import matplotlib.pyplot as plt
    # import numpy as np

    # fix, ax = plt.subplots()
    # ax.plot(wx, ly, 'o-')
    # plt.show()
