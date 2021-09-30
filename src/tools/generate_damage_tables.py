#!/usr/bin/env python

#
# Attack damage table generator for Shock Lobster
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

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

output = 'res/damage_tables_generated.asm'

# Each attack has:
#  - Base damage
#  - Emp buffed damage (+30%)
#  - Crit damage
#  - Crit+Emp damage
values = []

# Baseline values
BASE_HIT = 800 # average
AP = 9650
CRIT_RATE = 1.4 # unused
CRIT_MULT = 2.2
EMP_MULT = 1.3
ARMOR_MITIGATION = 1-10643/(10643+15232.5)
SHOCK_UPGRADE = 1.2
ALT_MULT = 1.3
GENERAL_MULT = 1.1
DISCHARGE_UPGRADE = 1.15
SCALE = 0.02 # Tuned such that the overall maximum hit (discharge with 30 bonus energy) is 255!
JET_SCALE = 0.3

print('Damage LUT Generator')
print('--------------------')
print('Base hit: {}'.format(BASE_HIT))
print('AP: {}'.format(AP))
print('Crit mult: {}'.format(CRIT_MULT))
print('Emp mult: {}'.format(EMP_MULT))
print('Armor mitigation: {}'.format(ARMOR_MITIGATION))
print('Alternate mult: {}'.format(ALT_MULT))
print('Scale: {}'.format(SCALE))
print('')

# Jet
#  - hit, empHit, crit, empCrit
hit = BASE_HIT * GENERAL_MULT * ARMOR_MITIGATION * SCALE * JET_SCALE
empHit = hit * EMP_MULT
crit = hit * CRIT_MULT
empCrit = crit * EMP_MULT
print('Jet: {}, {}, {}, {}'.format(int(hit), int(empHit), int(crit), int(empCrit)))
jetValues = [hit, empHit, crit, empCrit]
# Add upgraded jet values
UPGRADE_SCALE = 2.0
jetValues += [hit*UPGRADE_SCALE, empHit*UPGRADE_SCALE, crit*UPGRADE_SCALE, empCrit*UPGRADE_SCALE]


# Zap
# LUT:
#  - hit, empHit, crit, empCrit
#  - hit, empHit, crit, empCrit (+20% on debuffed targets)
energy = 42
hit = (BASE_HIT * 2.25 + 635) * GENERAL_MULT * ALT_MULT * ARMOR_MITIGATION * SCALE
empHit = hit * EMP_MULT
crit = hit * CRIT_MULT
empCrit = crit * EMP_MULT
zapValues = [hit, empHit, crit, empCrit]
print('Zap: {}, {}, {}, {}, DPE: {:0.2f}'.format(int(hit), int(empHit), int(crit), int(empCrit), hit/energy))
hit *= 1.2
empHit *= 1.2
crit *= 1.2
empCrit *= 1.2
print('Zap [debuffed]: {}, {}, {}, {}, DPE: {:0.2f}'.format(int(hit), int(empHit), int(crit), int(empCrit), hit/energy))
zapValues.extend([hit, empHit, crit, empCrit])

# Shock
# LUT:
#  - hit, dot
#  - empHit, empDot
#  - crit, critDot (equal to hit dot, can we just not store crit dot values?)
#  - empCrit, empCritDot (equal to empDot)
energy = 35
hit = (AP/100 + 176) * GENERAL_MULT * ALT_MULT * ARMOR_MITIGATION * SHOCK_UPGRADE * SCALE # +20% talent mod
dotCount = 3 # 9 seconds, ticks every 3 seconds
dot = ((358*3 + AP*0.18) / dotCount) * GENERAL_MULT * SHOCK_UPGRADE * SCALE # +20% talent mod
empHit = hit * EMP_MULT
empDot = dot * EMP_MULT
crit = hit * CRIT_MULT
critDot = dot
empCrit = crit * EMP_MULT
empCritDot = empDot
shockValues = [dot, hit, empDot, empHit, critDot, crit, empCritDot, empCrit]
print('Shock: {} [{}*{}], {} [{}*{}], {} [{}*{}], {} [{}*{}], DPE: {:0.2f}'.format(int(hit), int(dot), dotCount, 
                                                                                   int(empHit), int(empDot), dotCount, 
                                                                                   int(crit), int(critDot), dotCount, 
                                                                                   int(empCrit), int(empCritDot), dotCount,
                                                                                   (hit+dot*dotCount)/energy))

