;
; Level sequence handling for Shock Lobster
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

;INCLUDE "charmap.asm"

DEF TEXT_WIDTH_TILES EQU 18
DEF TEXT_HEIGHT_TILES EQU 3

; Exports for vwf TextScroll
EXPORT TEXT_WIDTH_TILES
EXPORT TEXT_HEIGHT_TILES
EXPORT TOP_MESSAGE_TILEMAP
EXPORT BOTTOM_MESSAGE_TILEMAP

SECTION "Level Sequence Code", ROM0
; Advance through the level sequence as required
UpdateLevelSequence:
    ld      a, [wLevelSequenceAddr]
    ld      l, a
    ld      a, [wLevelSequenceAddr+1]
    ld      h, a

.nextEvent
    ld      a, [hl]
    or      a
    ASSERT(SEQ_ENEMY == 0)
    jr      z, EventEnemy
    dec     a
    ASSERT(SEQ_BACKGROUND == 1)
    jr      z, EventBackground
    dec     a
    ASSERT(SEQ_OBSTACLE_LOOKUP == 2)
    jr      z, EventObstacleLookup
    dec     a
    ASSERT(SEQ_MESSAGE_TOP == 3)
    jr      z, EventMessageTop
    dec     a
    ASSERT(SEQ_MESSAGE_BOTTOM == 4)
    jp      z, EventMessageBottom
    dec     a
    ASSERT(SEQ_SCROLL_DELTA == 5)
    jr      z, EventScrollDelta
    dec     a
    ASSERT(SEQ_SKILL_MASK == 6)
    jr      z, EventSkillMask
    dec     a
    ASSERT(SEQ_LEVEL_CLEAR == 7)

EventLevelClear:
    ret

EventScrollDelta:
    inc     hl
    ld      a, [hli]
    ld      [wPhysicsUpdateDelta], a
    jr      UpdateLevelSequence.nextEvent

EventSkillMask:
    inc     hl
    ld      a, [hli]
    ldh     [hLevelSkillMask], a
    jr      UpdateLevelSequence.nextEvent

EventBackground:
    inc     hl
    ld      a, [hli]
    ld      [wBGTilemapPrimary], a
    ld      a, [hli]
    ld      [wBGTilemapPrimary+1], a
    ; The problem is we flip to using the new BG tilemap at a specific point,
    ;  but the player can still collect pearls from 3 columns, which may include
    ;  a mix of old/new columns. Not sure if I want to just accept this or base
    ;  while tilemap to use on which of the 3 columns we're operating on.

    ; The +2 offset gives the correct result when comparing wBGHandoffTimer to
    ;  the pearl column loop counter to seamlessly transition between backgrounds.
    ld      a, PEARL_INDEX_COLLISION_OFFSET + 2
    ld      [wBGHandoffTimer], a
    jr      UpdateLevelSequence.nextEvent

EventObstacleLookup:
    inc     hl
    ; Note: It would take more bytes to move HL to DE, rst MemcpySmall,
    ;  recover HL, and advance HL 8 bytes than just duplicating MemcpySmall
    ;  with a HL->DE copy direction, so we do that instead!
    ld      de, wObstacleSpawnLookup
    ld      c, 8
.copyLoop
    ld      a, [hli]
    ld      [de], a
    inc 	de
    dec 	c
    jr 		nz, .copyLoop
    jr      UpdateLevelSequence.nextEvent

EventEnemy:
    ldh     a, [hEnemyState]
    or      a
    ASSERT(STATE_NONE == 0)
    jr      z, .spawn
    dec     a
    ASSERT(STATE_DESPAWNED == 1)
    ret     nz
    ; Enemy despawned and we're at that enemy event, advance to the next event
    ;  and continue level sequence processing.

    ; Set new state as STATE_NONE so future enemies can spawn
    ldh     [hEnemyState], a

    ; Note: As the length of the event arguments changes, adjust the hl incrementing
    inc     hl
    inc     hl
    inc     hl
    inc     hl
    jr      UpdateLevelSequence.nextEvent

