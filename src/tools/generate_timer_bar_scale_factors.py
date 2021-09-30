#!/usr/bin/env python

#
# Timer bar scale factor generator for Shock Lobster
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

output = 'res/timer_bar_scale_factors_generated.asm'

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

BAR_MAX = 48
FRAME_MAX = 60

LABEL = 'TimerBarScaleFactors'

# Note: Although the Focus cooldown is 76 seconds, due to the MAX_TIMERBAR_INDEX
#  of 71 the last 4 entries will never be used. Therefore set the duration to
#  72 and accept that the bar won't move for the first 4 seconds, which given
#  the 48 pixel bar length it's only actually missing ~2 pixel ticks, and since
#  it's such a long bar it's not a big deal.
# Note: The FocusBuff bar only gets 32 entries, which means it'll move less smooth
#  than it potentially could over the 48 pixel bar length. Luckily it's only 4
#  seconds long, and moves pretty quickly, so it ends up looking alright.
SKILLS_AND_SCALE_FACTORS = (('Shock', 9, 3, 3),
                            ('Electrify', 16, 2, 4),
                            ('Empower', 34, 1, 5),
                            ('Invigorate', 30, 1, 5),
                            ('FocusBuff', 4, 3, 3),
                            ('FocusCooldown', 72, 0, None),
        )

with open(output, 'w') as f:
    f.write('DEF MAX_TIMERBAR_INDEX EQU 71\n')
    f.write('SECTION "Timer Bar Scale Factors", ROM0, ALIGN[4]\n')
    f.write(";  This is only aligned to 4 bits because that's all we need for the index\n")
    f.write(f'{LABEL}::\n')

    # Note: Index is reversed because we loop through the timers backwards when
    #  updating the raster bars.
    for name, __, __, __ in reversed(SKILLS_AND_SCALE_FACTORS):
        f.write(f'    dw .{name}\n')

    for name, maxValue, tShift, fShift in SKILLS_AND_SCALE_FACTORS:

        f.write('\n.{}\n'.format(name))
        print(name)

        seconds = []
        indexValues = []
        lookupValues = []
        #for t in range(0, maxValue):
            #for frame in range(1, 61):
        # Since we only add the first index value each time loop backwards so we
        #  store the larger lookup value so bars start at the max length.
        for t in range(maxValue-1, -1, -1):
            for frame in range(60, 1, -1):
                if name == 'FocusCooldown':
                    index = (t >> tShift)
                    if index not in indexValues:
                        seconds.append(t + frame/60)
                        indexValues.append(index)
                        lookupValues.append(t / maxValue * 48 + 96 + 24) # + 96 is because it's off to the right of the tilemap
                else:
                    index = (t << tShift) + (frame >> fShift)
                    #print('t: {}, f: {}, index: {}, SCX: {}'.format(t, frame, index, int((t + frame/60) / maxValue * 48)))
                    if index not in indexValues:
                        seconds.append(t + frame/60)
                        indexValues.append(index)
                        lookupValues.append((t + frame/60) / maxValue * 48 + 24)

        # If a player activates Focus and then Electrify, and Zap three times
        #  quickly and all 3 Zaps crit, and the Refresh upgrade is present the
        #  Electrify timer duration could hit 22 seconds. To avoid a timer bar
        #  glitch we pad up to 72 entries (to match Shock, the longest table),
        #  then include code in the bar updater to never index past 72. This
        #  saves 16 bytes in the Electrify table here at the cost of 6 bytes
        #  worth of code (and a few cycles checking it).
        if name == 'Electrify':
            for _ in range(72-64):
                lookupValues.insert(0, 0x48)

        # import matplotlib.pyplot as plt
        # import numpy as np

        # fix, ax = plt.subplots()
        # ax.plot(lookupValues)
        # plt.show()

        # Reverse things so the bars start at the max length
        lookupValues = list(reversed(lookupValues))

        # # Pad tables to 64 bytes for easy indexing
        # while len(lookupValues) < 64:
        #     lookupValues.append(0)

        print(len(lookupValues))
        for chunk in chunks(lookupValues, 16):
            f.write('    db {}\n'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
            print('    db {}'.format(','.join(['${:02X}'.format(0xFF & int(item)) for item in chunk])))