# The following have charge-based damage, and thus require hit/dot lookups based on 1-5 charges

# Electrify
# LUT (5 * 4 = 20 entries):
#  - base dot per charge (dot1, dot2, dot3, dot4, dot5)
#  - Emp dot per charge (dotEmp1, ... dotEmp5)
#  - crit dot per charge (dotCrit1, ... )
#  - Emp crit dot per charge (dotempCrit1, ...)
energy = 30
dotCount = 8 # 16 seconds, ticks every 2 seconds (12+4 sec, with glyph baked in)
electrifyValues = []
for Charge in range(1, 6):
    dot = (((36 + 93 * Charge + 0.01 * Charge * AP) * 6) * GENERAL_MULT * ALT_MULT) * SCALE * 16/12 # scale to 16sec total damage
    empDot = dot * EMP_MULT
    critDot = dot * CRIT_MULT
    empCritDot = empDot * CRIT_MULT
    electrifyValues.extend([dot/dotCount, empDot/dotCount, critDot/dotCount, empCritDot/dotCount])
    print('Electrify [{} Charge(s)]: {} [{}], {}, {}, {}, DPE: {:0.2f}'.format(Charge, int(dot/dotCount), int(dot), int(empDot/dotCount), int(critDot/dotCount), int(empCritDot/dotCount), dot/energy))

# Discharge
# LUT (4 * (5 + 30) = 140 entries)
#  - hit per charge, per 0-30 extra energy
#  - empHit per charge, per 0-30 extra energy
#  - crit per charge, per 0-30 extra energy
#  - empCrit per charge, per 0-30 extra energy
energy = 35
dischargeValues = []
for Charge in range(1, 6):
    hit = (190 + Charge * (290 + 0.07 * AP)) * GENERAL_MULT * ARMOR_MITIGATION * DISCHARGE_UPGRADE * SCALE # +15% mod
    empHit = hit * EMP_MULT
    crit = hit * CRIT_MULT
    empCrit = crit * EMP_MULT
    dischargeValues.extend([hit, empHit, crit, empCrit])
    print('Discharge [{} Charge(s)]: {}, {}, {}, {}, DPE: {:0.2f}'.format(Charge, int(hit), int(empHit), int(crit), int(empCrit), hit/energy))
    maxDischarge = empCrit
    
dischargeExtraValues = []
for extra in range(0, 31):
    hitExtra = (9.4 + AP/410) * GENERAL_MULT * ARMOR_MITIGATION * DISCHARGE_UPGRADE * SCALE * extra # +15% mod
    empExtra = hitExtra * EMP_MULT
    critExtra = hitExtra * CRIT_MULT
    empCritExtra = critExtra * EMP_MULT
    dischargeExtraValues.extend([hitExtra, empExtra, critExtra, empCritExtra])
    print('Discharge [{} Extra]: {}, {}, {}, {} [max: {}]'.format(extra, int(hitExtra), int(empExtra), int(critExtra), int(empCritExtra), int(maxDischarge+empCritExtra)))


# Write final file    
with open(output, 'w') as f:
    f.write('SECTION "Damage Tables", ROMX, ALIGN[8]\n')
    f.write('\nJetDamage::\n')
    for chunk in chunks(jetValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(int(item)) for item in chunk])))

    f.write('\nZapDamage::\n')
    for chunk in chunks(zapValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(int(item)) for item in chunk])))

    f.write('\nShockDamage::\n')
    for chunk in chunks(shockValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(int(item)) for item in chunk])))

    f.write('\nElectrifyDamage::\n')
    for chunk in chunks(electrifyValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(int(item)) for item in chunk])))

    f.write('\nDischargeDamage::\n')
    for chunk in chunks(dischargeValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(int(item)) for item in chunk])))

    f.write('\nDischargeExtraDamage::\n')
    for chunk in chunks(dischargeExtraValues, 16):
        f.write('    db {}\n'.format(','.join(['${:02X}'.format(int(item)) for item in chunk])))