.spawn
    ; No enemy present and we're at an enemy event, spawn this enemy

    push    hl
    inc     l           ; advance to enemy index
    ld      a, [hli]    ; get enemy index

    push    hl
    ; Copy enemy tiles to VRAM
    ld      de, EnemyTiles
    add     d           ; each 32x32 enemy tile set is 256 bytes, so this is easy!
    ld      d, a
    ld      hl, vEnemyTiles
    ld      c, 0

    ; This is a brutal amount to copy at once... do we need to queue up a popslide
    ;  for VBlank, possibly in multiple passes?
    call    LCDMemcpySmall
    pop     hl

    ; Initialize enemy health
    xor     a           ; low byte always starts at zero
    ld      [wEnemyHealth], a
    ld      a, [hli]
    ld      [wEnemyHealth+1], a
    ld      a, [hl]
    ld      [wEnemyHealthShift], a
    pop     hl

    ; Set enemy as spawning
    ld      a, STATE_SPAWNING
    ldh     [hEnemyState], a

    ; Point to spawning animation path
    ld      a, LOW(EnemyAnimationPaths.spawning)
    ld      [wEnemyAnimationPath], a
    ld      a, HIGH(EnemyAnimationPaths.spawning)
    ld      [wEnemyAnimationPath+1], a

    ; Store level sequence pointer 'stalled' at this enemy event
    ld      a, l
    ld      [wLevelSequenceAddr], a
    ld      a, h
    ld      [wLevelSequenceAddr+1], a

    ret


EventMessageTop:
    push    hl

    ; Rebuild dialog border and clear lingering dialog contents
    ld      hl, TOP_DIALOG_TILEMAP
    call    DrawDialogBox

    ; Cache current raster entries we're going to overwrite for restoration later
    ld      de, wRasterLookup.bgEnable + 1
    ld      hl, wRasterCache
    ld      c, wRasterCache.end - wRasterCache
    rst     MemcpySmall

    ; Ensure we're early in the frame so the raster table is setup before
    ;  we're in the middle of it to prevent flicker
    call    _hUGE_dosound
    rst     WaitVBlank
    
    ; Alter raster entries to show message dialog over battlefield
    ld      hl, wRasterLookup.bgEnable + 1
    ld      d, SCX_TOP_DIALOG
    ld      e, WX_RIGHT_EDGE
    ld      c, LCDC_TOP_MESSAGE_DIALOG_ON
    ld      a, LY_BG_START+1

    ld      b, 3
.rasterLoop
    ld      [hl], d     ; SCX
    inc     l
    ld      [hl], e     ; WX
    inc     l
    ld      [hl], c     ; LCDC
    inc     l
    ld      [hli], a    ; LY
    inc     a
    dec     b
    jr      nz, .rasterLoop

    ; battlefield2
    ; Disable enemy so window tilemap advancement is correct
    dec     l           ; backtrack
    ld      a, LY_BG_START+$20
    ld      [hli], a    ; LY
    inc     a
    ld      [hl], d     ; SCX
    inc     l
    ld      [hl], e     ; WX
    inc     l
    ld      c, LCDC_TOP_MESSAGE_DIALOG_ON_NO_ENEMY
    ld      [hl], c     ; LCDC
    inc     l

    ; battlefield3
    ; return to 'normal' at end of dialog
    ld      a, LY_BG_START + 40 ; LY to end dialog
    ld      [hli], a    ; LY

    call    SetupTextEngine

    ; Recover and then re-store event pointer
    pop     hl
    inc     hl      ; advance to message text
    push    hl

    ld      a, TEXT_NEW_STR
    call    PrintVWFText
    ld      hl, TOP_MESSAGE_TILEMAP
    call    SetPenPosition

    call    DisplayMessage

    ; Restore laser tilemap
    ld      hl, TOP_DIALOG_TILEMAP
    ld      de, SCRN_VX_B - 8
    REPT 5
    lb      bc, LOW(vTerrainTiles / 16), 4
    call    LCDMemsetSmallFromB
    lb      bc, 0, 4
    call    LCDMemsetSmallFromB
    add     hl, de
    ENDR

    ; Restore battle raster entries
    ld      de, wRasterCache
    ld      hl, wRasterLookup.bgEnable + 1
    ld      c, wRasterCache.end - wRasterCache
    rst     MemcpySmall

    pop     hl

    ; Advance to end of message string so the next event is lined up
