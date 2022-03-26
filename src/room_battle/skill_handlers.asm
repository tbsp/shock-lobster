;
; Skill and item activation handlers for Shock Lobster
;
; Copyright 2021 Dave VanEe
;
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
; 
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
; 
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;

INCLUDE "engine.inc"
INCLUDE "sound_fx.inc"

DEF COST_ZAP        EQU 40
DEF COST_SHOCK      EQU 35
DEF COST_DISCHARGE  EQU 35
DEF COST_ELECTRIFY  EQU 30
DEF COST_EMPOWER    EQU 25

DEF GAIN_INVIGORATE EQU 60

; Decimal initial timer duration for dots/buffs
; Note: Electrify can be refreshed up to 22sec, but the bar is always relative to a 16sec max
; Note: Empower's duration is charge-dependent, but the bar is always relative to the max
DEF DURATION_SHOCK      EQU 9
DEF DURATION_ELECTRIFY  EQU 16
DEF DURATION_EMPOWER    EQU 34
DEF DURATION_FOCUS      EQU 4

; Cooldown durations
DEF COOLDOWN_INVIGORATE EQU 30
DEF COOLDOWN_FOCUS      EQU 80-4 ; cooldown minus buff duration

; Maximum number of times the refresh upgrade can extend the duration of electrify
DEF MAX_REFRESHES       EQU 3

; Number of frames the player is invulnerable after using Second Wind
DEF SECOND_WIND_INVULNERABLE_FRAMES EQU 120

; Export so they can be used to dim skill icons elsewhere
; (or should we just handle that here?)
export COST_ZAP
export COST_SHOCK
export COST_DISCHARGE
export COST_ELECTRIFY
export COST_EMPOWER

; These end up as fixed point, so divide by 255 to get the value we want
DEF CRITICAL_THRESHOLD              EQU (1.0-0.3)/255 ; (30% crit rate)
DEF CRITICAL_THRESHOLD_EXPERTISE    EQU (1.0-0.6)/255 ; (60% crit rate)
DEF CRITICAL_THRESHOLD_DETONATE     EQU (1.0-0.7)/255 ; (60% crit rate)
DEF CRITICAL_THRESHOLD_EXPERTISE_DETONATE   EQU (1.0-0.90)/255 ; (90% crit rate)

DEF CLARITY_THRESHOLD   EQU (1.0-0.1)/255 ; (10% proc rate)

; These are the handlers for when skills are activated
SECTION "Skill Activate Handlers", ROM0

; Jump table for handlers
SkillHandlers::
.even
    dw Jet
.odd
    dw Zap
    dw Shock
    dw Discharge
    dw Electrify
    dw Empower
    dw Invigorate
    dw Focus
; items
    dw FirstStrike
    dw Blitz
    dw FinalWord
    dw SecondWind

; Zap [40 Energy]
; Zap the enemy, dealing 40 damage. Generates 1 charge.
; TODO: Adjust damage for 40 (vs 42) energy cost
Zap:
    call    ProcessClarityProc
    jr      nz, .clarityWasActive
    ld      b, COST_ZAP
    ldh     a, [hFocusBuffActive]
    or      a
    jr      z, .noFocusBuff
    srl     b   ; Halve energy cost if focus buff is active
.noFocusBuff
    ldh     a, [hEnergy]
    sub     b   ; Deduct skill energy cost
    ldh     [hEnergy], a
    ; No need to update the energy display as it ticks every 6 frames and will update
    ;  soon enough.
.clarityWasActive

    ld      a, FX_ZAP
    call    audio_play_fx

    ; Initialize laser animation
    ld      a, LOW(LASER_ANIMATION_LOOKUP.zap)
    ldh     [hLaserLowAddr], a

    ; Determine if the damage is critical
    ld      a, [wCriticalThreshold]
    ld      e, a
    call    rand
    cp      e
    ld      e, 0
    jr      c, .noCritical
    inc     e   ; GenerateCharges requires a 0 or 1 value for crits
.noCritical

    call    GenerateCharges
    call    ActivateRecoil

    sla     e   ; zap critical damage is 2 entries over, and DealDamage needs that full offset

    ; Lookup damage
    ld      hl, ZapDamage
    ld      a, [wEmpowerTimer]
    or      a
    jr      z, .notEmpowered
    inc     l
