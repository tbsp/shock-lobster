#!/usr/bin/env python

#
# Obstacle animation path generator for Shock Lobster
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
import numpy as np
from scipy import interpolate


PLOT_PATHS = False

# If we want to store a range of -2 to +1 (instead of -1 to +2), set the
#  PACK_OFFSET to 1 (and uncomment the `dec a` in the unpack code).
PACK_OFFSET = 0

output = 'res/obstacle_animation_paths_generated.asm'

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

def generateSplineDelta(xCoords, yCoords, targetSumDY=0):
    """Generate a list of dY/dX pairs for the given coordinates"""
    
    data = np.array((xCoords, yCoords))

    tck, u = interpolate.splprep(data)#, s=0)
    unew = np.arange(0, 1.01, 1.0/ANIMATION_FRAMES)
    out = interpolate.splev(unew, tck)
    outInt = np.rint(out)

    minY = min(outInt[1])
    maxY = max(outInt[1])
    xRange = max(outInt[0]) - min(outInt[0])

    print(f'Min Y: {minY}, Max Y: {maxY}, xRange: {xRange}, xRate: {xRange/ANIMATION_FRAMES}')

    lookupValues = []
    for index in range(1, len(out[0])):
        lookupValues.append(-(outInt[1][index] - outInt[1][index-1]))
        lookupValues.append(outInt[0][index] - outInt[0][index-1])

    dYs = lookupValues[::2]
    dXs = lookupValues[1::2]
    print(f'Total dY: {sum(dYs)} [{targetSumDY}], dX: {sum(dXs)}')

    # Ensure vertical drift is the required amount
    assert sum(dYs) == targetSumDY

    # Ensure all delta values will fit in the 2bit compression scheme
    if PACK_OFFSET == 0:
        assert(min(lookupValues) >= -1)
        assert(max(lookupValues) <= 2)
    elif PACK_OFFSET == 1:
        assert(min(lookupValues) >= -2)
        assert(max(lookupValues) <= 1)

    if PLOT_PATHS:
        import matplotlib.pyplot as plt

        fix, ax = plt.subplots()
        ax.plot(out[0], out[1], 'x-')
        ax.plot(outInt[0], outInt[1], 'or')
        ax.plot(data[0,:], data[1,:], 'ob')
        plt.show()

        # Used to debug delta issues
        #fix, ax = plt.subplots()
        #ax.plot(np.arange(len(dXs)), dXs, 'og')
        #ax.plot(np.arange(len(dYs)), dYs, 'om')
        #plt.show()

    return lookupValues


# All paths are 64 entries so we can AND the pointer low byte to loop them
ANIMATION_FRAMES = 64
PER_INDEX_OFFSET = 16 / 4

pathData = []

# Jump tolerances:
# - 48 frames in a jump where the player is above the collision Y coordinate
# - Obstacles move (40*scale)/64 pixels per frame
# - Horizontal collisions use a 14 pixel box
# - The 'safety margin' is therefore:
#   48 * (40*scale/64) - 14
#   scale = 1.0, margin ~= 16
#   scale = 1.1, margin ~= 19
#   scale = 1.2, margin ~= 22
#   scale = 1.3, margin ~= 25

# Without the High Pressure upgrade, the player spends only 41 frames above
#  the collision Y coordinate, giving the following margins of safety:
#   41 * (40*scale/64) - 14
#   scale = 1.0, margin ~= 11.625
#   scale = 1.1, margin ~= 14.1875
#   scale = 1.2, margin ~= 16.75
#   scale = 1.3, margin ~= 19.3125

# This makes the High Pressure a 29.4% increase in the safety margin for jumps.

# Player feedback suggested the original ~16 pixel margin was too unforgiving,
#  so the obstacle paths are now scaled to provide a ~25 pixel safety margin,
#  which is a 56% increase. The (new) un-upgraded margin is 19.3 frames, a 20%
#  increase over the unforgiving value.

# Adjust the X scale factor to tune the speed of obstacles
X_SCALE = 1.3

xCoords = np.array((0, -10, -20, -38, -39, -40)) * X_SCALE
yCoords = (0, 2, 4, 5, 5, 0)
pathData.append(generateSplineDelta(xCoords, yCoords, len(pathData)*PER_INDEX_OFFSET))

xCoords = np.array((0, -10, -20, -25, -40)) * X_SCALE
yCoords = (0, -2, 0, 3, -4)
pathData.append(generateSplineDelta(xCoords, yCoords, len(pathData)*PER_INDEX_OFFSET))

xCoords = np.array((0, -10, -20, -30, -40)) * X_SCALE
yCoords = (0, -4, -2, 0, -8)
# Completely crazy loop that requires PACK_OFFSET of 1
#xCoords = (0, -8, -28, -16, -25, -40)
#yCoords = (0, -4, -3, -2, -5, -8)
pathData.append(generateSplineDelta(xCoords, yCoords, len(pathData)*PER_INDEX_OFFSET))

# In order to end up with sequential paths at ALIGN[8], we hard-code the
#  sections in WRAM, even though that's generally not ideal.
address = 0xD000

with open(output, 'w') as f:
    f.write(f'\nDEF OBSTACLE_PATH_COUNT EQU {len(pathData)}\n')
    f.write(f'DEF OBSTACLE_PATH_LENGTH EQU ${2 * ANIMATION_FRAMES:02X}\n')
    f.write(f'DEF OBSTACLE_PATH_WRAP EQU OBSTACLE_PATH_LENGTH - 1\n')
    f.write('EXPORT OBSTACLE_PATH_WRAP\n')

    for index in range(len(pathData)):
        f.write(f'\nSECTION "Obstacle Animation Path {index}", WRAM0[${address:04X}], ALIGN[8]\n')
        f.write(f'wObstacleAnimationPath{index}:: ds {2 * ANIMATION_FRAMES}\n')
        address += 0x100

    f.write('\nSECTION "Compressed Obstacle Animation Paths", ROMX\n')
    f.write('; These dY/dX animation paths are compressed. Since the maximum\n')
    f.write(';  possible delta value is -1>x>2, we can pack 4 deltas in a byte.\n')
    f.write('CompressedObstaclePaths:\n')
    for data in pathData:
        # Debug print unpacked data
        for chunk in chunks(data, 16):
            print('    db {}'.format(','.join(['${:02X}'.format(0xFF & (int(item) + PACK_OFFSET)) for item in chunk])))
        print('')

        packedData = []
        for chunk in chunks(data, 4):
            packedData.append((0x3 & (int(chunk[0]) + PACK_OFFSET)) << 6 | 
                              (0x3 & (int(chunk[1]) + PACK_OFFSET)) << 4 |
                              (0x3 & (int(chunk[2]) + PACK_OFFSET)) << 2 |
                              (0x3 & (int(chunk[3]) + PACK_OFFSET)))

        for chunk in chunks(packedData, 16):
            f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
            print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('')