.messageEndLoop
    ld      a, [hli]
    cp      "<END>"
    jr      nz, .messageEndLoop

    jp      UpdateLevelSequence.nextEvent


EventMessageBottom:
    ; Alter raster entries to show message dialog over lower HUD
    push    hl

    ; Clear lingering old dialog contents
    ld      hl, BOTTOM_DIALOG_TILEMAP
    call    DrawDialogBox
    
    ldh     a, [hEnemyState]
    ASSERT(STATE_NONE == 0)
    or      a
    jr      nz, .showEnemy
    ; Hide enemy since the 2-pixel strip will be static for a while
    ld      hl, wRasterLookup.battlefield0+3
    ld      a, LCDC_HIDE_ENEMY ; switch to tilemap with blank entries in enemy region
    ld      c, 3
.hideLoop
    ld      [hli], a
    inc     l
    inc     l
    inc     l
    dec     c
    jr      nz, .hideLoop
.showEnemy

    call    ShowLowerMessageBox
    call    SetupTextEngine

    ; Recover and then re-store event pointer
    pop     hl
    inc     hl      ; advance to message text
    push    hl

    ld      a, TEXT_NEW_STR
    call    PrintVWFText
    ld      hl, BOTTOM_MESSAGE_TILEMAP
    call    SetPenPosition

    call    DisplayMessage

    ; Restore battle raster entries
    ; Just do this regardless of enemy state to save space on the enemy check
    ld      hl, wRasterLookup.battlefield0+3
    ld      a, LCDC_HIDE_ENEMY
    ld      c, 3
.showLoop
    ld      [hli], a
    inc     l
    inc     l
    inc     l
    dec     c
    jr      nz, .showLoop

    call    HideLowerMessageBox

    pop     hl

    jr      EventMessageTop.messageEndLoop

ShowLowerMessageBox::
    ld      b, LCDC_BOTTOM_MESSAGE_DIALOG_ON
.overrideLCDC::
    ld      hl, wRasterLookup.barInvigorate
    ld      a, LY_BOTTOM_MESSAGE
    ld      [hli], a    ; LY (8 pixels early)
    inc     l           ; skip SCX
    ld      a, WX_LEFT_EDGE
    ld      [hli], a    ; WX
    ld      [hl], b    ; LCDC
    inc     l

    ld      a, $FF      ; Disable following raster entry for now
    ld      [hl], a
    ret

HideLowerMessageBox::
    ld      hl, wRasterLookup.barInvigorate
    ld      a, LY_BAR_INVIGORATE
    ld      [hli], a    ; LY (8 pixels early)
    inc     l           ; skip SCX
    ld      a, WX_LOWER_HUD
    ld      [hli], a    ; WX
    ld      a, LCDC_BOTTOM_MESSAGE_DIALOG_OFF
    ld      [hli], a    ; LCDC

    ld      a, LY_BAR_FOCUS
    ld      [hli], a
    ret

SetupTextEngine:
    ; Setup VWF engine for message text
    ld      a, TEXT_WIDTH_TILES * 8 + 1
    lb      bc, LOW(vMessageTiles / 16), LOW(vMessageTiles.end / 16) - 1
    lb      de, TEXT_HEIGHT_TILES, $80
    call    TextInit

    ld      a, 2
    ld      [wTextLetterDelay], a
    ret


DisplayMessage:

    ; Print message in dedicated loop with sound still playing
