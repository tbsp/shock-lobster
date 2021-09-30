;
; Timer handlers for Shock Lobster
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

; These are the handlers for when timers tick/elapse
; Note: These are jumped to using `de`, and so we can safely destroy
;  `de` without pushing/popping it. `hl` and `bc` must be protected though.
; Note: The timer updating code is heavily redundant and could easily be
;  converted into a call, but we can spare the ROM and save the call time.
SECTION "Timer Handlers", ROM0

; Note: A physics delta of $10 causes things to move at 60fps. A value of $08
;  would result in objects updating at 30fps, and $20 would still update
;  at 60fps, but would update twice per frame. It's essentially a 4.4 fixed
;  point physics update value, which is used to 'smoothly' scale the
;  game speed to increase difficulty.

; Note: The engine seems to be able to handle things up to $F0, at which
;  point things go sideways and it starts feeling like slow motion before
;  falling apart when it hits zero (if un-capped).

; The max delta is meant to prevent the engine from falling apart, as we
;  expect players to mess up well before then.
DEF MAX_PHYSICS_DELTA       EQU $E0 ; Maximum physics delta
SpeedTimerTick::
    ; Speed up physics updates every N seconds, up to a maximum speed
    push    hl

    dec     l       ; `hl` starts as wSpeedTimer+4
    ld      a, [hl] ; get seconds before speed increase
    or      a
    jr      nz, .noSpeedIncrease

    push    hl      ; hl->de optimized for size
    pop     de
    ld      hl, wSpeedIncreaseSeconds
    ld      a, [hli]
    ld      [de], a ; reset delay until next speed increase
    ld      a, [hl] ; get wPhysicsUpdateDelta
    cp      MAX_PHYSICS_DELTA
    jr      z, .noSpeedIncrease
    inc     a
    ld      [hl], a

    ; Trick code we return to so it doesn't zero the frame counter
    ;  and this timer can keep running
    ld      b, 1
.noSpeedIncrease
    ; Since we bypass the `ld b,1` when we hit max speed the speed timer
    ;  will expire and stop running entirely
    pop     hl
    ret


ShockTimerTick::
    push    hl
    push    bc
    dec     l   ; `hl` starts as wShockTimer+4
    ld      a, [hl]
    ; Apply damage at 6/3/0 seconds remaining
    cp      6
    jr      z, .damageTick
    cp      3
    jr      z, .damageTick
    or      a
    jr      nz, .noDamage
.damageTick
    ld      a, [wShockDamageTick]
    ld      e, 0    ; shock dots can't crit
    call    DealDamage
.noDamage
    ; Update timer numerical display
    ld      a, [wShockTimer+3]  ; DealDamage trashes `hl` and this is faster than push/pop
    or      a
    jr      z, .timerdone
    ld      hl, SHOCK_TIME_TILEMAP
    call    bcd8bit_baa
    add     a   ; double for 8x16 tile layout
    add     $80 ; add base tile offset
    ld      b, a
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
.timerdone
    pop     bc
    pop     hl
    ret

ElectrifyTimerTick::
    push    hl
    dec     l   ; `hl` starts as wElectrifyTimer+4
    ld      a, [hl]
    push    bc
.fakeTimerValue
    and     %00000001   ; Apply damage on even ticks
    jr      nz, .noDamage

    ; determine if ticks can crit
    ld      a, [wEnabledUpgrades]
    and     UPGRADEF_RESIDUAL_CHARGE
    ld      e, 0                ; setup values for non-critical tick
    ld      a, [wElectrifyDamageTick]
    jr      z, .noCritTicks

    ld      a, [wCriticalThreshold]
    ld      e, a
    call    rand
    cp      e                   ; set flag for crit/non-crit
    ld      e, 0                ; setup values for non-critical tick
    ld      a, [wElectrifyDamageTick]
    jr      c, .noCritical
    inc     e                   ; replace with critical values
    ld      a, [wElectrifyDamageCrit]
.noCritTicks
.noCritical
    call    DealDamage
.noDamage
    call    .refreshElectrifyTimerDisplay
.generalTimerDone
    pop     bc
    pop     hl
    ret

