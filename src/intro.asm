;
; Main entry point for Shock Lobster
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

INCLUDE "defines.asm"
INCLUDE "engine.inc"
INCLUDE "hiscore.inc"

INCLUDE "res/obstacle_animation_paths_generated.asm"

SECTION "Tutorial", WRAM0
wDetailsPanelShown::    ds 1 ; Flag indicating if details panel has been shown
wDetailsCounter::       ds 1 ; Counter until details popup is shown

SECTION "General HRAM", HRAM

hGameMode::     ds 1 ; track active game mode
hLastMode::     ds 1 ; track last game mode (for music reinitialization)

; Temporary variables within the given scope
SECTION "Temporary HRAM", HRAM
UNION

NEXTU

ENDU

; Larger-scope variables for different game modes
SECTION "Shared HRAM", HRAM
UNION ; Room Battle
hMessageBoxActive:: ds 1 ; Flag indicating which message box is active (0=none, 1=initial, 2=final, 3=gameover)
hButtonPair::       ds 1 ; Which button pair is currently selected (0-1, pre-multipled by 4)
hDirectionBit::     ds 1 ; Bit for the current button pair
hEnergy::           ds 1 ; Current player energy
hCharges::          ds 1 ; Current charges
hAvailableSkills::  ds 1 ; Bitmask of skills the player has the resources to use
hEnemySkillMask::   ds 1 ; Skills masked off due to enemy state
hLevelSkillMask::   ds 1 ; Skills masked off due to level state (ie; tutorial)

hBGScroll::         ds 1 ; SCX value for background portion of screen (copied to various raster entries)

hEnemyWX::          ds 1 ; WX value of enemy
hEnemyStartLY::     ds 1 ; LY of start of enemy
hLaserStartLY::     ds 1 ; LY of start of laser
hLaserSCX::         ds 1 ; SCX or laser
hLaserEndLY::       ds 1 ; LY of end of laser

hFocusBuffActive::  ds 1 ; Flag indicating if focus buff is active
hObstacleActive::   ds 1 ; Flag indicating if obstacle is active
hClarityActive::    ds 1 ; Flag indicating if clarity buff is active

hPlayerYCoord::     ds 1 ; Y coordinate of top edge of player in screen space
hEnemyState::       ds 1 ; spawning/alive/despawning
hLaserLowAddr::     ds 1 ; Low byte of laser state lookup

NEXTU ; Room Loadout/Status (UpdateEnabledOverlay)
hEnabledOAMY::      ds 1 ; Y coordinate of sprites
hEnabledOAMBaseX::  ds 1 ; Base X coordinate of enabled skill/upgrade sprites
hEnabledOAMDeltaX:: ds 1 ; Delta X for each sprite added
hEnabledOAMLowByte::ds 1 ; Low byte of OAM to start inserting new entries

NEXTU ; Title
hFrameCounter::     ds 1 ; Frame counter to regulate raster animation speed
hCurveLowByte0::    ds 1 ; Low byte of curve table 0
hCurveLowByte1::    ds 1 ; Low byte of curve table 1
hSeaweedLowByte::   ds 1 ; Low byte of curve table
hSeaweedAttrs::     ds 1 ; Seaweed object attribute cache

NEXTU ; Header
hFrameCounterLogo:: ds 1 ; Frame counter to regulate animation speed
hSCYCache::         ds 1 ; Cache of SCY start value for effect
hResumeLY::         ds 1 ; LY to resume showing things
hSpriteLowByte::    ds 1 ; Low byte of sprite table pointer
hSplitLowByte::     ds 1 ; Low byte of split table pointer

ENDU


SECTION "Intro", ROMX

Intro::

    ; Init SRAM and/or load the current saved data
    call    InitSRAM

    ; Initialize random number state based on the hiscores/pearls
    ; The source values are BCD with one digit per byte. Combine
    ;  the least significant digit from each hiscore into a single
    ;  random seed byte. Also add some additional variation by
    ;  xoring with an initial, and rolling, B value.
    ld      hl, wMaxDamageScore + HISCORE_LENGTH - 2
    ld      de, randstate
    lb      bc, %01011101, 4
.seedRandLoop
    ld      a, [hli]
    swap    a
    xor     b
    ld      b, a
    ld      a, [hli]
    or      b
    ld      [de], a
    inc     de
    push    de
        ld      de, HISCORE_LENGTH - 2
        add     hl, de
    pop     de
    srl     b   ; additional variation from the `xor b`, mainly to seed titlescreen seaweed cycle
    dec     c
    jr      nz, .seedRandLoop

    ; Uncompress obstacle animation paths here since they never change, and
    ;  we might as well do it right away. 45 bytes of code, which expands
    ;  32 bytes per obstacle path to 128 bytes in WRAM.
    ld      de, CompressedObstaclePaths
    ld      hl, wObstacleAnimationPath0
    ld      c, OBSTACLE_PATH_COUNT
.obstaclePathUncompressLoop
    push    bc
        ld      c, OBSTACLE_PATH_LENGTH / 4
    .pathChunkLoop
        push    bc
            ld      a, [de]
            inc     de
            ld      b, a

            ld      c, 4
        .bitPairLoop
            xor     a
            sla     b   ; move one entry into A
            rla
            sla     b
            rla

            cp      %00000011
            jr      nz, .notNegative
            ld      a, $FF      ; convert '3' to '-1'
        .notNegative
            ;dec     a           ; Offset if we're using a PACK_OFFSET of 1
            ld      [hli], a    ; store unpacked delta value

            dec     c
            jr      nz, .bitPairLoop

        pop     bc
        dec     c
        jr      nz, .pathChunkLoop

        ld      l, c        ; prepare for next target WRAM address
    pop     bc
    inc     h       ; advance to next WRAM address
    dec     c
    jr      nz, .obstaclePathUncompressLoop
.endUncompress

    ; VWF engine init
    xor     a
    ld      [wTextCurPixel], a
    ; xor a ; ld a, 0
    ld      [wTextCharset], a
    ; xor a ; ld a, 0
    ld      c, $10 * 2
    ld      hl, wTextTileBuffer
    rst     MemsetSmall

    ; xor a
    ld      [wDetailsPanelShown], a ; Initialized here so the titlescreen doesn't 
                                    ;  overwrite it as we only want to show the
                                    ;  popup once per bootup maximum.

    ; Start on the credits screen
    ld      a, MODE_CREDITS
    ldh     [hLastMode], a
    ldh     [hGameMode], a

.modeLoop
    ld      hl, ModeEntryPoints
    ldh     a, [hGameMode]
    add     a
    add     l
    ld      l, a
    ld      a, [hli]
    ld      h, [hl]
    ld      l, a
    rst     CallHL
    jr      .modeLoop


SECTION "Mode Entry Points", ROM0, ALIGN[4]
ModeEntryPoints:
    ASSERT(MODE_CREDITS == 0)
    ASSERT(MODE_TITLE == 1)
    ASSERT(MODE_BATTLE == 2)
    ASSERT(MODE_STATUS == 3)
    dw InitTitle
    dw InitTitle
    dw InitBattle
    dw InitStatus