.messageLoop
    call    PrintVWFChar
    call    DrawVWFChars

    ld      hl, wTextFlags
    bit     7, [hl]
    jr      z, .continueSlowly
    res     7, [hl]
    ; Toggle text speed
    ; TODO: Figure out why this isn't working!
    ld      a, [wTextLetterDelay]
    xor     8
    ld      [wTextLetterDelay], a
.continueSlowly

    call    _hUGE_dosound
    rst     WaitVBlank

    ; Check if the text is done
    ld      a, [wTextSrcPtr + 1]
    inc     a
    jr      nz, .messageLoop

    ; Wait for a final button press
.waitClose
    call    _hUGE_dosound
    rst     WaitVBlank
    ldh     a, [hPressedKeys]
    and     PADF_A
    jr      z, .waitClose

    ret

; Event constants
RSRESET
DEF SEQ_ENEMY           RB 1 ; sequence always pauses after enemy unti it's dead
DEF SEQ_BACKGROUND      RB 1 ; set a new background tilemap base address
DEF SEQ_OBSTACLE_LOOKUP RB 1 ; control which obstacles spawn
DEF SEQ_MESSAGE_TOP     RB 1 ; message dialogs pause gameplay until dismissed
DEF SEQ_MESSAGE_BOTTOM  RB 1 ; message dialogs pause gameplay until dismissed
DEF SEQ_SCROLL_DELTA    RB 1 ; scroll delta is adjustable to adjust tension
DEF SEQ_SKILL_MASK      RB 1 ; skill masks can be used to limit player skill selection
DEF SEQ_LEVEL_CLEAR     RB 1 ; all levels must end with a level clear event
;DEF SEQ_SET_TIMER       RB 1 ; set the battle timer

; Enemy constants
RSRESET
DEF ENEMY_SNAIL     RB 1
DEF ENEMY_SQUID     RB 1
DEF ENEMY_JELLYFISH RB 1
DEF ENEMY_TURTLE    RB 1
DEF ENEMY_CAT       RB 1
DEF ENEMY_DRAGON    RB 1
DEF ENEMY_TREANT    RB 1
DEF ENEMY_EYEBALL   RB 1

; Obstacle constants
RSRESET
DEF OBSTACLE_NONE       RB 1
DEF OBSTACLE_ANCHOR     RB 1
DEF OBSTACLE_CRATE      RB 1
DEF OBSTACLE_EYEBALL   RB 1

; Health constants
; Due to the current simplified way the health bar is rendered, all health
;  values are powers of two which can be easily shifted up/down to 64 (which
;  is the number of pixels in the enemy health bar).
; Note: The low byte of health is always 0, so these contain only the high byte
RSRESET
DEF HEALTH_256      EQU %00000001
DEF HEALTH_512      EQU %00000010
DEF HEALTH_1024     EQU %00000100
DEF HEALTH_2048     EQU %00001000
DEF HEALTH_4096     EQU %00010000
DEF HEALTH_8192     EQU %00100000
DEF HEALTH_16384    EQU %01000000
DEF HEALTH_32768    EQU %10000000

; Background Tilemap Offsets
DEF BG_OCEAN_FLOOR  EQU 16 * SCRN_VX_B
DEF BG_OCEAN_DEPTHS EQU 13 * SCRN_VX_B
DEF BG_OCEAN_MID    EQU 12 * SCRN_VX_B
DEF BG_FOREST_FLOOR EQU 8 * SCRN_VX_B
DEF BG_FOREST_MID   EQU 7 * SCRN_VX_B
DEF BG_FOREST_HIGH  EQU 6 * SCRN_VX_B
DEF BG_SKY          EQU 0 * SCRN_VX_B