; This is broken out into a call so we can also call it after
;  the refresh upgrade extends the duration. Sadly, due to the
;  breaking of this out we can't jump to it and rely on it
;  for the final pops/return like before, so several of the
;  other timers now call this then jump to generalTimerDone.
.refreshElectrifyTimerDisplay
    ; Update timer numerical display
    ld      a, [wElectrifyTimer+3]
    or      a
    jr      z, .electrifyDone
    ld      hl, ELECTRIFY_TIME_TILEMAP
.generalTwoDigitTimer
    call    bcd8bit_baa
    ld      c, a
    and     $0F
    add     a   ; double for 8x16 tile layout
    add     $80 ; add base tile offset
    ld      b, a
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, b
    ld      [hld], a
    ld      a, c
    swap    a
    and     $0F
    jr      z, .tensZero
    add     a   ; double for 8x16 tile layout
    add     $80 ; add base tile offset
.tensZero
    ld      b, a
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
    ret
.electrifyDone
    ld      [wRefreshCounter], a    ; Clear refresh counter for next electrify
    ret

FocusBuffTimerTick::
    push    hl
    push    bc
    dec     l   ; `hl` starts as wFocusBuffTimer+4
    ld      a, [hl]
    or      a
    jr      z, .timerDone
    ld      hl, FOCUS_BUFF_TIME_TILEMAP
    call    ElectrifyTimerTick.generalTwoDigitTimer
    jr      ElectrifyTimerTick.generalTimerDone

.timerDone
    ; Buff expired, clear flag
    xor     a
    ldh     [hFocusBuffActive], a

    ; Activate focus cooldown
    ld      a, FRAME_COUNTER_MAX
    ld      [wFocusCooldownTimer], a
    ld      a, COOLDOWN_FOCUS
    ld      [wFocusCooldownTimer+3], a

    pop     bc
    pop     hl
    ret

EmpowerTimerTick::
    push    hl
    push    bc
    dec     l   ; `hl` starts as wEmpowerTimer+4
    ld      a, [hl]
    or      a
    jr      z, ElectrifyTimerTick.generalTimerDone
    ld      hl, EMPOWER_TIME_TILEMAP
    call    ElectrifyTimerTick.generalTwoDigitTimer
    jr      ElectrifyTimerTick.generalTimerDone

InvigorateTimerTick::
    push    hl
    push    bc
    dec     l   ; `hl` starts as wInvigorateTimer+4
    ld      a, [hl]
    or      a
    jr      z, ElectrifyTimerTick.generalTimerDone
    ld      hl, INVIGORATE_TIME_TILEMAP
    call    ElectrifyTimerTick.generalTwoDigitTimer
    jr      ElectrifyTimerTick.generalTimerDone

FocusCooldownTimerTick:
    push    hl
    push    bc
    push    de
    ; Update timer numerical display
    ld      a, [wFocusCooldownTimer+3]
    or      a
    jr      z, .timerDone
    call    bcd8bit_baa
    ld      c, a
    and     $0F
    add     a   ; double for 8x16 tile layout
    add     $80 ; add base tile offset
    ld      d, a
    ld      hl, FOCUS_COOL_TIME_TILEMAP
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, d
    ld      [hld], a

    ; check hundreds first
    ld      a, b
    and     %00000011   ; upper 6 bits are undefined
    ld      b, a
    jr      nz, .haveHundreds
    ld      a, c
    and     $F0
    jr      z, .storeFinal  ; no hundreds or tens, done this entry
.haveHundreds
    ld      a, c
    swap    a
    and     $0F
    add     a   ; double for 8x16 tile layout
    add     $80 ; add base tile offset
    ld      d, a
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], d
    dec     l

    ; hundreds digit
    ld      a, b
    or      a
    jr      z, .noHundreds
    add     a   ; double for 8x16 tile layout
    add     $80 ; add base tile offset
.storeFinal
.noHundreds
    ld      d, a
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], d

    ; Since we'll never drop from 3 to 1 digit directly, there's no need to
    ;  clear up both trailing digits if the tens/hundreds are both zero.
    
.timerDone
    pop     de
    pop     bc
    pop     hl
    ret
    
    