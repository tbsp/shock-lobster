#!/usr/bin/env python

#
# Name, description, and dictionary generator for Shock Lobster
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

output = 'res/names_descriptions_generated.asm'

"""
Script to build a dictionary of substring replacements and insert them into the
item names and descriptions where appropriate. Bytes saved are reported. Note
that there doesn't seem to be any notable performance hit from including these
lookups in-game, in terms of time to write out the VWF for the descriptions.
"""

import re
import math
from collections import Counter

START_ENTRY = ('Start Game', 'Deal as much damage as possible while avoiding obstacles.<NEWLINE><NEWLINE>Charges and damage over time effects are cleared when enemies are defeated.<NEWLINE><NEWLINE>Use pearls you collect to expand and improve your abilities.')

# Each entry is a code name (used for labels) as the key, and a tuple of
#  (name, description) for the value.
ENTRIES = {
    'Jet': ('Jet', "Release a jet of water, propelling yourself upwards and dealing 3 points of damage. The damage effect can only occur once every second."),
    'Zap': ('Zap [40 energy]', "Zap the enemy, dealing 40 damage. Generates 1 charge."),
    'Shock': ('Shock [35 energy]', "Shock the enemy for 5 damage and an additional 24 damage every 3 seconds over 9 seconds. Generates 1 charge."),
    'Discharge': ('Discharge [35+30 energy]', 'Finisher which deals damage per charge, plus 0.5 additional damage per extra point of energy (up to 30 energy).<NEWLINE><NEWLINE>1 charge: 17 damage<NEWLINE>2 charges: 31 damage<NEWLINE>3 charges: 45 damage<NEWLINE>4 charges: 60 damage<NEWLINE>5 charges: 74 damage'),
    'Electrify': ('Electrify [30 energy]', "Finisher which deals damage over time. Damage is increased per charge:<NEWLINE><NEWLINE>1 charge: 51 damage over 16 seconds<NEWLINE>2 charges: 94 damage over 16 seconds<NEWLINE>3 charges: 138 damage over 16 seconds<NEWLINE>4 charges: 181 damage over 16 seconds<NEWLINE>5 charges: 225 damage over 16 seconds"),
    'Empower': ('Empower [25 energy]', "Finisher which increases damage done by 30%. Lasts longer per charge:<NEWLINE><NEWLINE>1 charge: 14 seconds<NEWLINE>2 charges: 19 seconds<NEWLINE>3 charges: 24 seconds<NEWLINE>4 charges: 29 seconds<NEWLINE>5 charges: 34 seconds"),
    'Invigorate': ('Invigorate', "Instantly regain 60 energy. 30 second cooldown."),
    'Focus': ('Focus', r"Reduce the energy cost of all skills by 50% for 4 seconds. Invigorate cannot be used while Focus is active. 80 second cooldown."),

    'Amplify': ('Amplify', r"Increase the damage of Zap by 20% when Shock or Electrify are active."),
    'Detonate': ('Detonate', "Increase the critical strike chance of Disharge by 30% when Shock or Electrify are active."),
    'HighPressure': ('High Pressure', "Jet now launches you further into the air and deals double damage."),
    'Overcharge': ('Overcharge', "Critical hits from skills which generate charges generate an additional charge."),
    'ResidualCharge': ('Residual Charge', "The periodic damage from your Electrify skill can now critically hit."),
    'Expertise': ('Expertise', "Double your base critical strike chance from 30% to 60%."),
    'Clarity': ('Clarity', "All direct damage has a chance to cause you to enter a state of clarity, which reduces the base energy cost of the next skill to zero."),
    'Refresh': ('Refresh', "Zap will now extend the duration of an active Electrify by 2 seconds (up to 6 seconds total)."),

    'FirstStrike': ('First Strike', "Let loose an initial strike of two 100 damage blasts. Each hit may be a critical hit. [Consumable]"),
    'Blitz': ('Blitz', "Come out swinging with three 100 damage blasts. Each hit may be a critical hit. [Consumable]"),
    'FinalWord': ('Final Word', "Unleash an impassioned last-ditch retort, dealing three 100 damage blasts. Each hit may be a critical hit. [Consumable]"),
    'SecondWind': ('Second Wind', "Bounce back from defeat for a second chance. [Consumable]"),

    'GameSpeed': ('Game Speed', "Adjust the game speed.<NEWLINE><NEWLINE>Hiscores are tracked per game speed."),
    'Music': ('Music', "Enable game music."),
    'StickyDpad': ('Sticky D-Pad', "Enable sticky button pair selection in-game, which will snap back to the top pair when the D-pad is released."),
    'ResetSave': ('Reset Save', "Press A four times to reset the save data. Details panel must be visible to activate.<NEWLINE><NEWLINE>**WARNING** No final confirmation!"),
}