.notEmpowered
    ld      a, [wElectrifyTimer]
    or      a
    jr      z, .notElectrified
    ; If we're electrified, check the refresh conditions!

    ; To increase the duration we must:
    ;  - Be using 'zap' (we're in this call)
    ;  - Have the 'refresh' upgrade enabled
    ;  - Have extended the duration fewer than 3 times
    ld      a, [wEnabledUpgrades]
    and     UPGRADEF_REFRESH
    jr      z, .noRefreshUpgrade
    ld      a, [wRefreshCounter]
    cp      MAX_REFRESHES
    jr      z, .maxRefreshes
    inc     a
    ld      [wRefreshCounter], a
    ld      a, [wElectrifyTimer+3]
    add     2
    ld      [wElectrifyTimer+3], a
    ; Manually trigger an update of the timer display value
    push    hl
    call    ElectrifyTimerTick.refreshElectrifyTimerDisplay
    pop     hl
.noRefreshUpgrade
;.notCritical
.maxRefreshes

.notElectrified
    ld      a, [wShockTimer]
    or      a
    jr      z, .notDebuffed
    ld      a, [wEnabledUpgrades]
    and     UPGRADEF_AMPLIFY
    jr      z, .noAmplify
    ; We have a debuff and the amplify upgrade, apply it
    ld      a, l    ; if the shock or electrify dot is active, zap does +20% damage
    add     4
    ld      l, a
.notDebuffed
.noAmplify
    ld      a, e    ; add critical offset
    add     l
    ld      l, a
    ld      a, [hl]

    sra     e       ; drop critical down to a 0/1 flag

    ;jp      DealDamage ; fallthrough

; Deal `a` damage to enemy health
; Inputs: a = damage to deal
;         e = critical flag (0 = hit, 1 = critical)
DealDamage:
    ; Generate animated damage text entry
    ld      c, a    ; cache damage value

    ; Add damage to pending HiScore update (which can take several scanlines,
    ;  which can push the raster table update too late and cause visual artifacts,
    ;  so we add up the pending damage and then update the HiScore all at once
    ;  later on when we have scanlines to spare).
    push    de      ; protect critical flag
    ld      hl, wPendingDamage
    ld      a, [hli]
    ld      e, a
    ld      a, [hl]
    ld      d, a

    ld      a, c    ; add `c` (damage value) to `de` (existing pending damage)
    add     e
    ld      e, a
    adc     d
    sub     e
    ;ld      d, a

    ;ld      a, d
    ld      [hld], a
    ld      a, e
    ld      [hl], a
    pop     de      ; recover critical flag

    ; Find empty damage text entry
    ld      hl, wDamageText
.seekLoop
    ld      a, [hl]
    or      a
    jr      z, .emptyEntryFound
    ld      a, l    ; advance to next entry
    or      DAMAGE_TEXT_SIZE-1
    inc     a       ; aligned so we'll never overflow the high byte
    ld      l, a
    ; Although I believe we have enough entries to never overflow, players
    ;  might do something I didn't think of, so check to be sure.
    cp      LOW(wDamageText.end)
    jr      z, .outOfEntries
    jr      .seekLoop
.emptyEntryFound
    ld      a, DAMAGE_TEXT_FRAMES
    ld      [hli], a
    ld      a, e
    or      a
    jr      z, .notCrit
    ld      a, LOW(DAMAGE_TEXT_ANIMATIONS.crit)
.notCrit
    ld      [hli], a    ; Note: hit animations have a low byte of zero

    ld      e, c        ; move cached damage value to protect it during rand
    ; Randomize starting location within small window
    ; TODO: Call rand in the main loop and cache a single byte in HRAM?
    push    hl
    call    rand
    pop     hl
    ld      c, a
    and     $0F         ; use lower nibble 0-16 for Y coord randomization
    add     $10
    ld      [hli], a    ; Y coord
    ld      a, c
    and     $F0         ; use upper nibble 0-16 for X coord randomization
    swap    a
    add     $88
    ld      [hli], a    ; X coord

    ; Determine ones/tens/hundreds digits from damage value
    ld      a, e
    call    bcd8bit_baa
    ; 41 bytes, 180/192 cycles
    ld      c, a        ; cache ones/tens byte

    ; ones digit tile
    and     $0F
    add     a           ; account for spaced out digit tiles
    add     $80
    ld      [hli], a

    ; tens digit tile
    ; first check if we have a hundreds digit
    ld      a, b
    and     %00000011   ; upper 6 bits are undefined
    ld      b, a
    jr      nz, .haveHundreds
    ld      a, c
    and     $F0
    ld      a, $FF      ; prepare empty fill value
    jr      z, .twoEmpty    ; no hundreds or tens, done this entry
.haveHundreds
    ld      a, c
    and     $F0
    swap    a
    add     a           ; account for spaced out digit tiles
    add     $80
    ld      [hli], a

    ; hundreds digit tile
    ld      a, b
    or      a
    ld      a, $FF      ; prepare empty fill value
    jr      z, .oneEmpty

    ld      a, b
    add     a           ; account for spaced out digit tiles
    add     $80
.twoEmpty
    ld      [hli], a
.oneEmpty
    ld      [hli], a    ; for 3-digit cases the hundreds tile will end up in the pad byte, which is fine

.outOfEntries

    ; Load negative damage value in `de`
    ld      a, e
    cpl
    inc     a
    ld      e, a
    ld      d, $FF

    ; Deal damage
    ld      hl, wEnemyHealth
    ld      a, [hli]
    ld      h, [hl]
    ld      l, a
    add     hl, de  ; subtract damage dealt

    ; If h=$FF, inc a will be zero, and the health overflowed.
    ; Since the maximum damage in one hit is 255, this can never overflow
    ;  to $FE in a single hit.
    ld      a, h
    inc     a
    jr      nz, .notDead

    ; Enemy defeated!
    ld      h, a    ; snap to zero health to not break health bar updates
    ld      l, a

    ; Terminate all dots by zeroing their frame counter
    ld      [wShockTimer], a
    ld      [wElectrifyTimer], a

    ; Block certain skills while enemy is dead
    ld      a, ENEMY_DEAD_SKILL_MASK
    ldh     [hEnemySkillMask], a

    ; Flag enemy as despawning
    ld      a, STATE_DESPAWNING
    ldh     [hEnemyState], a

    ld      a, FX_ENEMY_DEFEATED
    push    hl
    call    audio_play_fx
    pop     hl

    ; Point to despawning animation path
    ld      a, LOW(EnemyAnimationPaths.despawning)
    ld      [wEnemyAnimationPath], a
    ld      a, HIGH(EnemyAnimationPaths.despawning)
    ld      [wEnemyAnimationPath+1], a

.notDead

    ld      a, l
    ld      [wEnemyHealth], a
    ld      a, h
    ld      [wEnemyHealth+1], a

    ret

; Input: e = Indicates if attack was a critical hit or not
GenerateCharges:
    ld      a, [wEnabledUpgrades]
    and     UPGRADEF_OVERCHARGE
    ld      d, 0
    jr      z, .noOvercharge
    inc     d           ; will be used to bypass overcharge below
.noOvercharge

    ldh     a, [hCharges]
    ld      b, a        ; cache original charge count
    cp      MAX_CHARGES
    ret     z           ; max charges already reached
    inc     a
    dec     e           ; check if e==1
    ld      c, 0
    jr      nz, .notCritical
    dec     d
    jr      nz, .skipOvercharge
    cp      MAX_CHARGES
    jr      z, .maxCharges
    inc     a           ; add a second charge if we're still not at the max
    inc     c           ; indicate a second charge was actually added
.maxCharges
.skipOvercharge
.notCritical
    ldh     [hCharges], a
    inc     e           ; restore `e` for subsequent use by DealDamage

    ; Update charges tilemap
    ld      hl, CHARGE_TILEMAP - 1
    inc     b           ; increment for first pass
.seekLoop
    inc     l           ; advance to address of new charge added
    dec     b
    jr      nz, .seekLoop

:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, TILE_CHARGE_FULL
    ld      [hli], a

    ld      a, c        ; check if an extra charge was actually added
    or      a
    ret     z

:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, TILE_CHARGE_FULL
    ld      [hli], a

    ret

ActivateRecoil:
    ld      a, e
    or      a
    ld      a, LOW(EnemyAnimationPaths.recoilSmall)
    jr      z, .noCrit
    add     LOW(EnemyAnimationPaths.recoilLarge - EnemyAnimationPaths.recoilSmall)
.noCrit
    ld      [wEnemyAnimationPath], a
    ld      a, HIGH(EnemyAnimationPaths)
    ld      [wEnemyAnimationPath+1], a

    ; Set to recoil state, which will decrement to idle state on completion
    ld      a, STATE_RECOILING
    ldh     [hEnemyState], a

    ret

; The base jump has a maximum height of 29 pixels and 19.3 'safe' frames of obstacle clearance
DEF PLAYER_INITIAL_JET_VELOCITY_BASE        EQU 110

; The upgraded jump has a maximum height of 35 pixels and 25 'safe' frames of obstacle clearance
DEF PLAYER_INITIAL_JET_VELOCITY_UPGRADED    EQU 120

DEF PLAYER_LOW_ACCELERATION         EQU -3

; Determine if a new clarity proc should occur, and also return with the
;  z flag indicating if a clarity proc was active and energy consumption
;  can be skipped. (z set means no proc was active)
; Since Jet shouldn't consume the proc, we preload `bc` with values based
;  on the state of the proc beforehand and call .overrideClearedProc.
ProcessClarityProc:
    lb      bc, 0, 0    ; setup tile and flag values for cleared proc
.overrideClearedProc
    ld      a, [wEnabledUpgrades]
    and     UPGRADEF_CLARITY
    ret     z       ; no clarity upgrade

    ldh     a, [hClarityActive]
    inc     a       ; offset flag so '0' will result in the zero flag being set by `dec e`
    ld      e, a

    push    bc
    call    rand
    pop     bc
    cp      CLARITY_THRESHOLD
    jr      c, .noClarityProcTriggered

    push    de  ; preserve prior proc state (DisplayBuff wipes out D)
        ld      a, FX_CLARITY
        call    audio_play_fx

        ld      e, LOW(vBuffTiles.clarity / 16) ; buff tile ID
        call    DisplayBuff
    pop     de

    ; Clarity proc triggered, setup tile and flag values
    lb      bc, LOW(vClarityTile / 16), 1 ; tile ID and !0

.noClarityProcTriggered

    ; Update visuals
    ld      hl, CLARITY_TILEMAP
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b ; show or hide proc tile

    ld      a, c    ; set or clear proc flag
    ldh     [hClarityActive], a

    dec     e       ; set `z` flag based on prior state of proc
    ret

; Release a jet of water, propelling yourself upwards and doing 3 points of damage. This damage effect can only occur once every second.
Jet:
    ld      hl, wJumpCounter
    ld      a, [hl]
    cp      1
    ret     z   ; we can only jump once

    inc     a
    ld      [hl], a

    ld      a, [wEnabledUpgrades]
    and     UPGRADEF_HIGH_PRESSURE
    ; Setup for base Jet
    ld      b, FX_JET
    ld      a, PLAYER_INITIAL_JET_VELOCITY_BASE
    jr      z, .noHighPressure
    ASSERT(FX_JET + 1 == FX_JET_UPGRADED)
    inc     b   ; move to upgraded Jet SFX
    add     PLAYER_INITIAL_JET_VELOCITY_UPGRADED - PLAYER_INITIAL_JET_VELOCITY_BASE
.noHighPressure
    ; Activate upward movement
    ld      [wPlayerYVelocity], a
    ld      a, b
    call    audio_play_fx

    ; For now use constant acceleration
    ; TODO: Use higher acceleration after button released?
    ld      a, PLAYER_LOW_ACCELERATION
    ld      [wPlayerYAccel], a
    
    ; Maintain upward movement as long as button is held?
    ;  -> Even if the player changes the active button pair?

    ; Do we use the core timer mechanism to track the ICD of the damage?
    ; -> Is that worth it for such a short timer that has no visible bar?

    ; Check if the ICD on the attack portion has expired
    ld      a, [wJetCooldownTimer]
    or      a
    ret     nz

    ; If the skill mask isn't $FF, there's no enemy to attack, so don't fire the jet
    ldh     a, [hEnemySkillMask]
    inc     a
    ret     nz

    ; Special setup for Jet to avoid consuming clarity procs
    ; (basically makes it set the state to what it was before OR a new proc)
    lb      bc, 0, 0    ; setup tile and flag values for cleared proc
    ldh     a, [hClarityActive]
    or      a
    jr      z, .clarityNotActive
    lb      bc, LOW(vClarityTile / 16), 1 ; tile ID and !0
.clarityNotActive
    call    ProcessClarityProc.overrideClearedProc

    ; Start Jet ICD
    ld      a, JET_COOLDOWN_MAX
    ld      [wJetCooldownTimer], a

    ; Initialize laser animation
    ld      a, LOW(LASER_ANIMATION_LOOKUP.jet)
    ldh     [hLaserLowAddr], a

    ; Determine if the damage is critical
    ld      a, [wCriticalThreshold]
    ld      e, a
    call    rand
    cp      e
    ld      e, 0
    jr      c, .noCritical
    ld      e, 2    ; Jet critical damage is 2 entries over
.noCritical

    call    ActivateRecoil

    ; Lookup damage
    ld      hl, JetDamage
    ld      a, [wEmpowerTimer]
    or      a
    jr      z, .notEmpowered
    inc     l
.notEmpowered
    ; Check if we have the damage upgrade
    ld      a, [wEnabledUpgrades]
    and     UPGRADEF_HIGH_PRESSURE
    ld      a, e    ; start with critical offset
    jr      z, .noUpgradedDamage
    add     4       ; offset for upgraded damage
.noUpgradedDamage
    add     l       ; add Empower offset

    ld      l, a
    ld      a, [hl] ; damage value

    sra     e       ; drop critical down to a 0/1 flag

    jp      DealDamage

; Shock [35 Energy]
; Shock the enemy for 5 electrical damage and an additional 24 damage every 3 seconds. Generates 1 charge.
Shock:
    call    ProcessClarityProc
    jr      nz, .clarityWasActive
    ld      b, COST_SHOCK
    ldh     a, [hFocusBuffActive]
    or      a
    jr      z, .noFocusBuff
    srl     b   ; Halve energy cost if focus buff is active
.noFocusBuff
    ldh     a, [hEnergy]
    sub     b   ; Deduct skill energy cost
    ldh     [hEnergy], a
.clarityWasActive

    ld      a, FX_SHOCK
    call    audio_play_fx

    ; Initialize laser animation
    ld      a, LOW(LASER_ANIMATION_LOOKUP.shock)
    ldh     [hLaserLowAddr], a

    ; Determine if the damage is critical
    ld      a, [wCriticalThreshold]
    ld      e, a
    call    rand
    cp      e
    ld      e, 0
    jr      c, .noCritical
    inc     e   ; GenerateCharges requires a 0 or 1 value for crits
.noCritical

    call    GenerateCharges
    call    ActivateRecoil

    sla     e    ; Shock critical damage is 4 entries over
    sla     e

    ; Determine if enemy is electrified (shock or electrify, we need a better general term!)

    ; Setup damage timer
    ld      hl, wShockTimer
    ld      a, FRAME_COUNTER_MAX
    ld      [hli], a
    inc     l       ; skip shift byte
    inc     l       ; skip unused high byte
    ld      a, DURATION_SHOCK
    ld      [hli], a

    ; Force a tick to update the timer number
    call    ShockTimerTick

    ; Lookup damage
    ld      hl, ShockDamage
    ld      a, [wEmpowerTimer]
    or      a
    jr      z, .notEmpowered
    inc     l
    inc     l
.notEmpowered
    ld      a, e    ; add critical offset
    add     l
    ld      l, a
    ld      a, [hli]                ; dot damage value
    ld      [wShockDamageTick], a   ; used by the ShockTimerTick call
    ld      a, [hl]                 ; direct damage value

    sra     e       ; drop critical down to a 0/1 flag
    sra     e

    jp      DealDamage

; Discharge [35+30 Energy]
; Finisher which deals damage per charge, plus 0.5 additional damage per extra point of energy (up to 30 energy maximum).
; 1 point: 17 damage
; 2 points: 31 damage
; 3 points: 45 damage
; 4 points: 60 damage
; 5 points: 74 damage
Discharge:
    call    ProcessClarityProc
    jr      nz, .clarityWasActive
    ld      b, COST_DISCHARGE
    ldh     a, [hFocusBuffActive]
    or      a
    jr      z, .noFocusBuff
    srl     b   ; Halve energy cost if focus buff is active
.noFocusBuff
    ldh     a, [hEnergy]
    sub     b   ; Deduct skill energy cost
    ldh     [hEnergy], a
.clarityWasActive

    ld      a, FX_DISCHARGE
    call    audio_play_fx

    ldh     a, [hCharges]
    ld      e, a
    ;xor     a   ; Consume all charges (done below so we can re-get it from HRAM)
    ;ldh     [hCharges], a


    ; Initialize laser animation
    ld      a, LOW(LASER_ANIMATION_LOOKUP.discharge)
    ldh     [hLaserLowAddr], a

    ; Update charge display
    ld      hl, CHARGE_TILEMAP
.clearCharges
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, TILE_CHARGE_EMPTY
    ld      [hli], a
    dec     e
    jr      nz, .clearCharges

    ; Determine if enemy has an active dot (grants +30% critical chance)
    ld      a, [wCriticalThreshold]
    ld      e, a
    ld      a, [wEnabledUpgrades]
    and     UPGRADEF_DETONATE
    jr      z, .noDetonate
    ld      a, [wShockTimer]
    or      a
    jr      nz, .isDebuffed
    ld      a, [wElectrifyTimer]
    or      a
    jr      z, .notDebuffed
.isDebuffed
    ld      a, [wCriticalDetonate]
    ld      e, a
.notDebuffed
.noDetonate

    ; Determine if the damage is critical
    call    rand
    cp      e
    jr      c, .noCritical
    ld      e, 2    ; Discharge critical damage is 2 entries over
    jr      :+
.noCritical
    ld      e, 0
:

    call    ActivateRecoil

    ; Lookup damage
    ld      hl, DischargeDamage

    ldh     a, [hCharges]
    dec     a   ; first charge provides zero offset
    add     a   ; charges*4 to get damage row for that many charges
    add     a
    add     l   ; offset to row for charge-based damage
    ld      l, a
    ld      a, [wEmpowerTimer]
    or      a
    jr      z, .notEmpowered
    inc     l
.notEmpowered
    ld      a, e    ; add critical offset
    add     l
    ld      l, a

    xor     a       ; Consume all charges (done late due to register pressure earlier)
    ldh     [hCharges], a

    ld      a, [hl]
    ld      b, a    ; store base damage value

    ; Consume up to 30 additional energy to boost damage
    ld      c, 30
    ldh     a, [hEnergy]
    cp      c
    jr      nc, .consume30energy
    ld      c, a    ; consume whatever's left over
.consume30energy
    sub     c
    ldh     [hEnergy], a

    ; Lookup extra damage
    sla     c       ; energy consumed * 4
    sla     c

    ; `h` is already HIGH(DischargeExtraDamage)
    ld      a, LOW(DischargeExtraDamage)    ; add energy offset
    add     c
    ld      l, a
    ld      a, [wEmpowerTimer]
    or      a
    jr      z, .notEmpoweredExtra
    inc     l
.notEmpoweredExtra
    ld      a, e    ; add critical offset
    add     l
    ld      l, a
    ld      a, [hl]
    add     b       ; add base damage

    sra     e       ; drop critical down to a 0/1 flag
    
    jp      DealDamage

 
; Electrify [30 Energy]
; Finisher which deals damage over time. Damage is increased per charge:
; 1 point: 51 damage over 16 seconds
; 2 points: 94 damage over 16 seconds
; 3 points: 138 damage over 16 seconds
; 4 points: 181 damage over 16 seconds
; 5 points: 225 damage over 16 seconds
Electrify:
    call    ProcessClarityProc
    jr      nz, .clarityWasActive
    ld      b, COST_ELECTRIFY
    ldh     a, [hFocusBuffActive]
    or      a
    jr      z, .noFocusBuff
    srl     b   ; Halve energy cost if focus buff is active
.noFocusBuff
    ldh     a, [hEnergy]
    sub     b   ; Deduct skill energy cost
    ldh     [hEnergy], a
.clarityWasActive

    ld      a, FX_ELECTRIFY
    call    audio_play_fx

    ldh     a, [hCharges]
    ld      e, a
    xor     a   ; Consume all charges
    ldh     [hCharges], a
    ld      [wRefreshCounter], a    ; Clear refresh counter

    ; Initialize laser animation
    ld      a, LOW(LASER_ANIMATION_LOOKUP.electrify)
    ldh     [hLaserLowAddr], a

    ; Update charge display
    ld      hl, CHARGE_TILEMAP
    ld      d, e
.clearCharges
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, TILE_CHARGE_EMPTY
    ld      [hli], a
    dec     d
    jr      nz, .clearCharges

    ; Lookup damage
    ld      hl, ElectrifyDamage
    ld      a, e
    dec     a   ; first charge provides zero offset
    add     a   ; charges*4 to get damage row for that many charges
    add     a
    add     l   ; offset to row for charge-based damage
    ld      l, a
    ld      a, [wEmpowerTimer]
    or      a
    jr      z, .notEmpowered
    inc     l
.notEmpowered
    ; Store hit and crit values, with "did it crit?" determined when tick occurs
    ld      a, [hl]
    ld      [wElectrifyDamageTick], a   ; used by the ElectrifyTimerTick call
    inc     l
    ld      a, [wEnabledUpgrades]
    and     UPGRADEF_RESIDUAL_CHARGE
    jr      z, .noCritTicks
    inc     l   ; if we have the upgrade, increment to read the critical tick value
.noCritTicks
    ld      a, [hl]
    ld      [wElectrifyDamageCrit], a   ; used by the ElectrifyTimerTick call

    ; Setup damage timer
    ; Note: It'd be a tiny bit faster to just direct load the values we need,
    ;  but ElectrifyTimerTick assumes `hl` points to timer+3, so we do it this way.
    ld      hl, wElectrifyTimer
    ld      a, FRAME_COUNTER_MAX
    ld      [hli], a
    inc     l       ; skip shift byte
    inc     l       ; skip unused high byte
    ld      a, DURATION_ELECTRIFY
    ld      [hli], a

    ; Force a tick to update the timer number
    inc     a   ; Put an odd value into `a` and jump mid-call to avoid dealing damage
    call    ElectrifyTimerTick.fakeTimerValue
    ret

; Empower [25 Energy]
; Finisher which increases damage done by 30%. Lasts longer per charge:
; 1 point: 14 seconds
; 2 points: 19 seconds
; 3 points: 24 seconds
; 4 points: 29 seconds
; 5 points: 34 seconds
Empower:
    call    ProcessClarityProc
    jr      nz, .clarityWasActive
    ld      b, COST_EMPOWER
    ldh     a, [hFocusBuffActive]
    or      a
    jr      z, .noFocusBuff
    srl     b   ; Halve energy cost if focus buff is active
.noFocusBuff
    ldh     a, [hEnergy]
    sub     b   ; Deduct skill energy cost
    ldh     [hEnergy], a
.clarityWasActive

    ld      a, FX_EMPOWER
    call    audio_play_fx

    ldh     a, [hCharges]
    ld      e, a
    xor     a   ; Consume all charges
    ldh     [hCharges], a

    ; Update charge display
    ld      hl, CHARGE_TILEMAP
    ld      d, e
.clearCharges
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, TILE_CHARGE_EMPTY
    ld      [hli], a
    dec     d
    jr      nz, .clearCharges

    ; Determine duration based on charges
    ld      hl, EMPOWER_DURATION_BASED_ON_CHARGES
    ld      a, e
    dec     a       ; Offset 1 less than number of charges
    add     l
    ld      l, a
    adc     h
    sub     l
    ld      h, a
    ld      e, [hl]

    ; Setup buff timer
    ld      hl, wEmpowerTimer
    ld      a, FRAME_COUNTER_MAX
    ld      [hli], a
    inc     l       ; skip shift byte
    inc     l       ; skip unused high byte
    ld      [hl], e
    inc     l       ; must point to wEmpowerTimer+4 for EmpowerTimerTick

    ; Force a tick to update the timer number
    call    EmpowerTimerTick

    ld      e, LOW(vBuffTiles.empower / 16) ; buff tile ID
    ;call    DisplayBuff    ; fall through to call
    ;ret

DisplayBuff:
    ; Find empty damage text entry
    ld      hl, wDamageText
.seekLoop
    ld      a, [hl]
    or      a
    jr      z, .emptyEntryFound
    ld      a, l    ; advance to next entry
    or      DAMAGE_TEXT_SIZE-1
    inc     a       ; aligned so we'll never overflow the high byte
    ld      l, a
    ; Although I believe we have enough entries to never overflow, players
    ;  might do something I didn't think of, so check to be sure.
    cp      LOW(wDamageText.end)
    ret     z       ; out of entries
    jr      .seekLoop
.emptyEntryFound
    ld      a, DAMAGE_TEXT_FRAMES
    ld      [hli], a
    ld      a, LOW(DAMAGE_TEXT_ANIMATIONS.buff)
    ld      [hli], a

    ; Randomize starting location within small window
    push    hl
    call    rand
    pop     hl
    ld      c, a
    and     $0F         ; use lower nibble 0-16 for Y coord randomization
    ld      b, a
    ldh     a, [hPlayerYCoord]
    sub     b
    ld      [hli], a    ; Y coord
    ld      a, c
    and     $F0         ; use upper nibble 0-16 for X coord randomization
    swap    a
    add     LOBSTER_X_COORD
    ld      [hli], a    ; X coord

    ld      a, e
    ld      [hli], a
    ;sub     2
    ld      a, $FF
    ld      [hli], a
    ;ld      a, $FF
    ld      [hli], a

    ret


; Instantly regain 60 energy. 30 second cooldown.
Invigorate:
    ; Add energy gain up to maximum
    ldh     a, [hEnergy]
    add     GAIN_INVIGORATE
    cp      MAX_ENERGY - 1 ; TODO: Confirm if this should be -1 or the true max
    jr      c, .notOverMax
    ; Actually set to 1 below and allow the next tick 1-5 frames away to cap us and
    ;  trigger the tilemap updates. If we set to exactly the cap the update isn't
    ;  triggered. Although a player could theoretically invigorate and then hit
    ;  another skill before the tick caps them out, the cooldown and lack of a skill
    ;  that consumes max energy means this should never been an issue.
    ld      a, MAX_ENERGY - 1
.notOverMax
    ldh     [hEnergy], a

    ld      a, FX_INVIGORATE
    call    audio_play_fx

    ; Setup buff timer
    ld      hl, wInvigorateTimer
    ld      a, FRAME_COUNTER_MAX
    ld      [hli], a
    inc     l       ; skip shift byte
    inc     l       ; skip unused high byte
    ld      a, COOLDOWN_INVIGORATE
    ld      [hli], a

    ; Force a tick to update the timer number
    call    InvigorateTimerTick

    ld      e, LOW(vBuffTiles.invigorate / 16) ; buff tile ID
    jp      DisplayBuff

; Focus
; Reduce the energy cost of all skills by 50% for 4 seconds. Invigorate cannot be used while Focus is active. 80 second cooldown.
Focus:
    ld      a, FX_FOCUS
    call    audio_play_fx

    ; Setup buff timer
    ld      hl, wFocusBuffTimer
    ld      a, FRAME_COUNTER_MAX
    ld      [hli], a
    inc     l       ; skip shift byte
    inc     l       ; skip unused high byte
    ld      a, DURATION_FOCUS
    ld      [hli], a

    ldh     [hFocusBuffActive], a    ; any non-zero value will indicate the buff is active

    ; Force a tick to update the timer number
    call    FocusBuffTimerTick

    ld      e, LOW(vBuffTiles.focus / 16) ; buff tile ID
    jp      DisplayBuff


; First Strike
FirstStrike:
    ld      a, FX_FIRST_STRIKE
    call    audio_play_fx

    ; Initialize laser animation
    ld      a, LOW(LASER_ANIMATION_LOOKUP.doubleHit)
    ldh     [hLaserLowAddr], a

    ; Flag item as used for game over screen
    ld      hl, wItemsUsed
    set     ITEMB_FIRST_STRIKE, [hl]

    ld      de, wFirstStrikeCount
    lb      bc, 100, 2
    ld      a, 220
    ; fall-through to .multiStrike

; Note: Since all 3 multi-strike items now use the same base/crit damage
;  value we could save a few bytes by not passing them, but for some reason
;  I want to leave the code generalized.
.multiStrike
    ld      hl, InputProcessing.hideMessageBoxBasedOnState
.multiStrikeOverrideJumpTarget
    push    af      ; cache critical damage value
    ld      a, [de] ; Consume item
    dec     a
    daa
    ld      [de], a

    ld      e, 1    ; All item damage shows as critical to seem more epic!
    call    ActivateRecoil

    ; Ensure the enemy animation path is updated immediately or there's a 2/3
    ;  chance we won't be due for an update and the spawning enemy vertical
    ;  position will conflict with the laser position.
    ld      a, e
    ld      [wEnemyAnimationDelay], a

    ; The enemy skill mask is generally cleared when the spawning animation
    ;  completes, but since FirstStrike/Blitz can interrupt that with a
    ;  recoil animation and bypass the .nowAlive code path, just clear it here.
    ld      a, $FF
    ldh     [hEnemySkillMask], a

    ld      d, c    ; move loop counter to `d` (to reduce pushes/pops below)
    pop     af      ; recover critical damage value
    ld      c, a    ; `bc` now contains the non-crit and crit damage values

    push    hl
.loop
    push    de

        ; Determine if the damage is critical
        ld      a, [wCriticalThreshold]
        ld      e, a
        push    bc  ; protect damage values
            call    rand
        pop     bc  ; recover damage values
        cp      e
        ld      e, 0    ; prepare for non-critical case
        ld      a, b
        jr      c, .noCritical
        ld      a, c    ; switch to critical case
        inc     e
    .noCritical
        push    bc  ; protect damage values
        call    DealDamage
        pop     bc  ; recover damage values

    pop     de
    dec     d
    jr      nz, .loop
    pop     hl

    jp      hl

; Blitz
Blitz:
    ld      a, FX_BLITZ
    call    audio_play_fx

    ; Initialize laser animation
    ld      a, LOW(LASER_ANIMATION_LOOKUP.tripleHit)
    ldh     [hLaserLowAddr], a

    ; Flag item as used for game over screen
    ld      hl, wItemsUsed
    set     ITEMB_BLITZ, [hl]
    
    ld      de, wBlitzCount
    lb      bc, 100, 3
    ld      a, 220
    jr      FirstStrike.multiStrike
    
; Final Word
FinalWord:
    ; Check if the player has already used this item
    ld      a, [wFinalWordUsed]
    or      a
    ret     nz

    ld      a, FX_FINAL_WORD
    call    audio_play_fx

    ; Since UpdateTimers is skipped while the final item panel is shown,
    ;  no laser effect can be shown. Change the description of the item
    ;  to indicate it's a verbal attack.

    ; ; Initialize laser animation
    ; ld      a, LOW(LASER_ANIMATION_LOOKUP.tripleHit)
    ; ldh     [hLaserLowAddr], a

    ; Flag item as used for game over screen
    ld      hl, wItemsUsed
    set     ITEMB_FINAL_WORD, [hl]

    ; Set a flag so the player can't just spam FinalWord until the prompt is hidden
    ASSERT(LOW(LASER_ANIMATION_LOOKUP.zap) != 0)
    ld      [wFinalWordUsed], a

    ; Jumping to hideMessageBoxTimed after multiStrike checks
    ;  the wDamageText entry before triggering GameOver, which allows
    ;  the animated damage values from FinalWord to play out before ending.

    ld      de, wFinalWordCount
    lb      bc, 100, 3
    ld      a, 220
    ld      hl, InputProcessing.hideMessageBoxTimed
    jr      FirstStrike.multiStrikeOverrideJumpTarget

; Second Wind
SecondWind:
    ; Decrement the cached version and zero the 'real' value so the player
    ;  can't use it a second time.
    ld      hl, wSecondWindCache
    xor     a       ; clear flags so `daa` works correctly
    ld      a, [hl] ; Consume item
    dec     a
    daa
    ld      [hld], a; move to wGameSpeed

    dec     l       ; move to wSecondWindCount
    xor     a
    ld      [hl], a ; zero wSecondWindCount

    ld      a, FX_SECOND_WIND
    call    audio_play_fx

    ; Flag item as used for game over screen
    ld      hl, wItemsUsed
    set     ITEMB_SECOND_WIND, [hl]
    
    ; This is all we need to do to ensure hideItemPrompt doesn't
    ;  end the game and UpdatePhysics resumes operation
    xor     a
    ldh     [hMessageBoxActive], a

    ; Avoid the player dying immediately after to the same obstacle
    ld      a, SECOND_WIND_INVULNERABLE_FRAMES
    ld      [wInvulnerableTimer], a

    ld      e, LOW(vBuffTiles.secondWind / 16) ; buff tile ID
    call    DisplayBuff

    jp      InputProcessing.hideMessageBoxDirect


; Laser animation sequences for different skills
; Each table is a sequence of:
;  - dY (relative to player Y coord)
;  - SCX
;  - height (in lines, of the laser)
; Each table is terminated with a value of $FF, and the hLaserLowAddr pointing
;  to a value of $FF will cause no laser to be shown.
; Note: All laser effects must be 16 lines or fewer to avoid raster issues
;  when the enemy is despawning!
SECTION "Laser Animation Lookup", ROMX, ALIGN[8]
LASER_ANIMATION_LOOKUP:
.inactive
    db  0
.jet
    ; Simple blip laser
    db  8, 0, 1
    db  8, 0, 2
    db  8, 0, 2
    db  8, 0, 2
    db  8, 0, 1
    db $FF
.zap
    ; Extended version of basic laser
    db  8, 0, 1
    db  8, -1, 1
    db  8, -2, 2
    db  8, -3, 2
    db  8, -3, 2
    db  8, -2, 2
    db  9, -1, 1
    db  9, 0, 1
    db  9, 0, 1
    ; db  6, 0, 5 hits line $37! Bad!
.terminator
    db $FF
.shock
    ; Fairly large laser that extends outwards and retracts
    db  6, 0, 2
    db  6, -2, 2
    db  6, -4, 2
    db  6, -6, 2
    db  5, -8, 4
    db  5, -10, 4
    db  5, -10, 4
    db  5, -8, 4
    db  6, -6, 2
    db  6, -4, 2
    db  6, -2, 2
    db  6, 0, 2
    db $FF
.discharge
    ; Fairly large laser that extends and continues
    db  6, 0, 2
    db  6, -2, 2
    db  6, -4, 2
    db  6, -6, 2
    db  5, -8, 4
    db  5, -10, 4
    db  5, -12, 5
    db  5, -14, 5
    db  6, -16, 4
    db  6, -18, 4
    db  6, -20, 3
    db  6, -22, 2
    db $FF
.electrify
    ; Laser that pulses small/large/small/large/small
    db  6, 0, 2
    db  6, -1, 3
    db  5, -2, 4
    db  5, -3, 5
    db  5, -4, 5
    db  5, -5, 4
    db  6, -6, 3
    db  6, -7, 2
    db  6, -8, 2
    db  6, -9, 3
    db  5, -10, 4
    db  5, -11, 5
    db  5, -12, 5
    db  6, -13, 4
    db  6, -14, 3
    db  6, -15, 2
    db $FF
.doubleHit
    ; Two small beams (first strike)
    db  6, 0, 1
    db  8, 0, 1
    db  6, 0, 1
    db  8, 0, 1
    db  6, 0, 1
    db  8, 0, 1
    db  6, 0, 1
    db  8, 0, 1
    db $FF
.tripleHit
    ; Three small beams (blitz and final word)
    db  4, 0, 1
    db  6, 0, 1
    db  8, 0, 1
    db  4, 0, 1
    db  6, 0, 1
    db  8, 0, 1
    db  4, 0, 1
    db  6, 0, 1
    db  8, 0, 1
    db  4, 0, 1
    db  6, 0, 1
    db  8, 0, 1
    db $FF
.end
ASSERT(LASER_ANIMATION_LOOKUP.end - LASER_ANIMATION_LOOKUP <= 256)

SECTION "Empower Duration", ROMX
EMPOWER_DURATION_BASED_ON_CHARGES:
    db 14, 19, 24, 29, 34