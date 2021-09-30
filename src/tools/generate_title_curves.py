#!/usr/bin/env python

#
# Title curve generator for Shock Lobster
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

output = 'res/title_curves_generated.asm'

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

with open(output, 'w') as f:
    LINES0 = 64

    f.write('SECTION "Title Curve 0", ROMX, ALIGN[8]\n')
    f.write('TitleCurve0:\n')

    lookupValues0 = []
    for line in range(LINES0):
        lookupValues0.append(int(4*math.sin(line/(LINES0/20*math.pi))))

    print(len(lookupValues0))
    for chunk in chunks(lookupValues0, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))

    LINES1 = 32

    f.write('SECTION "Title Curve 1", ROMX, ALIGN[8]\n')
    f.write('TitleCurve1:\n')

    lookupValues1 = []
    for line in range(LINES1):
        lookupValues1.append(int(2*math.sin(line/(LINES1/30*math.pi))))

    print(len(lookupValues1))
    for chunk in chunks(lookupValues1, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
        print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))


    # import matplotlib.pyplot as plt
    # import numpy as np

    # fix, ax = plt.subplots()
    # frames0 = [item for item in range(LINES0)]
    # frames1 = [item for item in range(LINES1)]
    # ax.plot(lookupValues0, frames0, 'o-')
    # ax.plot(lookupValues1, frames1, 'x-')
    # plt.show()