# Each dictionary entry is a name used to identify it in code (without the prefix),
#  and the string to create a lookup entry for.
DICTIONARY = {
    'HDamageBlasts': ' 100 damage blasts. Each hit may be a critical hit. ',
    'DamageOver16Seconds': ' damage over 16 seconds', # very special case for Electrify
    'Damage': ' damage',
    'Seconds': ' seconds',
    'Charges': ' charges: ',
    'Charge': ' charge', 
    'Energy': ' energy',
    'Additional': ' additional',
    'Critical': ' critical',
    'Strike': ' strike',
    'Electrify': 'Electrify',
    'Shock': 'Shock',
    'Invigorate': 'Invigorate',
    'Active': ' active',
    'Second': ' second',
    'Generates': ' Generates',
    'FinisherWhich': 'Finisher which ',
    'IncreaseThe': 'Increase the',
    'The': 'the ',
    'Cooldown': ' cooldown.',
    'Per': ' per',
    'Skill': ' skill',
    'Your': ' your',
    'Initial': ' initial',
    'Of': ' of ',
    'UpTo': 'up to ',
    'Chance': ' chance',
    'GameSpeed': 'game speed.',
    'Consumable': '. \[Consumable\]',
}


wFreqs = Counter()

def addLookupEntries(s, freq):
    """Replace all dictionary strings found with the appropriate code for gb-vwf to look them up, and increment the counter"""
    for name, string in DICTIONARY.items():
        count = len(list(re.finditer(string, s)))
        freq[name] += count
        s = s.replace(string.replace('\\', ''), f'", TEXT_DICT, Dict{name}, "')
        #if count > 0:
            #print(s)
    return s

# One-off calls to handle game start entry
PROCESSED_START_ENTRY = (addLookupEntries(START_ENTRY[0], wFreqs),
                         addLookupEntries(START_ENTRY[1], wFreqs))

# Build version of entries with dictionary strings replaced
PROCESSED_ENTRIES = {}
for item, (name, description) in ENTRIES.items():
    PROCESSED_ENTRIES[item] = (addLookupEntries(name, wFreqs),
                               addLookupEntries(description, wFreqs))

# Print bytes saved per dictionary item, and overall
print('Bytes saved by dictionary use:')
totalSaved = 0
for name, string in DICTIONARY.items():
    # old size is length of string multipled by uses
    oldSize = len(string) * wFreqs[name]
    # new size if length of string plus <END> terminator, plus 2 for the table index entry, plus 2 bytes per use
    newSize = len(string) + 1 + 2 + wFreqs[name] * 2
    savedBytes = oldSize - newSize
    print(f'{name}, "{string}" [{wFreqs[name]}]: {oldSize} - {newSize} = {savedBytes}')
    totalSaved += savedBytes
print(f'Total: {totalSaved}')

with open(output, 'w') as f:
    nameDescAlign = int(round(math.log(len(PROCESSED_ENTRIES)*2, 2)))

    f.write(f'\nSECTION "Status Names", ROMX, ALIGN[{nameDescAlign}]\n')
    f.write('StatusNames:\n')
    for item in PROCESSED_ENTRIES.keys():
        f.write(f'    dw .{item}\n')
    for item, (name, __) in PROCESSED_ENTRIES.items():
        f.write(f'.{item}\n')
        f.write(f'    db "{name}<END>"\n')
    
    f.write('\nGameStartName:\n')
    f.write(f'    db "{PROCESSED_START_ENTRY[0]}<END>"\n')

    f.write(f'\nSECTION "Status Descriptions", ROMX, ALIGN[{nameDescAlign}]\n')
    f.write('StatusDescriptions:\n')
    for item in PROCESSED_ENTRIES.keys():
        f.write(f'    dw .{item}\n')
    for item, (__, description) in PROCESSED_ENTRIES.items():
        f.write(f'.{item}\n')
        # Break up descriptions with newlines to avoid the RGBASM long string limit
        subStrings = description.split('>')
        for i, subString in enumerate(subStrings):
            if i < len(subStrings) - 1:
                f.write(f'    db "{subString}>"\n')
            else:
                f.write(f'    db "{subString}<END>"\n')

    f.write('\nGameStartDescription:\n')
    f.write(f'    db "{PROCESSED_START_ENTRY[1]}<END>"\n')

    # Calculate how many bits of alignment we need to index the table with just
    #  the low byte of the pointer.
    dictAlign = int(round(math.log(len(DICTIONARY), 2)))

    f.write(f'\nSECTION "VWF Dictionary", ROMX, ALIGN[{dictAlign}]\n')
    f.write('RSRESET\n')
    for item in DICTIONARY.keys():
        f.write(f'Dict{item} RB 1\n')

    f.write('\nDictionary::\n')
    for item in DICTIONARY.keys():
        f.write(f'    dw .{item}\n')
    for name, string in DICTIONARY.items():
        f.write(f'.{name}\n')
        cleanString = string.replace('\\', '')
        f.write(f'    db "{cleanString}<END>"\n')