SECTION "Level Sequence", ROMX
LevelSequence::
    db SEQ_SKILL_MASK, $FF
    db SEQ_OBSTACLE_LOOKUP, 20, OBSTACLE_ANCHOR, 255, OBSTACLE_NONE, 0, 0, 0, 0
    db SEQ_ENEMY, ENEMY_SNAIL, HEALTH_1024, HEALTH_SHIFT_1024
    db SEQ_BACKGROUND
    dw BackgroundTilemap + BG_OCEAN_FLOOR
    db SEQ_OBSTACLE_LOOKUP, 30, OBSTACLE_ANCHOR, 255, OBSTACLE_NONE, 0, 0, 0, 0
    db SEQ_ENEMY, ENEMY_SQUID, HEALTH_1024, HEALTH_SHIFT_1024
    db SEQ_BACKGROUND
    dw BackgroundTilemap + BG_OCEAN_DEPTHS
    db SEQ_OBSTACLE_LOOKUP, 20, OBSTACLE_ANCHOR, 40, OBSTACLE_CRATE, 255, OBSTACLE_NONE, 0, 0
    db SEQ_ENEMY, ENEMY_JELLYFISH, HEALTH_2048, HEALTH_SHIFT_2048
    db SEQ_BACKGROUND
    dw BackgroundTilemap + BG_OCEAN_MID
    db SEQ_OBSTACLE_LOOKUP, 10, OBSTACLE_ANCHOR, 40, OBSTACLE_CRATE, 255, OBSTACLE_NONE, 0, 0
    db SEQ_ENEMY, ENEMY_TURTLE, HEALTH_2048, HEALTH_SHIFT_2048
    db SEQ_BACKGROUND
    dw BackgroundTilemap + BG_FOREST_FLOOR
    db SEQ_OBSTACLE_LOOKUP, 20, OBSTACLE_CRATE, 255, OBSTACLE_NONE, 0, 0, 0, 0
    db SEQ_ENEMY, ENEMY_CAT, HEALTH_4096, HEALTH_SHIFT_4096
    db SEQ_BACKGROUND
    dw BackgroundTilemap + BG_FOREST_MID
    db SEQ_OBSTACLE_LOOKUP, 30, OBSTACLE_CRATE, 255, OBSTACLE_NONE, 0, 0, 0, 0
    db SEQ_ENEMY, ENEMY_DRAGON, HEALTH_4096, HEALTH_SHIFT_4096
    db SEQ_BACKGROUND
    dw BackgroundTilemap + BG_FOREST_HIGH
    db SEQ_OBSTACLE_LOOKUP, 20, OBSTACLE_CRATE, 40, OBSTACLE_EYEBALL, 255, OBSTACLE_NONE, 0, 0
    db SEQ_ENEMY, ENEMY_TREANT, HEALTH_8192, HEALTH_SHIFT_8192
    db SEQ_BACKGROUND
    dw BackgroundTilemap + BG_SKY
    db SEQ_OBSTACLE_LOOKUP, 10, OBSTACLE_CRATE, 40, OBSTACLE_EYEBALL, 255, OBSTACLE_NONE, 0, 0
    db SEQ_ENEMY, ENEMY_EYEBALL, HEALTH_32768, HEALTH_SHIFT_32768
    db SEQ_LEVEL_CLEAR
.end

SECTION "Level Sequence Variables", WRAM0
wLevelSequenceAddr::    ds 2    ; address of current level sequence event

SECTION "Pearl Sequence Index", ROMX, ALIGN[8]
DEF DEBUG_PEARL_COLLISIONS EQU 0
DEF PEARL_SEQUENCE_TERMINATOR EQU $FF
IF DEBUG_PEARL_COLLISIONS
DEF PEARL_SEQUENCE_COUNT EQU 1
ELSE
DEF PEARL_SEQUENCE_COUNT EQU 32 ; Note: Must be a power of 2!
ENDC
; Pearl sequences are blocks of pearls which can appear in the battlefield
;  for collection by the player. Only the lower 6 bits matter, with the
;  LSB appearing at the top of the battlefield, and the first row appearing
;  on the left (leading) edge of the sequence.
; I ended making a lot which are horizontal/vertical flip variations, which
;  could likely be done in code pretty easily, but it'll do for now.
PearlSequenceIndex:
    dw PearlSequences.blocks
    dw PearlSequences.blocks_flipped
    dw PearlSequences.dot_pairs
    dw PearlSequences.dots_narrow
    dw PearlSequences.zigzag
    dw PearlSequences.zigzag_flipped
    dw PearlSequences.slashes
    dw PearlSequences.slashes_flipped

    dw PearlSequences.broken_x
    dw PearlSequences.step_down
    dw PearlSequences.step_up
    dw PearlSequences.ramp_up_down
    dw PearlSequences.criss_cross
    dw PearlSequences.flowers
    dw PearlSequences.gate
    dw PearlSequences.gate_flipped

    dw PearlSequences.ticks
    dw PearlSequences.ticks_flipped
    dw PearlSequences.tets
    dw PearlSequences.tets_flipped
    dw PearlSequences.speckles
    dw PearlSequences.speckles_flipped
    dw PearlSequences.flip_flop
    dw PearlSequences.flip_flop_flipped

    dw PearlSequences.chevrons
    dw PearlSequences.chevrons_flipped
    dw PearlSequences.zigzag_broken
    dw PearlSequences.zigzag_broken_flipped
    dw PearlSequences.cups
    dw PearlSequences.cups_flipped
    dw PearlSequences.facing
    dw PearlSequences.shock

.endIndex
ASSERT(PearlSequenceIndex.endIndex - PearlSequenceIndex <= 128)

SECTION "Pearl Sequences", ROMX

PearlSequences:
.blocks
    IF DEBUG_PEARL_COLLISIONS
    INCBIN "res/pearls/solid.pearls"
    ELSE
    INCBIN "res/pearls/blocks.pearls"
    ENDC
.blocks_flipped
    INCBIN "res/pearls/blocks_flipped.pearls"
.dot_pairs
    INCBIN "res/pearls/dot_pairs.pearls"
.dots_narrow
    INCBIN "res/pearls/dots_narrow.pearls"
.zigzag
    INCBIN "res/pearls/zigzag.pearls"
.zigzag_flipped
    INCBIN "res/pearls/zigzag_flipped.pearls"
.slashes
    INCBIN "res/pearls/slashes.pearls"
.slashes_flipped
    INCBIN "res/pearls/slashes_flipped.pearls"

.broken_x
    INCBIN "res/pearls/broken_x.pearls"
.step_down
    INCBIN "res/pearls/step_down.pearls"
.step_up
    INCBIN "res/pearls/step_up.pearls"
.ramp_up_down
    INCBIN "res/pearls/ramp_up_down.pearls"
.criss_cross
    INCBIN "res/pearls/criss_cross.pearls"
.flowers
    INCBIN "res/pearls/flowers.pearls"
.gate
    INCBIN "res/pearls/gate.pearls"
.gate_flipped
    INCBIN "res/pearls/gate_flipped.pearls"

.ticks
    INCBIN "res/pearls/ticks.pearls"
.ticks_flipped
    INCBIN "res/pearls/ticks_flipped.pearls"
.tets
    INCBIN "res/pearls/tets.pearls"
.tets_flipped
    INCBIN "res/pearls/tets_flipped.pearls"
.speckles
    INCBIN "res/pearls/speckles.pearls"
.speckles_flipped
    INCBIN "res/pearls/speckles_flipped.pearls"
.flip_flop
    INCBIN "res/pearls/flip_flop.pearls"
.flip_flop_flipped
    INCBIN "res/pearls/flip_flop_flipped.pearls"

.chevrons
    INCBIN "res/pearls/chevrons.pearls"
.chevrons_flipped
    INCBIN "res/pearls/chevrons_flipped.pearls"
.zigzag_broken
    INCBIN "res/pearls/zigzag_broken.pearls"
.zigzag_broken_flipped
    INCBIN "res/pearls/zigzag_broken_flipped.pearls"
.cups
    INCBIN "res/pearls/cups.pearls"
.cups_flipped
    INCBIN "res/pearls/cups_flipped.pearls"
.facing
    INCBIN "res/pearls/facing.pearls"
.shock
    INCBIN "res/pearls/shock.pearls"