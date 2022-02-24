;
; Battle gameplay for Shock Lobster
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

INCLUDE "charmap.asm"

; Debug: Disable death via obstacle collision
DEF DISABLE_OBSTACLE_DEATH EQU 0

; Wait states the battle can enter
DEF WAIT_NONE           EQU 0
DEF WAIT_INITIAL_ITEMS  EQU 1
DEF WAIT_FINAL_ITEMS    EQU 2
DEF WAIT_FALLEN         EQU 3 ; After final items so the two that aren't timer-based are trailing
DEF WAIT_GAME_OVER      EQU 4

DEF vLoadoutTiles       EQU $8B00
DEF vFallenTilemap      EQU $9D86
DEF vGameOverTilemap    EQU $9D67
DEF vAButtonTilemap     EQU $9D92
DEF vSpeedTilemap           EQU $9D61
DEF vSkillLoadoutTilemap    EQU $9DA1
DEF vUpgradeLoadoutTilemap  EQU $9DAB
DEF vItemsUsedTilemap       EQU $9D6F

; Tilemap Addresses
DEF SCORE_TILEMAP       EQU $9800
DEF PEARL_TILEMAP       EQU $9807
DEF PEARLS_TILEMAP      EQU PEARL_TILEMAP + 1
DEF ENEMY_HP_TILEMAP    EQU $980C
DEF ENEMY_TILEMAP       EQU $9820
DEF TIME_ICON_TILEMAP   EQU $98A0

DEF SPLITTER_TILEMAP    EQU $98A2
DEF CLARITY_TILEMAP     EQU $98CC
DEF ENERGY_VAL_TILEMAP  EQU $98C5
DEF ENERGY_TILEMAP      EQU $98C6
DEF CHARGE_TILEMAP      EQU $98E6

; Location of ones digit of time values for timer bars
DEF SHOCK_TIME_TILEMAP      EQU $9AC8
DEF ELECTRIFY_TIME_TILEMAP  EQU $9B08
DEF EMPOWER_TIME_TILEMAP    EQU $9B48
DEF INVIGORATE_TIME_TILEMAP EQU $9B88
DEF FOCUS_BUFF_TIME_TILEMAP EQU $9BC8
DEF FOCUS_COOL_TIME_TILEMAP EQU $9BD4

; A button skills
DEF BUTTON_ICON_SKILL_0 EQU $9928
DEF BUTTON_ICON_SKILL_1 EQU $996B
DEF BUTTON_ICON_SKILL_2 EQU $9965
DEF BUTTON_ICON_SKILL_3 EQU $99A8

; B button skills
DEF BUTTON_ICON_SKILL_4 EQU $9926
DEF BUTTON_ICON_SKILL_5 EQU $9969
DEF BUTTON_ICON_SKILL_6 EQU $9963
DEF BUTTON_ICON_SKILL_7 EQU $99A6

; DPad
DEF vDPadTilemap        EQU $9967

; Item prompts
DEF vItemTilemap        EQU $9D88
DEF vPausedTilemap      EQU $9D88
DEF vLoadoutTilemap     EQU $9D61

DEF BG_TILEMAP          EQU $99E0
DEF GROUND_TILEMAP      EQU $9AA0

DEF TOP_DIALOG_TILEMAP      EQU $9DEC
DEF TOP_MESSAGE_TILEMAP     EQU $9E0D
DEF BOTTOM_DIALOG_TILEMAP   EQU $9D40
DEF BOTTOM_MESSAGE_TILEMAP  EQU $9D61

DEF vStartTilemap           EQU $9D42

; OBJ Tile IDs
DEF TILE_B_CURSOR       EQU $10
DEF TILE_A_CURSOR       EQU $12

DEF TILE_FLICKER_BLANK  EQU $7C

; Background Tile IDs
DEF TILE_ELEC_BAR_END   EQU $1A
DEF TILE_ELEC_BAR_MID   EQU $1B
DEF TILE_BUFF_BAR_END   EQU $1C
DEF TILE_BUFF_BAR_MID   EQU $1D
DEF TILE_COOL_BAR_END   EQU $1E
DEF TILE_COOL_BAR_MID   EQU $1F

DEF TILE_SPLITTER_TOP   EQU $70
DEF TILE_SPLITTER_MID   EQU $71
DEF TILE_SPLITTER_END   EQU $72
DEF TILE_CHARGE_EMPTY   EQU $73
DEF TILE_CHARGE_FULL    EQU $74
DEF TILE_BORDER_CORNER  EQU $75
DEF TILE_BORDER_HORZ    EQU $76
DEF TILE_BORDER_VERT    EQU $77

DEF TILE_BAR_EMPTY      EQU $F0
DEF TILE_BAR_FULL       EQU $F8

; Static OAM entries
DEF OAM_LOBSTER         EQU $00
DEF OAM_B_BUTTON        EQU $02
DEF OAM_A_BUTTON        EQU $03
DEF OAM_DYNAMIC         EQU $04 ; Start of dynamically assigned OAM entries

; Gameplay Constants
DEF LOBSTER_Y_COORD_0   EQU $2C
DEF LOBSTER_X_COORD     EQU $10
DEF LOBSTER_Y_OFFSET    EQU $2D
DEF MIN_LASER_Y         EQU $18 ; Minimum LY to draw the laser (to not mess up raster effects)

DEF FRAME_COUNTER_MAX   EQU 60
DEF MAX_ENERGY          EQU 100
DEF MAX_CHARGES         EQU 5
export MAX_CHARGES

INCLUDE "defines.asm"
INCLUDE "engine.inc"
INCLUDE "hiscore.inc"

;******************************************************************************
;**                                  Variables                               **
;******************************************************************************

DEF RASTER_ENTRY_SIZE EQU 4
SECTION "Raster Lookup", WRAM0, ALIGN[8]
wLCDC::                                 ; WRAM version of hLCDC shadow register
wRasterLookup::                         ; Each entry is: LY, SCX, WX, LCDC
.vblankSetup:   ds RASTER_ENTRY_SIZE-2  ; First entry is an exception: LCDC, WX
.hudDisable:    ds RASTER_ENTRY_SIZE
.bgEnable:      ds RASTER_ENTRY_SIZE
.battlefield0:  ds RASTER_ENTRY_SIZE    ; 4 entries juggled for enemy/laser
.battlefield1:  ds RASTER_ENTRY_SIZE
.battlefield2:  ds RASTER_ENTRY_SIZE
.battlefield3:  ds RASTER_ENTRY_SIZE
.groundStart:   ds RASTER_ENTRY_SIZE
.barShock:      ds RASTER_ENTRY_SIZE
.barElectrify:  ds RASTER_ENTRY_SIZE
.barEmpower:    ds RASTER_ENTRY_SIZE
.barInvigorate: ds RASTER_ENTRY_SIZE
.barFocus:      ds RASTER_ENTRY_SIZE

wRasterCache:   ds RASTER_ENTRY_SIZE * 4
.end

; Add additional padding for the title raster effect
wRasterOverflow:ds RASTER_ENTRY_SIZE * (57 - 15)

; Special standard LCDC settings used by raster effect
DEF LCDC_HUD_ENABLE EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9800

DEF LCDC_BG_DISABLE EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGOFF | LCDCF_BG9800 | LCDCF_WINOFF | LCDCF_WIN9800
DEF LCDC_BG_ENABLE EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINOFF | LCDCF_WIN9800

DEF LCDC_ENEMY_ENABLE EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9800
DEF LCDC_ENEMY_DISABLE EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINOFF | LCDCF_WIN9800

DEF LCDC_GROUND_ENABLE EQU LCDCF_ON | LCDCF_OBJOFF | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINOFF | LCDCF_WIN9800
DEF LCDC_BAR_ENABLE_NO_OBJ EQU LCDCF_ON | LCDCF_OBJOFF | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9800
DEF LCDC_BAR_ENABLE EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9800

DEF LCDC_ENEMY_ON_NO_LASER EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9800
DEF LCDC_ENEMY_OFF_NO_LASER EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINOFF | LCDCF_WIN9800
DEF LCDC_ENEMY_ON_WITH_LASER EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9C00 | LCDCF_WINON | LCDCF_WIN9800
DEF LCDC_ENEMY_OFF_WITH_LASER EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9C00 | LCDCF_WINOFF | LCDCF_WIN9800

DEF LCDC_SHOW_ENEMY EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9800
DEF LCDC_HIDE_ENEMY EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9C00

DEF LCDC_TOP_MESSAGE_DIALOG_ON EQU LCDCF_ON | LCDCF_OBJOFF | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9C00 | LCDCF_WINON | LCDCF_WIN9C00
DEF LCDC_TOP_MESSAGE_DIALOG_ON_NO_ENEMY EQU LCDCF_ON | LCDCF_OBJOFF | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9C00 | LCDCF_WINOFF | LCDCF_WIN9800
DEF LCDC_TOP_MESSAGE_DIALOG_OFF EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9800
DEF LCDC_BOTTOM_MESSAGE_DIALOG_ON EQU LCDCF_ON | LCDCF_OBJOFF | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9C00
DEF LCDC_BOTTOM_MESSAGE_DIALOG_ON_WITH_OBJ EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9C00
DEF LCDC_BOTTOM_MESSAGE_DIALOG_OFF EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9800


; Each timer is made up of:
;  - 1 byte frame counter (counts down from 60)
;  - 1 byte shift nibbles (low nibble Timer shift, high nibble Frame shift)
;  - 2 byte BCD for wBattleTimer, 2 byte decimal (only low byte used) for all others
;  - Address of tick handler
;  - 2 padding bytes
; Note: The battle timer requires values greater than 255, but converting 16bit
;  values for BCD to display them is rather slow. The other timers are all less
;  than 255, and having them in decimal is convenient for scaling the timer bars,
;  so the 2 timer bytes can take either form. Yes, it's pretty ugly but handling
;  the two cases at once is fairly straightfoward.
DEF TIMER_SIZE              EQU 8   ; Size of each timer
DEF NUM_TIMERS              EQU 7   ; Total number of timers
;DEF LAST_BCD_TIMER  EQU 7   ; Last timer which stores BCD values (when counting down from NUM_TIMERS)
SECTION "Timers", WRAM0, ALIGN[8]
wTimers:
wSpeedTimer:        ds TIMER_SIZE
wShockTimer:        ds TIMER_SIZE
wElectrifyTimer:    ds TIMER_SIZE
wEmpowerTimer:      ds TIMER_SIZE
wInvigorateTimer:   ds TIMER_SIZE
wFocusBuffTimer:    ds TIMER_SIZE
wFocusCooldownTimer:ds TIMER_SIZE

DEF JET_COOLDOWN_MAX EQU 60     ; Frame for jet's ICD
wJetCooldownTimer:      ds 1    ; Frame counter for Jet's internal cooldown
; Some code assumed these are right after each other
ASSERT(wJetCooldownTimer - wFocusCooldownTimer == TIMER_SIZE)

DEF ENERGY_TIMER_MAX EQU 6
wEnergyTimer:       ds 1    ; Simple 6-frame counter for energy ticks
ASSERT(wEnergyTimer - wJetCooldownTimer == 1)

DEF PHYSICS_DELTA_DEFAULT EQU $10
wSpeedIncreaseSeconds:  ds 1    ; Seconds between increases to wPhysicsUpdateDelta
ASSERT(wSpeedIncreaseSeconds - wEnergyTimer == 1)
wPhysicsUpdateDelta:    ds 1    ; Value to add to physics update counter every frame
wPhysicsUpdateCounter:  ds 1    ; 4.4 counter for physics updates
wScrollCounter:         ds 1    ; A counter used to track BG/ground scroll updates (also player animation frames)
wBGScrollPearlCounter:  ds 1    ; Count BG scroll offsets up to 8 to trigger pearl updates

wAvailableItems:        ds 1    ; Bitmask of items the player has access to
DEF ITEM_USE_DURATION EQU 120 ; frames to use items
wItemUseTimer:          ds 1    ; Track how many frames the player has to use items
wInvulnerableTimer:     ds 1    ; Timer tracking how many more frames the player is invulnerable
wFinalWordUsed:         ds 1    ; Flag indicating FinalWord item has been used

; Ordered such that in several cases we can decrease the state value
;  to end up at the next logical state,
DEF STATE_NONE          EQU 0
DEF STATE_DESPAWNED     EQU 1
DEF STATE_DESPAWNING    EQU 2 ; decrements to DESPAWNED ^
DEF STATE_ALIVE         EQU 3
DEF STATE_SPAWNING      EQU 4 ; decrements to ALIVE ^
DEF STATE_RECOILING     EQU 5 ; decrements to SPAWNING, which doesn't seem to make much
                              ;  sense, but avoids performing "after enemy spawned" logic

; Number of frames between enemy animation updates
DEF ENEMY_ANIMATION_DELAY EQU 3

; Mask used to block offensive skills while enemy is dead
DEF ENEMY_DEAD_SKILL_MASK EQU SKILLF_JET | SKILLF_FOCUS | SKILLF_INVIGORATE | SKILLF_EMPOWER

SECTION "Battle State", WRAM0

wEnemyHealth:       ds 2 ; Max health = 65535 for now
wEnemyHealthShift:  ds 1 ; How many times to shift enemy health for the display value
wEnemyHealthDisplay:ds 1 ; Value used to generate current enemy health bar

wEnemyAnimationDelay:   ds 1 ; Frame delay until enemy animation updates
wEnemyAnimationPath:    ds 2 ; Pointer to current enemy animation path

wEnergyDisplay:         ds 1 ; Value used to generate current energy display bar

wShockDamageTick::      ds 1 ; Damage of a single shock tick
wElectrifyDamageTick::  ds 1 ; Damage of a single electrify tick
wElectrifyDamageCrit::  ds 1 ; Damage of a single electrify crit

wPlayerYAccel:          ds 1 ; Player vertical acceleration
wPlayerYVelocity:       ds 1 ; Player vertical velocity
wPlayerYPositionLow:    ds 1 ; Player vertical position low byte
wPlayerYPosition:       ds 1 ; Player vertical position high byte

wCriticalThreshold:     ds 1 ; Current threshold to land a critical hit
wCriticalDetonate:      ds 1 ; Current threshold to land a critical with discharged using the detonate upgrade
wRefreshCounter:        ds 1 ; Counter for how many times the refresh upgrade has triggered on this electrify

wJumpCounter:           ds 1 ; How many jumps the player has performed since on the ground

wBGTilemapPrimary:      ds 2 ; Pointer to the primary BG tilemap (where new pearls go)
wBGTilemapSecondary:    ds 2 ; Pointer to the secondary BG tilemap (where pearls are cleared from)
wBGHandoffTimer:        ds 1 ; Pearl update ticks until the secondary tilemap is set to the primary

wButtonPairCache:       ds 1 ; Cache of button pair when showing final items
wDirectionBitCache:     ds 1 ; Cache of dpad direction when showing final items

wItemsUsed:             ds 1 ; Bits indicating which items were used this game
DEF AB_CLOSE_FRAMES EQU 90  ; frames to delay until A/B can close fallen/gameover panel
wPanelCloseABCounter:   ds 1 ; Counter for to allow A to close fallen/gameover panel with A/B

; A list of dealt damage values which are shown as animated numbers on the enemy
; Each entry is made up of:
;  - Frame counter
;  - YX offset table address (incremented every frame)
;  - Y coord
;  - X coord
;  - Ones tile
;  - Tens tile ($FF = no digit)
;  - Hundreds tile ($FF = no digit)
;  - padding byte
DEF DAMAGE_TEXT_SIZE    EQU 8
DEF MAX_DAMAGE_TEXT     EQU 16
DEF DAMAGE_TEXT_FRAMES  EQU 40  ; How many frames damage text animates for
SECTION "Damage Text", WRAM0, ALIGN[8]
wDamageText:            ds DAMAGE_TEXT_SIZE * MAX_DAMAGE_TEXT
.end
wPendingDamage:     ds 2            ; Damage to add to the HiScore later on
wPendingPearls:     ds 1            ; Pearls to add to the HiScore later on 

; A list of obstacles which move toward the player and must be evaded
; Each entry is made up of:
;  - path high byte
;  - path low byte
;  - Y coord
;  - X coord
;  - tileID
;  - 3 padding bytes
SECTION "Obstacles", WRAM0, ALIGN[8]

DEF WORK_X_OFFSET               EQU $10     ; obstacle work space offset
                                            ; (to make certain calculations easier)

DEF OBSTACLE_INITIAL_Y_COORD    EQU $34     ; starting obstacle Y coord
DEF OBSTACLE_OFFSET_Y_COORD     EQU -16     ; Y coord offset per path index
DEF OBSTACLE_INITIAL_X_COORD    EQU 160 + WORK_X_OFFSET  ; starting obstacle X coord
DEF OBSTACLE_INITIAL_X_RANGE    EQU 32     ; range of possible start x coords
DEF OBSTACLE_X_HIGH_COLLIDE     EQU 36     ; x coord below which the player might collide
DEF OBSTACLE_X_LOW_COLLIDE      EQU 37-14-12  ; x coord above which the player might collide
DEF OBSTACLE_Y_COLLIDE_OFFSET   EQU 13      ; vertical collision offset when moving downwards
DEF OBSTACLE_Y_COLLIDE_UP_OFF   EQU 12      ; vertical collision offset when moving upwards (more forgiving)
DEF OBSTACLE_SIZE               EQU 8
DEF MAX_OBSTACLES               EQU 3
DEF OBSTACLE_SPAWN_COOLDOWN     EQU 10      ; Frames between individual obstacle spawn attempts
wObstacles:             ds OBSTACLE_SIZE * MAX_OBSTACLES
.end

ASSERT(wObstacles.end == wObstacleCooldownMax)
; These are after the obstacle so `hl` ends up here after spawning the obstacle
wObstacleCooldownMax:   ds 1 ; Max value for obstacle cooldown timer
wObstacleCooldownTimer: ds 1 ; Frame counter for possible new obstacle

wObstacleSpawnLookup:   ds 8 ; Current obstacle spawn lookup

SECTION "Pearl Tracking", WRAM0, ALIGN[8]
DEF PEARL_BUFFER_SIZE EQU 32
DEF NEW_PEARL_SEQUENCE_LIKELYHOOD EQU $10 ; Chance in 256 of a new pearl sequence every column
DEF PEARL_INDEX_COLLISION_OFFSET EQU 19
wPearlBuffer:       ds PEARL_BUFFER_SIZE ; Ring buffer of active pearl columns
wPearlSequenceAddr: ds 2                 ; Pointer to current pearl sequence
wLastPearlSequence: ds 1                 ; Offset of last pearl sequence used
wPearlBufferIndex:  ds 1                 ; Pointer to the low byte of the wPearlBuffer

; Aligned to facilitate popslide
SECTION "Enemy Tiles", WRAM0, ALIGN[8]
EnemyTiles:         ds 256 * 8

SECTION "Background Tilemap", WRAM0
BackgroundTilemap: ds 24 * 32
.end

SECTION "Large Tracked Values (Battle)", WRAM0, ALIGN[4]
wBattleDamage::     ds HISCORE_LENGTH ; Damage dealt in battle
wBattlePearls::     ds HISCORE_LENGTH ; Pearls collected in battle

;******************************************************************************
;**                                    Data                                  **
;*****************************************************************************

SECTION "Room Battle Data", ROM0

LOBSTER_TILES:
    INCBIN "res/gfx/lobster.2bpp"
.end

CURSOR_TILES:
    INCBIN "res/gfx/ab_cursors.2bpp"
.end

SKILL_ACTIVATE_TILES:
    INCBIN "res/gfx/skill_activate.2bpp"
.end

BUFF_TILES:
    INCBIN "res/gfx/buff_icons.2bpp"
.end

OBSTACLE_TILES:
    INCBIN "res/gfx/obstacles.2bpp"
.end

IconsTiny::
    INCBIN "res/gfx/icons_tiny.2bpp"
.end

FILLING_BAR_TILES:
    INCBIN "res/gfx/filling_bar.2bpp", 16 * 8, 16 ; only include the final full tile
.end

PEARL_TILE::
    INCBIN "res/gfx/pearl.2bpp"
.end

TIMER_BAR_TILES:
    INCBIN "res/gfx/timer_bars.2bpp"
.end

; Only compresses down from 512 to 500 bytes!
SKILL_TILES::
    INCBIN "res/gfx/skills_linear.2bpp"
.end

; Compresses down from 512 to 362 bytes, so worth it!
SKILL_TILES_DIM:
    INCBIN "res/gfx/skills_dim_linear.2bpp.pb16"
.end

LockedSkillTile::
    INCBIN "res/gfx/skill_locked_linear.2bpp"
.end

DisabledSkillTile::
    INCBIN "res/gfx/skill_disabled_linear.2bpp"
.end

BACKGROUND_TILES:
    INCBIN "res/gfx/bg0_map.2bpp.pb16"
.end

TERRAIN_TILES:
    INCBIN "res/gfx/laser_fill.2bpp"
    INCBIN "res/gfx/ground.2bpp"
.end

; The background tilemap is 16 tiles wide and compressed. It's first uncompressed
;  into WRAM, then doubled up into the final 32 tile wide state for easy use.
BackgroundTilemapCompressed:
    INCBIN "res/gfx/bg0_map.tilemap.pb16"
.end

; Compressing the enemy tiles reduced them from 1536 to 1377 bytes (159 saved),
;  with a few bytes taken to decompress them. We had lots of WRAM to spare so
;  it seems worth it.
SECTION "Enemy Tiles Compressed", ROMX, ALIGN[8]
EnemyTilesCompressed::
    INCBIN "res/gfx/enemies_linear.2bpp.pb16"
.end

PausedText:
    db " Paused<END>"

FallenText:
    db "Impending defeat...<END>"

NewHiScoreText:
    db " High Score!<END>"

GameOverText:
    db "  Game Over<END>"

;******************************************************************************
;**                                    Code                                  **
;*****************************************************************************

SECTION "Room Battle Code", ROM0
CopySkillIcon:
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, c
    ld      [hli], a
    inc     a
    ld      [hli], a
    inc     a
    add     hl, de
    ld      [hli], a
    inc     a
    ld      [hli], a
    inc     a
    add     hl, de
    ret

CopyRasterBarTilemap:
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
    inc     l
    inc     b
    ld      c, 5
    call    LCDMemsetSmallFromB
    add     hl, de
    ret

; Setup either the initial or final item panel
; Input: HL = Pointer to either wFirstStrikeCount or wFinalWordCount
; Input: D  = Message box type being shown (0=none, 1=initial, 2=final, 3=gameover)
; Input: B  = Flag if this is the initial (0) or final (4) item set
; Input: C  = Left item base tile ID (actually the second item)
; Returns: Z = Panel was not shown
SetupItemPanel:
    ld      a, [hli]
    ld      e, [hl]
    or      e
    ret     z           ; neither item present

    ld      a, d
    ldh     [hMessageBoxActive], a
    dec     l
    ld      d, [hl]     ; re-get first item count now that `d` is free

    ; Cache pair/direction so we can restore them after SecondWind use,
    ;  which only really matters if sticky dpad is disabled.
    ld      hl, wButtonPairCache
    ldh     a, [hButtonPair]
    ld      [hli], a
    ldh     a, [hDirectionBit]
    ld      [hl], a

    ; Player has at least one item, show the item prompt
    ld      a, 1
    ldh     [hDirectionBit], a  ; ensure items are usuable if a direction was active before
    ld      a, 4 * 4    ; base cursor pair for initial item skills
    add     b           ; add offset which ensures the correct skill handlers are called
    ldh     [hButtonPair], a

    ; Setup item tilemaps
    ld      hl, vItemTilemap

    ld      a, e
    or      a
    ld      e, 0    ; initialize wAvailableItems bitmask
    ld      b, LOW(vDisabledTiles / 16)
    jr      z, .noLeftItem
    ld      b, c
    set     1, e    ; flag as available
.noLeftItem
    call    SetItemIconTilemap

    ld      a, d
    or      a
    ld      b, LOW(vDisabledTiles / 16)
    jr      z, .noRightItem
    ld      a, c    ; offset left item base tile ID for right item tile ID
    sub     4
    ld      b, a
    set     0, e    ; flag as available
.noRightItem
    call    SetItemIconTilemap

    ld      hl, wAvailableItems
    ld      a, e
    ld      [hli], a
    ld      a, ITEM_USE_DURATION
    ld      [hl], a    ; wItemUseTimer

    ; Show message box with items, allow for cursor sprites
    ld      b, LCDC_BOTTOM_MESSAGE_DIALOG_ON_WITH_OBJ
    jp      ShowLowerMessageBox.overrideLCDC

; Set an item icon tilemap. Note: HL must be aligned such that the set/res trick works
; Input: B = Base tile ID
SetItemIconTilemap:
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, b
    ld      [hli], a
    inc     a
    ld      [hld], a
    inc     a
    set     5, l
    ld      [hli], a
    inc     a
    ld      [hli], a
    inc     a
    res     5, l
    ret


InitBattle::
    ; Clear lingering tile/tilemap content from credits/title screen
    ; xor     a
    ; ld      hl, vDigitTiles
    ; ld      bc, 16 * 10 * 2
    ; call    LCDMemset

    ; Update the saved game to reflect any changes made to options,
    ;  as well as unlocked/enabled skills/upgrades and items.
    call    UpdateSavedGame
   
    xor     a
    ld      hl, $9800
    ld      bc, $660
    call    LCDMemset

    ; Clear lingering status screen sprites
    ld      hl, wShadowOAM
    ld      c, OAM_COUNT * sizeof_OAM_ATTRS
    rst     MemsetSmall

    ; Disable everything for maximum VRAM access time during heavy access to follow
    ; (Prompted by the 8 sprites per line in the status screen which were pushing
    ;  the STAT handler into mode 3 at times).
    ld      a, LCDCF_ON
    call    ResetRasterLookup

    ; Uncompress BG tilemaps to EnemyTiles temporarily
    ld      de, BackgroundTilemapCompressed
    ld      hl, EnemyTiles
    INCLUDE "res/gfx/bg0_map.tilemap.pb16.size"
	ld      b, NB_PB16_BLOCKS
	PURGE NB_PB16_BLOCKS
    call    pb16_unpack_block_lcd ; Note: Not targetting VRAM, but saves having 2 routines in ROM

    ; Now copy the tilemap to the final location in WRAM, doubled up
    ld      de, EnemyTiles
    ld      hl, BackgroundTilemap
    ld      b, (BackgroundTilemap.end - BackgroundTilemap) / 32
.tilemapDuplicateLoop
    push    de
    ld      c, $10
    rst     MemcpySmall
    pop     de
    ld      c, $10
    rst     MemcpySmall
    dec     b
    jr      nz, .tilemapDuplicateLoop

    ; Unpack enemy tiles to WRAM
    ld      de, EnemyTilesCompressed
    ld      hl, EnemyTiles
    INCLUDE "res/gfx/enemies_linear.2bpp.pb16.size"
	ld      b, NB_PB16_BLOCKS
	PURGE NB_PB16_BLOCKS
    call    pb16_unpack_block_lcd ; Note: Not targetting VRAM, but saves having 2 routines in ROM

    ; TODO: Condense copies to copy sequential source/target data in fewer calls
    ; Copy tiles
    ld      de, LOBSTER_TILES
    ld      hl, vLobsterTiles
    ld      c, (LOBSTER_TILES.end - LOBSTER_TILES) & $FF
    call    LCDMemcpySmall

    ld      de, CURSOR_TILES
    ld      hl, vCursorTiles
    ld      c, CURSOR_TILES.end - CURSOR_TILES
    call    LCDMemcpySmall

    ld      c, SKILL_ACTIVATE_TILES.end - SKILL_ACTIVATE_TILES
    call    LCDMemcpySmall

    ;ld      hl, vBuffTiles
    ld      b, 5
.buffTileLoop
    ld      c, 16
    call    LCDMemcpySmall
    push    de
    ld      de, BUFF_TILES + $10 * 5    ; copy shared tile
    ld      c, 16
    call    LCDMemcpySmall
    pop     de
    dec     b
    jr      nz, .buffTileLoop

    ld      de, OBSTACLE_TILES
    ;ld      hl, vObstacleTiles
    ld      bc, OBSTACLE_TILES.end - OBSTACLE_TILES
    call    LCDMemcpy

    ASSERT(OBSTACLE_TILES.end == IconsTiny)

    ;ld      de, IconsTiny
    ld      hl, vIconsTiny
    ld      c, IconsTiny.end - IconsTiny
    call    LCDMemcpySmall

    ; Copy A button tile
    ld      de, UICursors + 16
    ld      c, 16
    call    LCDMemcpySmall

    ASSERT(vIconsTiny + IconsTiny.end - IconsTiny + 16 == vStartTiles)
    ASSERT(UICursors + 16 + 16 == StartSelectTiles)
    ;ld      de, StartSelectTiles
    ;ld      hl, vStartTiles
    ld      c, 16 * 3
    call    LCDMemcpySmall

    ld      de, ItemIcons
    ;ld      hl, vItemTiles
    ;ld      bc, ItemIcons.end - ItemIcons
    ;ld      c, 0
    call    LCDMemcpySmall

    ; Write initial score/pearl zeroes (smaller/faster than using PrintScore)
    ld      hl, SCORE_TILEMAP + 5
    ld      a, LOW(vDigitTiles / 16)
    ld      [hli], a
    ld      l, LOW(PEARLS_TILEMAP) + 3
    ld      [hl], a

    ; Called again to clear the gaps between digit tiles
    call    CopyDigitTiles

    ; Build filling bar tile variations in code to save 95 bytes of ROM space
    ; Note: Can likely be optimized for even further savings
    ld      de, FILLING_BAR_TILES ; + 16 * 8
    ld      hl, vFillingBarTiles
    lb      bc, 0, 9
.fillingBarLoop
    push    de
    push    bc

    ld      c, 2
    call    LCDMemcpySmall

    ld      c, 10
.fillingBarInnerLoop
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-

    ld      a, [de]
    inc     de
    and     b
    ld      [hli], a
    dec     c
    jr      nz, .fillingBarInnerLoop

    ld      c, 4
    call    LCDMemcpySmall

    pop     bc
    scf
    rr      b
    pop     de
    dec     c
    jr      nz, .fillingBarLoop

    ld      de, PEARL_TILE
    ;ld      hl, vPearlTile
    ld      c, 16
    call    LCDMemcpySmall
    
    ; 8 bytes to copy a tile from a 'strange' location, which beats
    ;  storing the 16 bytes again right after PEARL_TILE and copying 'for free'
    ld      de, BUFF_TILES + $10 * 3
    ;ld      hl, vClarityTile
    ld      c, 16
    call    LCDMemcpySmall

    ld      hl, vBackgroundTiles
    ld      de, BACKGROUND_TILES
    INCLUDE "res/gfx/bg0_map.2bpp.pb16.size"
	ld      b, NB_PB16_BLOCKS
	PURGE NB_PB16_BLOCKS
    call    pb16_unpack_block_lcd

    ld      de, TERRAIN_TILES
    ld      hl, vTerrainTiles
    ld      bc, TERRAIN_TILES.end - TERRAIN_TILES
    call    LCDMemcpy

    ld      de, TIMER_BAR_TILES
    ld      hl, vTimerBarTiles
    ld      c, TIMER_BAR_TILES.end - TIMER_BAR_TILES
    call    LCDMemcpySmall

    ld      de, SKILL_TILES
    ld      hl, vSkillTiles
    ld      bc, 16*4*8
    call    LCDMemcpy

    ld      de, SKILL_TILES_DIM
    INCLUDE "res/gfx/skills_dim_linear.2bpp.pb16.size"
	ld      b, NB_PB16_BLOCKS
	PURGE NB_PB16_BLOCKS
    call    pb16_unpack_block_lcd

    ld      de, UITiles
    ld      c, UITiles.end - UITiles
    call    LCDMemcpySmall

    ; Top HUD
    ld      hl, ENEMY_HP_TILEMAP
    ld      c, 8
    ld      b, TILE_BAR_FULL
    call    LCDMemsetSmallFromB
    ld      l, LOW(PEARL_TILEMAP)
    ld      a, LOW(vPearlTile / 16)
    ld      [hli], a    ; soon enough after the last LCD copy that it should be safe

    ; Write enemy tilemap
    ld      hl, ENEMY_TILEMAP
    ld      de, SCRN_VX_B - 4
    ld      b, 4
    ld      c, HIGH(vEnemyTiles) << 4 & $FF
.enemyLoop    
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, c
    ld      [hli], a
    inc     a
    ld      [hli], a
    inc     a
    push    af      ; be super careful about VRAM writes for persistent items
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    pop     af
    ld      [hli], a
    inc     a
    ld      [hli], a
    inc     a
    ld      c, a
    add     hl, de
    dec     b
    jr      nz, .enemyLoop

    ; Timer icons
    ld      hl, TIME_ICON_TILEMAP
    ld      de, SCRN_VX_B - 2
    ld      c, LOW(vSkillTiles.shock / 16)
    call    CopySkillIcon
    ld      c, LOW(vSkillTiles.electrify / 16)
    call    CopySkillIcon
    ld      c, LOW(vSkillTiles.empower / 16)
    call    CopySkillIcon
    ld      c, LOW(vSkillTiles.invigorate / 16)
    call    CopySkillIcon
    ld      c, LOW(vSkillTiles.focus / 16)
    call    CopySkillIcon

    ; Splitter
    ld      hl, SPLITTER_TILEMAP
    ld      de, SCRN_VX_B
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      b, TILE_SPLITTER_TOP
    ld      [hl], b
    add     hl, de
    inc     b
    ld      c, 8
.splitterLoop
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
    add     hl, de
    dec     c
    jr      nz, .splitterLoop
    inc     b
    ld      [hl], b

    ; Starting energy (100) value, so it's there when we fade in
    ld      hl, ENERGY_VAL_TILEMAP - 2
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, LOW(vDigitTiles / 16) + 2
    ld      [hli], a
    sub     2
    ld      [hli], a
    ld      [hli], a

    ; Energy
    ;ld      hl, ENERGY_TILEMAP
    lb      bc, TILE_BAR_FULL, 6
    call    LCDMemsetSmallFromB

    ; Charges
    ld      hl, CHARGE_TILEMAP
    lb      bc, TILE_CHARGE_EMPTY, 5
    call    LCDMemsetSmallFromB

    ; Initial skill states based on ZERO energy and ZERO charges
    ; TODO: Update when initial energy is changed to MAX!
    ld      c, %00010001
    call    UpdateSkillAvailabilityVisuals.overrideMask

    ; Start with primary/secondary tilemaps as the same
    ld      hl, wBGTilemapPrimary
    ld      a, LOW(BackgroundTilemap + 18 * 32)
    ld      [hli], a
    ld      a, HIGH(BackgroundTilemap + 18 * 32)
    ld      [hli], a
    ld      a, LOW(BackgroundTilemap + 18 * 32)
    ld      [hli], a
    ld      a, HIGH(BackgroundTilemap + 18 * 32)
    ld      [hli], a
    xor     a
    ld      [hli], a ; wBGHandoffTimer

    ; Initial background tilemap
    ld      de, BackgroundTilemap + 18 * 32
    ld      hl, BG_TILEMAP
    ld      bc, 6 * 32 ; each background tilemap is 6 rows of 32 columns
    call    LCDMemcpy

    ; DPad tiles
    ; TODO: Any way to avoid the 6 byte STAT check?
    ld      hl, vDPadTilemap
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, LOW(vUITiles / 16) + 8
    ld      [hli], a
    inc     a
    ld      [hl], a
    inc     a
    push    af      ; be super careful about VRAM writes for persistent items
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    pop     af
    ld      l, LOW(vDPadTilemap) + $20
    ld      [hli], a
    inc     a
    ld      [hl], a

    ; Ground strip
    ld      hl, GROUND_TILEMAP
    ld      b, LOW(vTerrainTiles / 16) + 1
    ld      c, 16
.groundLoop
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
    inc     l
    inc     b
    ld      [hl], b
    inc     l
    dec     b
    dec     c
    jr      nz, .groundLoop

    ; Timer bars
    ld      l, $C9  ; Move to bar start
    ld      de, SCRN_VX_B * 2 - 6
    
    ; Shock bar
    ld      b, TILE_ELEC_BAR_END
    call    CopyRasterBarTilemap

    ; Electrify bar
    dec     b
    call    CopyRasterBarTilemap

    ; Empower bar
    ld      b, TILE_BUFF_BAR_END
    call    CopyRasterBarTilemap

    ; Invigorate bar
    ld      b, TILE_COOL_BAR_END
    call    CopyRasterBarTilemap

    ; Focus buff bar
    ld      b, TILE_BUFF_BAR_END
    call    CopyRasterBarTilemap

    ; Focus cooldown bar
    ld      hl, $9BD5
    ld      b, TILE_COOL_BAR_END
    call    CopyRasterBarTilemap
    
    ; Bottom dialog border
    ld      hl, BOTTOM_DIALOG_TILEMAP
    call    DrawDialogBox

    ld      hl, vStartTilemap
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, LOW(vStartTiles / 16)
    ld      [hli], a
    inc     a
    ld      [hli], a
    inc     a
    ld      [hl], a

    ; Laser fill tilemap
    ld      hl, $9DE3
    ld      de, SCRN_VX_B - 17
    ld      b, 6
.backfillLoop
    push    bc
    lb      bc, LOW(vTerrainTiles / 16), 13
    call    LCDMemsetSmallFromB
    lb      bc, 0, 4
    call    LCDMemsetSmallFromB
    add     hl, de
    pop     bc
    dec     b
    jr      nz, .backfillLoop

    ; Load debug raster LUT
    ld      de, BaseRasterLookup
    ld      hl, wRasterLookup
    ld      c, BaseRasterLookup.end - BaseRasterLookup
    rst     MemcpySmall

    ; Initialize battle state
    ; TODO: Make as many zero-initialized variables sequential as possible
    ;  and use a memset to clear them.
    xor     a
    ldh     [hCharges], a
    ldh     [hButtonPair], a
    ldh     [hBGScroll], a
    ldh     [hLaserStartLY], a
    ldh     [hLaserSCX], a
    ldh     [hLaserEndLY], a
    ld      [wJetCooldownTimer], a
    ld      [wJumpCounter], a
    ld      [wPendingDamage], a
    ld      [wPendingDamage+1], a
    ld      [wPendingPearls], a
    ld      [wRefreshCounter], a
    ldh     [hClarityActive], a
    ldh     [hMessageBoxActive], a
    ld      [wItemsUsed], a
    ld      [wPanelCloseABCounter], a

    ; Initialize sequential bytes to zero
    ld      hl, wInvulnerableTimer
    ; wInvulnerableTimer  ; This must be zero for physics updates to occur
    ; wFinalWordUsed
    ld      c, 2
    rst     MemsetSmall

    ld      hl, wDamageText         ; Clear damage text entries
    ld      c, wDamageText.end - wDamageText
    rst     MemsetSmall

    inc     a
    ldh     [hDirectionBit], a

    ; Cache the Second Wind count for potential juggling
    ld      hl, wSecondWindCount
    ld      a, [hli]
    inc     l       ; skip wGameSpeed
    ld      [hl], a ; store in wSecondWindCache
    ASSERT(wSecondWindCache - wSecondWindCount == 2)

    ; Show the initial item prompt if the player has either of the items
    ld      hl, wFirstStrikeCount
    lb      bc, 0, LOW(vItemTiles.Blitz / 16)
    ld      d, WAIT_INITIAL_ITEMS
    call    SetupItemPanel

    ld      a, OAM_DYNAMIC * sizeof_OAM_ATTRS
    ld      [wOAMIndex], a          ; Initialize dynamic OAM pointer
    ld      a, (OAM_COUNT) - 1 * sizeof_OAM_ATTRS
    ld      [wOAMEndIndex], a       ; set this so the full OAM is cleared the first pass

    ld      hl, wBattleDamage
    call    ResetHiScore
    ld      hl, wBattlePearls
    call    ResetHiScore

    ; Assign critical thresholds
    ld      hl, wCriticalThreshold
    ld      b, CRITICAL_THRESHOLD   ; setup for case without upgrade
    ld      c, CRITICAL_THRESHOLD_DETONATE
    ld      a, [wEnabledUpgrades]
    and     UPGRADEF_EXPERTISE
    jr      z, .noExpertiseUpgrade
    ld      b, CRITICAL_THRESHOLD_EXPERTISE
    ld      c, CRITICAL_THRESHOLD_EXPERTISE_DETONATE
.noExpertiseUpgrade
    ld      [hl], b
    inc     l
    ld      [hl], c

    ; In order to have pearl collisions occur when the player sprite
    ;  hits them, we start the pearl scroll counter offset slightly
    ld      a, 4
    ld      [wBGScrollPearlCounter], a

    ld      a, MAX_ENERGY           ; Start at full energy
    ldh     [hEnergy], a

    ld      hl, wEnergyTimer
    ld      a, ENERGY_TIMER_MAX
    ld      [hli], a

    ld      a, [wGameSpeed]
    add     a                       ; GameSpeed*2
    ld      b, a

    ; 16 - speed*2 = 14, 12, 10 seconds per increase

    ; Demos speed curves (R=16)
    ; - x/(R-2) + $10
    ; - x/(R-4) + $14
    ; - x/(R-6) + $18
    ; Time to delta (mins) = (delta - (12 + spd*4)) * (R - spd*2) / 60
    DEF BASE_R EQU 16

    ; Reaches delta of 50 at: 4.33, 6, 7.93 minutes
    cpl
    add     BASE_R + 1
    ld      [hli], a
    ; Max pure-jump speed from basic testing: 56 delta (3.5x base of 16)

    ; Start deltas are: $10, $14, $18
    ld      a, b                    ; GameSpeed*4
    add     a
    add     PHYSICS_DELTA_DEFAULT - 4
    ld      [hli], a                ; default physics timer delta
    xor     a                       ; Start at zero charges
    ld      [hli], a                ; physics scroll counter
    ld      [hli], a                ; wScrollCounter

    ; Start with no active pearls
    ld      hl, wPearlBuffer
    ld      c, PEARL_BUFFER_SIZE + 3 ; clear the wPearlBuffer, wPearlSequenceAddr
    rst     MemsetSmall
    
    ASSERT(STATE_NONE == 0)
    ;xor     a
    ldh     [hEnemyState], a        ; STATE_NONE
    ld      [wEnemyHealthDisplay], a
    ld      [wEnergyDisplay], a
    ldh     [hFocusBuffActive], a

    ; Clear obstacle entries
    ; TODO: Make this dynamic based on MAX_OBSTACLES
    ld      [wObstacles], a
    ld      [wObstacles + OBSTACLE_SIZE], a
    ld      [wObstacles + OBSTACLE_SIZE * 2], a

    ld      [wPlayerYAccel], a
    ld      [wPlayerYVelocity], a
    ld      [wPlayerYPositionLow], a
    ld      [wPlayerYPosition], a

    dec     a   ; ld a, $FF
    ld      hl, wLastPearlSequence  ; Make sure the first pearl sequence added doesn't conflict
    ld      [hli], a

    ; Start adding new pearl sequences at tile 22
    ASSERT(wLastPearlSequence + 1 == wPearlBufferIndex)
    ld      a, 22
    ld      [hl], a     ; wPearlBufferIndex

    ld      a, ENEMY_DEAD_SKILL_MASK
    ldh     [hEnemySkillMask], a
    ldh     [hLevelSkillMask], a

    ; Copy over tiles for locked skills
    ld      a, [wEnabledSkills]
    ld      c, a
    ld      de, SkillButtonTilemapsAndTiles
    ld      b, 8
.skillButtonLoop
    inc     de          ; skip low byte of tilemap
    inc     de          ; skip high byte of tilemap
    ld      a, [de]     ; get enabled tileID
    inc     de

    srl     c           ; shift current skill bit into carry flag
    jr      c, .skillUnlocked

    push    de
    push    bc

    ; Calculate address of base tile
    swap    a
    ld      l, a
    and     $0F
    add     HIGH(vSkillTilesDim) & $F0
    ld      h, a
    ld      a, l
    and     $F0
    ld      l, a

    ; Copy locked tile over this tile data
    ld      de, DisabledSkillTile
    ld      c, $40
    call    LCDMemcpySmall

    ; Offset to dimmed tile
    ld      de, $200 - $40
    add     hl, de

    ; Copy locked tile over this tile data
    ld      de, DisabledSkillTile
    ld      c, $40
    call    LCDMemcpySmall

    pop     bc
    pop     de

.skillUnlocked
    dec     b
    jr      nz, .skillButtonLoop

    ld      a, LOBSTER_Y_COORD_0
    ldh     [hPlayerYCoord], a
    ld      a, LOW(LASER_ANIMATION_LOOKUP.inactive)
    ldh     [hLaserLowAddr], a

    ld      a, 1    ; 1 will make this udpate on the first pass
    ld      [wEnemyAnimationDelay], a
    ld      a, LOW(EnemyAnimationPaths.terminated-2) ; start 1 entry before the terminator
    ld      [wEnemyAnimationPath], a
    ld      a, HIGH(EnemyAnimationPaths.terminated-2)
    ld      [wEnemyAnimationPath+1], a

    ; Init level
    ld      de, TimerTemplate       ; Copy timer template to get handler addresses alongside timers
    ld      hl, wTimers
    ld      c, NUM_TIMERS * TIMER_SIZE
    rst     MemcpySmall

    ld      a, 100                  ; TODO: Control via level sequence
    ld      [wObstacleCooldownTimer], a
    ld      [wObstacleCooldownMax], a

    ; Perform an initial level sequence update to load the battle timer and start
    ;  off the first enemy so the main loop doesn't run into anything strange.
    call    UpdateLevelSequence

    ; Init music
    ld      hl, song_battle_0
    call    hUGE_init

    ; Initial PPU state
    xor     a
    ldh     [rWY], a

    ld      a, 14*8-4
    ldh     [hSCY], a
    xor     a
    ldh     [hSCX], a

    ; Disable VBlank updating audio so we can handle it ourselves
    ldh     [hVBlankUpdateAudio], a

    ; Ensure cursor/player are properly positioned before FadeIn
    call    UpdateCursor
    call    UpdatePlayerSprite
    ld      a, HIGH(wShadowOAM)
    ldh     [hOAMHigh], a

    call    FadeIn

; ===== Battle Loop =====
RoomBattle::

    call    InputProcessing

    ; There's so much going on here we just queue OAM DMA every frame
    ; Also do this early in the frame since a Game Over state without items
    ;  jumps directly to the end state and doesn't finish the full loop.
    ld      a, HIGH(wShadowOAM)
    ldh     [hOAMHigh], a
   
    ; If the final items or game over is shown don't perform certain updates
    ldh     a, [hMessageBoxActive]
    cp      WAIT_FINAL_ITEMS
    jr      nc, .skippedUpdates

    call    UpdateTimers        ; called early enough to update raster table in time
    call    UpdateSkillAvailability
    call    UpdatePhysics
    call    UpdatePlayerSprite
.skippedUpdates

    ; These updates must be called even when the final item prompt is shown
    call    UpdateCursor        ; called so the item cursor is properly located
    call    UpdateDynamicOAM    ; called so animated damage is updated
    call    UpdateScore         ; called so damage from FinalWord is added

    call    UpdateEnemyHealth   ; called so enemy health drops from FinalWord
    call    UpdateLevelSequence ; always called after UpdateEnemyHealth (TODO: merge?)

    call    audio_update
    call    _hUGE_dosound

    rst     WaitVBlank
    call    UpdateSkillAvailabilityVisuals  ; Note: Now checks for VRAM access

    jr      RoomBattle

; This uses VRAM-safe copies because it's also used in the level sequence
;  message code
DrawDialogBox:
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, TILE_BORDER_CORNER
    ld      [hli], a
    ld      b, a
    inc     b
    ld      c, 18
    call    LCDMemsetSmallFromB
    dec     b
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
    ld      de, SCRN_VX_B - 19
    add     hl, de
    inc     b
    inc     b

    ld      c, 3
.dialogLoop
    push    bc
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
    inc     l
    lb      bc, 0, 18
    call    LCDMemsetSmallFromB
    ld      b, TILE_BORDER_VERT
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
    add     hl, de
    pop     bc
    dec     c

    jr      nz, .dialogLoop
    ld      b, TILE_BORDER_CORNER
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
    inc     l
    inc     b
    ld      c, 18
    call    LCDMemsetSmallFromB
    dec     b
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
    ret

; Update a byte mask indicating which skills are currently available for use,
;  which is then used to visually dim unavailable skills and block activation
;  of skills by the player. Skills are available if the player has sufficient
;  energy to use them, and at least 1 charge for skill which consume charges.
;  Invigorate and Focus are unique in that they have cooldowns, and so also
;  must not have an active timer to be available.
UpdateSkillAvailability:
    ; Note: I wanted to avoid loading hEnergy/hCharges each pass, but the
    ;  compare has to be done with them in `a` for the carry flag to work
    ;  correctly for >=, so oh well.
    ld      hl, SkillRequirements
    lb      bc, %00000001, 8    ; bit of current skill and loop counter
    ld      d, $00000000    ; bits representing available skills
.loop
    ldh     a, [hClarityActive]
    or      a
    ld      a, [hli]        ; get energy cost of skill and advance `l` without affecting flags
    jr      nz, .clarityActive
    ld      e, a
    ldh     a, [hFocusBuffActive]
    or      a
    jr      z, .noFocusBuff
    sra     e   ; Halve energy cost if focus buff is active
.noFocusBuff
    ldh     a, [hEnergy]
    cp      e
    jr      c, .notAvailable
.clarityActive
    ld      a, [hl]         ; get charge cost of skill (don't increment intentionally)
    ld      e, a
    ldh     a, [hCharges]
    cp      e
    jr      c, .notAvailable
    ld      a, d    ; or the current skill's bit onto the available bit mask
    or      b
    ld      d, a
.notAvailable
    inc     l       ; advance to next skill's energy requirement
    sla     b       ; advance to next skill's bit
    dec     c
    jr      nz, .loop

    ; Check invigorate/focus cooldowns
    ; TODO: Can we merge these two resets somehow?
    ld      a, [wInvigorateTimer]
    or      a
    jr      z, .invigorateOffCooldown
    res     6, d    ; invigorate is not available if on cooldown
.invigorateOffCooldown
    ldh     a, [hFocusBuffActive]
    or      a
    jr      z, .focusBuffInactive
    res     7, d    ; focus is not available if the buff is active
    res     6, d    ; invigorate is not available if the focus buff is active
.focusBuffInactive

    ld      a, [wFocusCooldownTimer]
    or      a
    jr      z, .focusOffCooldown
    res     7, d    ; focus is not available if on cooldown
.focusOffCooldown

    ; Disable skills which aren't enabled
    ld      a, [wEnabledSkills]
    and     d
    ld      d, a

    ; Disable skills due to enemy not being present
    ldh     a, [hEnemySkillMask]
    and     d
    ld      d, a

    ; Disable skills based on level restrictions
    ldh     a, [hLevelSkillMask]
    and     d

    ldh     [hAvailableSkills], a
    ret

; Update background tiles to reflect which skills can be used.
UpdateSkillAvailabilityVisuals:
    ; TODO: xor old/new available skills to only update changed items
    ;  and reduce precious VRAM access time.
    ld      a, [hAvailableSkills]   ; active skills mask
    ld      c, a
.overrideMask
    ld      de, SkillButtonTilemapsAndTiles
    ld      b, 8
.skillButtonLoop
    ld      a, [de]     ; get low byte of tilemap
    ld      l, a
    inc     de
    ld      a, [de]     ; get high byte of tilemap
    ld      h, a
    inc     de
    ld      a, [de]     ; get enabled tileID
    inc     de

    srl     c           ; shift current skill bit into carry flag
    jr      c, .skillActive
    add     DISABLED_TILE_OFFSET
.skillActive
    push    bc
        ld      c, a
    :   ldh     a, [rSTAT]
        and     STATF_BUSY
        jr      nz, :-
        ; The following code is 17 cycles, which is VRAM safe with a single check
        ld      a, c
        ld      [hli], a
        inc     a
        ld      [hli], a
        inc     a
        ld      bc, SCRN_VX_B - 2
        add     hl, bc
        ld      [hli], a
        inc     a
        ld      [hli], a
    pop     bc
    dec     b
    jr      nz, .skillButtonLoop

    ret

; Update all timers, and trigger results of timers expiring, which includes:
;  - Level timer (energy ticks on rollover)
;  - Dot ticks (damage dealt every 2/3 seconds)
;  - Cooldowns (skill becomes available)
; I suspect there's a more elegant way to handle a bunch of out-of-sync timers
;  which trigger events/changes on N-second boundaries, but this'll do for now.
UpdateTimers:

; The raster table is updated first because in very rare circumstances it can
;  take long enough to result in LY getting ahead of LYC, leading to a single
;  frame of a huge laser block filling the battlefield. This is only possible
;  wight lasers fired at high LY (~15) or so, but since moving the raster
;  update earlier it hasn't been observed.
.updateBattlefieldRasters
    ; Update the overloaded battle raster region (background, enemy, laser)

    ; Enemy animation is only updated every N frames
    ld      hl, wEnemyAnimationDelay
    dec     [hl]
    jr      nz, .noEnemyAnimationUpdate
    ld      a, ENEMY_ANIMATION_DELAY
    ld      [hl], a

    ; Get pointer to current path entry
    ld      a, [wEnemyAnimationPath]
    ld      l, a
    ld      a, [wEnemyAnimationPath+1]
    ld      h, a

    ld      a, [hl]     ; get LY/terimator
    cp      ENEMY_PATH_TERMINATED   ; check for terminated path
    jr      z, .pathTerminated

    ld      a, [hli]    ; store new values for use by raster update pass
    ldh     [hEnemyStartLY], a
    ld      a, [hli]
    ldh     [hEnemyWX], a

    ld      a, [hl]
    cp      ENEMY_PATH_LOOP         ; check for looping path
    jr      nz, .notLooping
    ; Load delta from table (always <256 bytes)
    inc     hl      ; advance to offset byte
    ld      d, $FF
    ld      a, [hl]
    ld      e, a
    add     hl, de  ; offset pointer

.notLooping
    ; Store new path pointer
    ld      a, l
    ld      [wEnemyAnimationPath], a
    ld      a, h
    ld      [wEnemyAnimationPath+1], a
    jr      .doneEnemyAnimationUpdate

.pathTerminated
    ; All terminated paths automatically decrement their state when terminated
    ldh     a, [hEnemyState]
    dec     a
    ldh     [hEnemyState], a
    cp      STATE_ALIVE
    jr      nz, .setToIdleAnimation
.nowAlive
    ; Stop restricting player skills now the enemy is present
    ld      a, $FF
    ldh     [hEnemySkillMask], a

    ; Clear all charges once the new enemy has spawned
    ; (player can use them on empower during despawn/spawn)
    ldh     a, [hCharges]
    or      a
    jr      z, .noChargesToClear
    ld      e, a
    xor     a
    ldh     [hCharges], a

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
.noChargesToClear

.setToIdleAnimation
    ; Set to enemy idle animation path
    ld      a, LOW(EnemyAnimationPaths.idleFloat)
    ld      [wEnemyAnimationPath], a
    ld      a, HIGH(EnemyAnimationPaths.idleFloat)
    ld      [wEnemyAnimationPath+1], a

.doneEnemyAnimationUpdate
.noEnemyAnimationUpdate
    
    ; Update laser animation
    ld      h, HIGH(LASER_ANIMATION_LOOKUP)
    ldh     a, [hLaserLowAddr]
    ld      l, a
    ld      a, [hli]; get dY value
    or      a
    jr      z, .noLaserAnimationUpdate
    cp      $FF
    jr      nz, .showLaser
    ; Laser frames are done, disable laser
    inc     a   ; ld a, 0 [should match LOW(LASER_ANIMATION_LOOKUP.inactive)]
    ldh     [hLaserLowAddr], a
    ldh     [hLaserStartLY], a

    jr      .doneLaserAnimationUpdate

.showLaser
    ld      c, a
    ldh     a, [hPlayerYCoord]
    add     c
    ; It shouldn't be possible to jump high enough to need this
;     cp      MIN_LASER_Y
;     jr      nc, .laserSafe
;     ld      a, MIN_LASER_Y
; .laserSafe
    ld      c, a
    ldh     [hLaserStartLY], a
    ld      a, [hli]    ; get laser SCX value
    ldh     [hLaserSCX], a
    ld      a, [hli]    ; get laser height
    add     c           ; add start line to height
    ldh     [hLaserEndLY], a
    
    ld      a, l        ; update laser low address byte for next frame
    ldh     [hLaserLowAddr], a

.doneLaserAnimationUpdate
.noLaserAnimationUpdate

    ; We have 4 general purpose 'battlefield' raster effect lines which are
    ;  used to position the enemy and laser. They also have to include the
    ;  current hBGScroll value when not showing the laser.

    ; There HAS to be a more efficient way to do this, which is a strange
    ;  kind of sorting problem, I think? It'd be much simpler if the laser
    ;  width wasn't variable.

    ; TODO: See if this whole thing could be cleaned up with a simple LUT.

    ld      hl, wRasterLookup.bgEnable + 1
    ld      a, [hBGScroll]
    ; This is updated here because UpdatePhysics would update it slightly out
    ;  of sync and result in tearing.
    ld      [hli], a
    inc     l
    inc     l

    ldh     a, [hLaserStartLY]
    or      a
    jr      nz, .activeLaser
    ; If there's no laser (which is the most common state) we just start the 
    ;  enemy, repeat that line twice, then end the enemy
    ldh     a, [hEnemyStartLY]
    ld      [hli], a
    inc     a
    ld      c, a    ; for next raster entry
    ldh     a, [hBGScroll]
    ld      [hli], a
    ld      b, a
    ldh     a, [hEnemyWX]
    ld      [hli], a
    ld      e, a
    ld      a, LCDC_ENEMY_ON_NO_LASER
    ld      [hli], a
    ld      d, $20-2  ; dLY we'll need to reach the enemy end LY later

    ld      [hl], c ; LY
    inc     c       ; for next raster entry
    inc     l
    ld      [hl], b ; SCX
    inc     l
    ld      [hl], e ; WX
    inc     l
    ld      [hli], a; LCDC

    jr      .fill2RasterEntries
    
.activeLaser
    ; When there's an active laser we need to figure out if the laser is before,
    ;  at, or after the enemy start or end, and use the raster entries in the
    ;  correct order (or share them as needed).

    ld      c, a    ; cache hLaserStartLY
    ldh     a, [hEnemyStartLY]
    cp      c
    jp      c, .enemyStartsFirst ; TODO: change to jr if we can clean this mess up
    jr      z, .enemyStartsWhenLaserStarts
.enemyStartsSecond
    ld      d, a        ; cache hEnemyStartLY
    ld      a, c        ; recover hLaserStartLY
    ld      [hl], a
    inc     l
    ldh     a, [hLaserSCX]
    ld      b, a
    ld      [hli], a
    ld      a, WX_OFF_SCREEN    ; ensure WX is off-screen to avoid SCX overlap bug
    ld      [hli], a
    ld      a, LCDC_ENEMY_OFF_WITH_LASER
    ld      [hli], a

    ldh     a, [hLaserEndLY]
    cp      d
    jr      c, .laserEndsBeforeEnemyStarts
    jr      z, .laserEndsWhenEnemyStarts
.enemyStartsBeforeLaserEnds
    ld      c, a        ; cache hLaserEndLY
    ld      [hl], d     ; LY (hEnemyStartLY)
    inc     l
    ld      [hl], b     ; SCX
    inc     l
    ldh     a, [hEnemyWX]
    ld      [hli], a    ; WX
    ld      e, a
    ld      a, LCDC_ENEMY_ON_WITH_LASER
    ld      [hli], a    ; LDCD

    ldh     a, [hBGScroll]
    ld      b, a

    ld      a, c         ; calculate dLY to get to hEnemyEndLY
    cpl
    add     $21
    add     d
    ld      d, a

    ld      a, LCDC_ENEMY_ON_NO_LASER

    jr      .fill2RasterEntries

.laserEndsBeforeEnemyStarts
    ld      [hli], a    ; LY
    ldh     a, [hBGScroll]
    ld      [hli], a    ; SCX
    ld      b, a
    ld      a, WX_OFF_SCREEN    ; ensure WX is off-screen to avoid SCX overlap bug
    ld      [hli], a
    ld      a, LCDC_ENEMY_OFF_NO_LASER
    ld      [hli], a

    ldh     a, [hEnemyStartLY]
    ld      c, a
    ld      d, $20
    ldh     a, [hEnemyWX]
    ld      e, a
    ld      a, LCDC_ENEMY_ON_NO_LASER

    ; Centrally located wrap up code to stick with relative jumps
.fill2RasterEntries
    ld      [hl], c ; LY
    inc     l
    ld      [hl], b ; SCX
    inc     l
    ld      [hl], e ; WX
    inc     l
    ld      [hli], a; LCDC

    ld      a, c
    add     d       ; add dLY to get to enemy end LY
    ld      [hli], a; LY
    ld      [hl], b ; SCX
    inc     l
    ld      [hl], e ; WX
    inc     l
    ld      a, LCDC_ENEMY_OFF_NO_LASER
    ld      [hl], a ; LCDC

    jr      .doneBattlefieldRasters


.laserEndsWhenEnemyStarts
    ld      [hli], a    ; LY
    inc     a
    ld      c, a
    ldh     a, [hBGScroll]
    ld      [hli], a    ; SCX
    ld      b, a
    ldh     a, [hEnemyWX]
    ld      [hli], a    ; WX
    ld      e, a
    ld      a, LCDC_ENEMY_ON_NO_LASER
    ld      [hli], a
    ld      d, $1F

    jr      .fill2RasterEntries

.enemyStartsWhenLaserStarts
    ld      [hli], a
    add     $21
    ld      d, a    ; prep EnemyEndLY for later

    ldh     a, [hLaserSCX]
    ld      [hli], a
    ld      b, a
    ldh     a, [hEnemyWX]
    ld      [hli], a
    ld      e, a
    ld      a, LCDC_ENEMY_ON_WITH_LASER
    ld      [hli], a

    ldh     a, [hLaserEndLY]
    ld      [hli], a; LY
    inc     a
    ld      c, a    ; for next raster entry
    cpl             ; calculate dLY to get to hEnemyEndLY
    add     d
    ld      d, a    ; dLY
    ld      [hl], b ; SCX
    ldh     a, [hBGScroll]
    ld      b, a    ; setup for next raster
    inc     l
    ld      [hl], e ; WX
    inc     l
    ld      a, LCDC_ENEMY_ON_NO_LASER
    ld      [hli], a; LCDC


    ; Now we can reuse some code above, since it's the same!
    jr      .fill2RasterEntries

.enemyStartsFirst
    ; Enemy starts before the laser
    ld      [hli], a
    ld      d, a        ; cache hEnemyStartLY for later
    ldh     a, [hBGScroll]
    ld      [hli], a
    ld      b, a
    ldh     a, [hEnemyWX]
    ld      [hli], a
    ld      e, a
    ld      a, LCDC_ENEMY_ON_NO_LASER
    ld      [hli], a

    ; TODO: Deal with laser starting AFTER enemy end (ew)
    ; -> Also laser ending AT enemy end!
    ; (maybe we just keep the enemy from moving up and avoid this...)

    ld      a, c        ; retrieve hLaserStartLY
    ld      [hli], a    ; LY
    ldh     a, [hLaserSCX]
    ld      [hli], a    ; SCX
    ld      [hl], e     ; WX
    inc     l
    ld      a, LCDC_ENEMY_ON_WITH_LASER
    ld      [hli], a

    ; Setup for last two entries
    ldh     a, [hLaserEndLY]
    ld      c, a        ; LY for 3rd entry

    cpl                 ; calculate dLY to get to hEnemyEndLY
    add     d
    add     $21
    ld      d, a        ; dLY
    
    ld      a, LCDC_ENEMY_ON_NO_LASER
    jr      .fill2RasterEntries

.doneBattlefieldRasters

    ; The BG enable STAT interrupt fires at LY==$0B, if the player jumps, shoots,
    ;  and procs Clarity there's a chance the raster table entries won't be setup
    ;  correctly in time to set the new LYC value for the laser and we'll end up
    ;  out of sync, causing a single-frame flicker.

    ; To resolve this, if LY_BG_START < LY < LY_GROUND when we get here, explicitly
    ;  set LYC to the LY value in wRasterLookup.battlefield0, to ensure the
    ;  interrupt fires at the intended time.
    
    ; Note that we could compare LY to the LY from wRasterLookup.battlefield0,
    ;  to not 'fix' LYC in a variety of other cases, but we'd still have to compare
    ;  against LY_GROUND, and juggle the rLY value a bit, so this is fine.
    ldh     a, [rLY]
    cp      LY_GROUND
    jr      nc, .notBeforeBFGround
    cp      LY_BG_START
    jr      c, .notPastBF0
    ld      a, [wRasterLookup.battlefield0]
    ldh     [rLYC], a
.notBeforeBFGround
.notPastBF0

.updateMainTimers
    ld      hl, wTimers
    ld      c, NUM_TIMERS
.tickLoop
    push    bc
    ; For each timer:
    ; - Decrement frame counter
    ; - If zero, reset counter and decrement timer
    xor     a
    cp      [hl]
    jr      z, .timerInactive
    dec     [hl]
    jr      nz, .noRollover
    ld      a, FRAME_COUNTER_MAX
    ld      [hli], a

    inc     l       ; skip shift byte

    ;ld      a, c
    ;cp      LAST_BCD_TIMER
    ;jr      c, .decimalTimer

    ; ; Decrement 3-digit BCD value
    ; inc     l   ; advance to ones/tens byte
    ; ld      a, [hl]
    ; sub     1       ; subtract 1
    ; daa             ; convert result back to BCD
    ; ld      [hld], a
    ; ld      b, a
    ; ld      a, [hl]
    ; sbc     0       ; subtract carry from tens/hundreds byte
    ; daa
    ; ld      [hli], a
    ; ld      c, a
    ; jr      .advanceBCD

.decimalTimer
    ; Decrement 16-bit timer value
    ld      d, [hl]
    inc     l
    ld      e, [hl]
    dec     de
    ld      b, d    ; cache for zero check later
    ld      c, e
    ld      [hl], e
    dec     l
    ld      [hl], d
    inc     l

;.advanceBCD
    inc     l       ; advance to decrement handler address

    ; Call handler on decrement for this timer
    ld      a, [hli]
    ld      e, a
    ld      a, [hld]
    ld      d, a
    rst     CallDE

    ld      a, b
    or      c
    jr      nz, .timerNotZero

    ; Clear frame counter for this timer so it stops running
    dec     l
    dec     l
    dec     l
    dec     l
    
    xor     a
    ld      [hl], a

.timerNotZero
.timerInactive
.noRollover
    ld      a, l    ; advance to next timer
    or      TIMER_SIZE-1
    ld      l, a
    inc     l

    pop     bc
    dec     c
    jr      nz, .tickLoop

    ; Note: We end up with hl=wJetCooldownTimer after the prior loop
    xor     a
    cp      [hl]        ; `hl` should be pointing to the jet ICD timer
    jr      z, .jetTimerZero
    dec     [hl]
.jetTimerZero
    inc     hl

    ; Handle energy ticks
    ; Note: We end up with hl=wEnergyTimer after the prior code block
    dec     [hl]
    jp      nz, .noEnergyTick
    ld      a, ENERGY_TIMER_MAX
    ld      [hli], a

    ; Gain 1 energy if we're not at the maximum
    ldh     a, [hEnergy]
    cp      MAX_ENERGY
    jp      z, .maxEnergy
    inc     a
    ldh     [hEnergy], a

    ; Update energy value display
    ld      e, a    ; cache for bar update below
    call    bcd8bit_baa
    ld      hl, ENERGY_VAL_TILEMAP
    ld      c, a
    and     $0F
    add     a
    add     $80
    ld      d, a
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], d
    dec     l

    ; tens digit tile
    ; first check if we have a hundreds digit
    ld      a, b
    and     %00000011   ; upper 6 bits are undefined
    ld      b, a
    jr      nz, .haveHundreds
    ld      a, c
    and     $F0
    ld      d, 0            ; prepare empty fill value
    jr      z, .oneEmpty    ; no hundreds or tens, done this entry
.haveHundreds
    ld      a, c
    and     $F0
    swap    a
    add     a           ; account for spaced out digit tiles
    add     $80
    ld      d, a
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], d
    dec     l

    ; hundreds digit tile
    ld      a, b
    or      a
    ld      d, 0        ; prepare empty fill value
    jr      z, .oneEmpty
    add     a           ; account for spaced out digit tiles
    add     $80
    ld      d, a
.oneEmpty
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], d
    dec     l
    ; Note: If we ever drop from 3 to 1 digit there would be a lingering hundreds
    ;  digit, but no skill costs more than 91 so that's impossible.

    ; Update energy tilemap
    srl     e   ; divide energy by two, as we only have 48 pixels for the bar

    ld      a, e
    cp      49
    jr      c, .notOver48
    ld      a, 48   ; cap bar display at 48 pixels
.notOver48
    ld      e, a

    ld      a, [wEnergyDisplay]
    cp      e   ; compare to last bar update value
    jr      z, .doneTimerUpdates

    ld      hl, ENERGY_TILEMAP

    ; TODO: Reuse energy/health bar update code, maybe?
    ld      a, e
    ld      [wEnergyDisplay], a
    srl     a       ; number of filled tiles
    srl     a
    srl     a
    jr      z, .lowEnergy
    ld      d, a
.filledEnergyLoop
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, TILE_BAR_FULL
    ld      [hli], a        ; wait_vram?
    dec     d
    jr      nz, .filledEnergyLoop
.lowEnergy
    ld      a, e
    and     %00000111       ; get fractional portion
    jr      z, .noFractionalEnergyPortion
    add     TILE_BAR_EMPTY  ; offset to fractional tile ID
    ld      e, a
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, e
    ld      [hli], a        ; wait_vram?
.noFractionalEnergyPortion
.fillEmptyEnergyPortion
    ; fill to the end of the bar
    ld      a, l
    cp      LOW(ENERGY_TILEMAP) + 6
    jr      z, .maxEnergy

:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, TILE_BAR_EMPTY
    ld      [hli], a
    jr      .fillEmptyEnergyPortion
.maxEnergy
.noEnergyTick

.doneTimerUpdates


.updateRasterBars
    ; Update timer bar raster scroll values based on timers
    ld      hl, wShockTimer
    ld      de, wRasterLookup.barShock + 1
    ld      c, NUM_TIMERS - 1 ; don't include the speed timer
.barLoop
    ld      a, [hli]
    or      a
    jr      z, .barInactive

    ; In order to have smooth-scrolling bars for various timer lengths, we
    ;  use a shifted combination of the frame counter and timer, with different
    ;  shift values for each skill, and a per-skill lookup table of SCX values
    ;  to use to get the bar length we want.

    ; The focus cooldown is the only bar longer than 48 seconds, and so also
    ;  needs special handling because we only use the timer value (not the frame),
    ;  and we shift it right instead of left.

    ; Actual math: -([timerValue-1]+frameCounter/60 - maxValue) / maxValue * 48

    push    bc          ; protect loop counter
    ld      b, a        ; store frame value

    ld      a, c        ; special handling for focus cooldown
    dec     a
    jr      nz, .notFocusCooldownTimer
    ; Special handling for focus cooldown, which is the only timer which doesn't
    ;  shift the timer value at all, and just uses it directly.
    inc     l           ; skip shift nibbles
    inc     l           ; skip unused timer high byte
    ld      a, [hli]    ; get timer value
    dec     a           ; remove initial whole second
    jr      .offsetReady
.focusBuffTimer
.notFocusCooldownTimer
    ld      a, [hli]    ; get shift nibbles
    ld      c, a        ; cache shift values
    and     $F0         ; mask off timer shift value
    swap    a
.frameShift
    sra     b           ; shift frame value right
    dec     a
    jr      nz, .frameShift
    inc     l           ; skip unused timer high byte
    ld      a, c
    and     $0F         ; mask off frame shift value
    ld      c, a
    ld      a, [hli]    ; get timer value
    dec     a           ; remove initial whole second
.timerShift
    add     a           ; shift timer value left
    dec     c
    jr      nz, .timerShift
    or      b           ; combine shifted timer and frame values to obtain the table offset
.offsetReady
    pop     bc          ; recover loop counter

    ; Cap timerbar index, which is used to avoid excessive redundant entries
    ;  for refresh-extended electrify timer bars.
    cp      MAX_TIMERBAR_INDEX
    jr      c, .notOverIndex
    ld      a, MAX_TIMERBAR_INDEX
.notOverIndex
    ld      b, a        ; store timer+frame shifted offset

    ld      a, c        ; get loop counter
    dec     a           ; Final pass will be c=1, but we want zero offset there
    jr      nz, .notFocusCooldownBar
    dec     e           ; If we're updating the focus cooldown bar, adjust the
    dec     e           ; wRasterLookup address to set the SCX for the shared
    dec     e           ; focus timer bar.
    dec     e
.notFocusCooldownBar
    add     a           ; *2 to get index offset

    push    hl
    ld      hl, TimerBarScaleFactors
    add     l           ; Add offset (no need to worry about carry due to alignment)
    ld      l, a
    ld      a, [hli]    ; load address of skill's timer bar scale factors
    ld      h, [hl]
    ld      l, a

    ld      a, b
    add     l           ; add shifted offset value to locate SCX value
    ld      l, a
    adc     h
    sub     l
    ld      h, a

    ld      a, [hl]     ; get SCX value, finally!
    pop     hl
    
.barInactive
    ld      [de], a
    inc     e       ; advance to next raster entry
    inc     e
    inc     e
    inc     e
    
    ld      a, l    ; advance to next timer
    or      TIMER_SIZE-1
    ld      l, a
    inc     l

    dec     c
    jr      nz, .barLoop


.updateObstacles
    ; Update obstacle
    ld      hl, wObstacleCooldownTimer
    dec     [hl]
    jp      nz, .obstacleSpawnOnCooldown
    ; Cooldown complete, set cooldown to intermediate value so spawns are only
    ;  attempted once in a while, or they'll occur too often
    ld      a, OBSTACLE_SPAWN_COOLDOWN
    ld      [hl], a
    
    ; Attempt spawn
    call    rand

    ld      hl, wObstacleSpawnLookup
.nextObstacleEntry
    ld      a, [hli]
    cp      b
    jr      nc, .foundObstacleEntry
    inc     hl      ; skip obstacle ID
    jr      .nextObstacleEntry
.foundObstacleEntry
    ld      a, [hl]
    or      a
    ASSERT(OBSTACLE_NONE == 0)
    jr      z, .noObstacleSpawn

    ; Spawn obstacle!
    dec     a   ; 1 is the 0th obstacle tile, so offset for that
    ld      c, a    ; cache ID-1 for path offset
    add     a   ; ID*4
    add     a
    add     LOW(vObstacleTiles / 16)
    ld      b, a

    ; Find empty obstacle entry
    ld      hl, wObstacles
.seekLoop
    ld      a, [hl]
    or      a
    jr      z, .emptyEntryFound
    ld      a, l    ; advance to next entry
    or      OBSTACLE_SIZE - 1
    ld      l, a
    inc     l
    jr      .seekLoop
.emptyEntryFound

    ld      a, c        ; recover path offset
    add     HIGH(wObstacleAnimationPath0)   ; each path is 0x100 bytes apart, starting at Path0
    ld      [hli], a    ; high byte of animation path doubles as indicating entry is in use
    xor     a
    ld      [hli], a    ; animation paths are all zero-aligned

    ; Note: Although we offset initial obstacle Y coords, their paths
    ;  are tuned so that when they reach the player they end up in roughly
    ;  the same location.
    ld      a, OBSTACLE_INITIAL_Y_COORD - OBSTACLE_OFFSET_Y_COORD
    ld      d, OBSTACLE_OFFSET_Y_COORD
    inc     c           ; restore full index (one offset pass minimum)
.obstacleYOffsetLoop
    add     d           ; offset obstacle based on path index
    dec     c
    jr      nz, .obstacleYOffsetLoop
    
    ld      [hli], a    ; yCoord
    ld      a, OBSTACLE_INITIAL_X_COORD
    ld      [hli], a    ; xCoord
    ld      a, b
    ld      [hli], a    ; tile ID

    ld      hl, wObstacleCooldownMax
    ld      a, [hli]
    ld      [hl], a    ; reset cooldown

.obstacleSpawnOnCooldown
.noObstacleSpawn


.updatePearls

    ld      a, [wBGScrollPearlCounter]
    cp      8
    ret     c   ; Return if we haven't yet scrolled 8 pixels
    sub     8
    ld      [wBGScrollPearlCounter], a  ; store counter minus 8

    ; Process a pending secondary/primary background handoff
    ld      hl, wBGHandoffTimer
    ld      a, [hl]
    or      a
    jr      z, .noHandoffPending
    dec     a
    ld      [hl], a
    jr      nz, .noHandoffYet
    ; Set secondary background tilemap (where pearls are cleared) to
    ;  match the primary background tilemap, which has now caught up to it.
    ld      de, wBGTilemapPrimary
    ld      hl, wBGTilemapSecondary
    ld      c, 2
    rst     MemcpySmall
.noHandoffPending
.noHandoffYet

    ld      hl, wPearlSequenceAddr
    ld      a, [hl]
    or      a
    jr      nz, .havePearlSequence

    ; Randomly select a pearl sequence, potentially choosing none to leave a gap.
    push    hl
    call    rand
    pop     hl

    cp      NEW_PEARL_SEQUENCE_LIKELYHOOD
    ld      a, 0    ; prepare noPearlSequence `a` value without touching flags
    jr      nc, .noPearlSequence

    ; Generate another random number for the sequence to use
    ; (avoid any chance the 'do we add one?' number affects what is shown)
    push    hl
    call    rand
    pop     hl

    ;ld      a, b        ; random value was also in `b`
    ld      d, HIGH(PearlSequenceIndex)
    and     PEARL_SEQUENCE_COUNT-1
    add     a
    ld      e, a
    inc     l           ; advance to wLastPearlSequence
    inc     l
    ld      a, [hl]     ; get wLastPearlSequence
    cp      e
    ld      a, 0    ; prepare noPearlSequence `a` value without touching flags
    jr      z, .noPearlSequence ; if we've settled on the same sequence as last, don't add it
    ld      a, e
    ld      [hld], a    ; store new sequence as the new wLastPearlSequence
    dec     l           ; retreat to wPearlSequenceAddr

    ld      a, [de]     ; get address of pearl sequence
    ld      [hli], a
    inc     e
    ld      a, [de]
    ld      [hld], a

.havePearlSequence
    ; Check again for fall-through case in case we failed to add a new
    ;  sequence, since we need to load the address anyways.
    ld      a, [hli]
    or      a
    jr      z, .noPearlSequence
    ld      d, [hl]
    ld      e, a

    ; TODO: Clean up all these jumps somehow
    ld      a, [de]     ; get next pearl sequence byte
    inc     de
    bit     7, a        ; check if the pearl sequence is terminated
    jr      z, .sequenceNotTerminated
    xor     a
    dec     l           ; back up to high byte
    ld      [hl], a     ; set pearl sequence as inactive
    jr      .noPearlSequence
.sequenceNotTerminated
    ld      [hl], d     ; store new pearl sequence address
    dec     l
    ld      [hl], e

.noPearlSequence
    ; Copy value to wPearlBuffer (may be zero!)
    ld      c, a

    ; Point `de` to the current primary BG tilemap start address
    ;  (done a little early because we can trash HLA here)
    ld      hl, wBGTilemapPrimary
    ld      a, [hli]
    ld      d, [hl]
    ld      e, a

    ld      hl, wPearlBufferIndex
    ld      l, [hl]
    ld      [hl], c     ; store new pearl buffer value

    ; Now copy the next column of 6 tiles based on the pearl buffer
    ld      a, l        ; leave `l` pointing to the old value for use below
    inc     a
    cp      PEARL_BUFFER_SIZE
    jr      nz, .noPearlBufferOverflow
    ; Pearl buffer overflowed, set pointer to start of buffer
    xor     a
.noPearlBufferOverflow
    ld      [wPearlBufferIndex], a    ; Store new wPearlBuffer pointer

; Note: This is called by UpdatePhysics to update pearl columns
; Inputs: l=low byte of wPearlBuffer to update
;         c=pearl bits
;         de=starting address of source background tilemap
; Destroys: bc, de, hl, a, flags
.writePearlColumn
    ; Point `hl` to the VRAM tilemap location of interest
    ld      h, HIGH(BG_TILEMAP)
    ld      a, LOW(BG_TILEMAP)
    add     l
    ld      b, l    ; retain offset for use with `de` below
    ld      l, a

    ; Advance `de` to the background tilemap point for 'empty' tiles
    ; TODO: It feels like this can be smaller, look into it
    ld      a, b
    add     e
    ld      e, a
    adc     d
    sub     e
    ld      d, a

    ld      b, 6
.pearlLoop
    ; Shift a bit out of `c`
    srl     c
    push    bc
    ld      a, LOW(vPearlTile / 16) ; prepare the pearl tile ID
    jr      c, .addPearl
    ld      a, [de]                 ; override pearl tile ID with BG tile ID
.addPearl
    ld      b, a        ; cache tile ID for STAT check
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b     ; write tile ID to VRAM

    ; Offset HL and DE, both down one row exactly. Maybe there's a trick here...
    ld      a, $20
    add     l
    ld      l, a
    adc     h
    sub     l
    ld      h, a

    ld      a, $20
    add     e
    ld      e, a
    adc     d
    sub     e
    ld      d, a

    pop     bc
    dec     b
    jr      nz, .pearlLoop

    ret

; Update the cursor sprites based on the template for the selected button pair
UpdateCursor:
    ld      hl, wShadowOAM + OAM_B_BUTTON * sizeof_OAM_ATTRS

    ldh     a, [hButtonPair]    ; pair * 8
    add     a

    ld      de, CursorTemplates ; add to de (aligned so we can ignore carry)
    add     e
    ld      e, a

    ld      c, 8
    jp      MemcpySmall

UpdatePlayerSprite:
    ; Determine which tiles to use for the player sprites
    ; (also decrement the invul timer here)
    ld      hl, wInvulnerableTimer
    ld      a, [hl]
    or      a
    jr      z, .notInvulnerable
    dec     a
    ld      [hl], a
    ; Show blank tile sprite on odd frames when invulnerable
    and     %00000001
    ld      d, TILE_FLICKER_BLANK
    jr      nz, .framePrepared
.notInvulnerable

    ld      a, [wJumpCounter]
    or      a
    jr      z, .onGround
    ld      a, [wPlayerYVelocity]
    cp      $80
    ld      a, 8
    jr      c, .movingUpwards
    ; falling
    add     4
.movingUpwards
    ld      d, a
    jr      .framePrepared
.onGround
    ; Toggle the player ground animation frame every 16 physics ticks
    ld      a, [wScrollCounter]
    swap    a
    and     %00000001
    add     a
    add     a
    ld      d, a
.framePrepared

    ; The lobster uses a static OAM entry
    ; (so if nothing happened with physics we don't need to update it!)
    ld      hl, wShadowOAM + OAM_LOBSTER * sizeof_OAM_ATTRS
    ldh     a, [hPlayerYCoord]
    add     $10
    ld      b, a
    ld      [hli], a
    ld      a, LOBSTER_X_COORD
    ld      [hli], a
    ld      a, d
    ld      [hli], a
    add     2
    ld      d, a
    ld      [hli], a

    ld      a, b
    ld      [hli], a
    ld      a, LOBSTER_X_COORD + 8
    ld      [hli], a
    ld      a, d
    ld      [hli], a
    xor     a
    ld      [hl], a

    ret

; Update everything that depends on the physics update rate
; - Background scrolling (pearls)
; - Player position
; - Obstacle animation
; - Pearl spawning/collection
; - Enemy animation (purely visual, no collision impact)
UpdatePhysics:
    ld      hl, wPhysicsUpdateDelta
    ld      a, [hli]    ; get physics delta
    add     [hl]        ; add to physics update counter
    ld      c, a        ; cache 4.4 counter value
    and     $0F         ; only re-store low nibble
    ld      [hli], a
    ld      a, c
    and     $F0
    swap    a
    ld      c, a        ; number of physics updates to perform this frame

    ; Even if there are zero phyics ticks, we also generate obstacle
    ;  OAM entries here, which share dynamic OAM with damage numbers
    ;  so we have to do that regardless.
    jr      z, .updateObstacles

    ld      d, 0        ; initialize delta to apply to BG scroll
    ld      b, a        ; copy of update count to consume updating scrolling
.scrollTick
    inc     [hl]        ; increment scroll counter
    ld      a, [hl]     ; get wScrollCounter
    and     %00000011   ; We only care about the lower 2 bits
    cp      %00000011   ; If it's been 4 ticks we should scroll the ground
    jr      nz, .noGroundScroll
    ld      a, [wRasterLookup.groundStart+1]
    inc     a
    ld      [wRasterLookup.groundStart+1], a
.noGroundScroll
    bit     0, a        ; If it's been 2 ticks we should scroll the background
    jr      z, .noBGScroll
    inc     d
.noBGScroll
    dec     b
    jr      nz, .scrollTick

    ; Add calculated BG scroll delta
    ldh     a, [hBGScroll]  ; Increment value used for raster table
    add     d
    ldh     [hBGScroll], a

    inc     l           ; advance to wBGScrollPearlCounter
    ld      a, d
    add     [hl]        ; add to BG scroll pearl counter
    ld      [hli], a    ; store updated pearl counter value

    ld      b, c        ; copy of update counter to consume updating player
.playerTick
    ; Update lobster physics
    ld      hl, wPlayerYAccel
    ld      a, [hli]
    add     [hl]        ; add acceleration to velocity
    ld      [hli], a    ; store new velocity

    sra     a           ; divide velocity by 4
    sra     a

    ; Thanks to rondnelson99 for this snippet!
    ld      e, a             ; change velocity to 4.4 fixed point in de
    swap    e
    rla
    sbc     a
    xor     e
    and     $F0
    xor     e
    ld      d, a
    ld      a, e
    and     $F0
    ld      e, a

    push    hl
    ld      a, [hli]    ; get 16bit position
    ld      h, [hl]
    ld      l, a
    add     hl, de      ; add 4.4 velocity to 8.8 fixed point position
    ld      d, h        ; move result so we can use hl again
    ld      a, l
    pop     hl
    ld      [hli], a    ; store new position
    ld      a, d
    ld      [hl], a

    ; Check if we hit the ground
    cp      $80
    jr      c, .inTheAir
    ; Hit the ground, zero position/velocity
    xor     a
    ld      [hld], a
    ld      [hld], a
    ld      [hld], a
    ld      [wJumpCounter], a   ; zero jump counter so we can jump again
.inTheAir
    ; Convert new fixed point position to Y coordinate in screen space
    cpl
    add     LOBSTER_Y_OFFSET
    ldh     [hPlayerYCoord], a

    dec     b
    jr      nz, .playerTick


.updateObstacles

    ; It's faster (and smaller) to load and push/pop this than use HRAM
    push    bc      ; physics tick to for use by pearl collision (in `c`)
    
    ; Update obstacle locations and generate OAM entries
.obstacleTick
    ; Reset dynamic OAM start entry (first used here, and then in UpdateDynamicOAM)
    ; Note: This is reset every obstacleTick so even though we may generate OAM
    ;  entries multiple times (for c>1), we won't end up with multiple OAM entries
    ;  for each obstacle.
    ; TODO: Change this to only generate OAM entries once!
    ld      a, OAM_DYNAMIC * sizeof_OAM_ATTRS
    ld      [wOAMIndex], a

    ; When this starts `c` contains the number of physics ticks to process
    ld      hl, wObstacles
    ld      b, MAX_OBSTACLES
.obstacleLoop
    push    bc

    ld      a, [hli]    ; get path high byte (to see if the obstacle is active)
    or      a
    jp      z, .advanceToNextEntry
    ld      d, a

    ld      a, c        ; check if the path location should be updated
    or      a
    lb      bc, 0, 0    ; preload dy=0, dx=0 for noPathUpdate
    jr      z, .noPathUpdate

    ld      a, [hl]     ; get path low byte
    and     OBSTACLE_PATH_WRAP  ; wrap the low byte, if needed
    ld      e, a
    ld      a, [de]     ; get dY
    inc     de
    ld      b, a
    ld      a, [de]     ; get dX
    inc     de
    ld      c, a
    ld      a, e
    ld      [hl], a     ; store updated low byte

.noPathUpdate
    inc     l
    ld      a, [hl]     ; get yCoord
    add     b           ; add dY
    ld      [hli], a    ; store new yCoord
    add     $10         ; add OAM y offset
    ld      b, a        ; cache yCoord in `b`

    ld      a, [hl]     ; get xCoord
    add     c           ; add dX
    cp      OBSTACLE_INITIAL_X_COORD + OBSTACLE_INITIAL_X_RANGE
    jr      c, .obstacleStillVisible
    ; Destroy obstacle once it's off the left edge of the screen
    dec     l           ; move back to path high byte
    dec     l
    dec     l

    xor     a
    ld      [hl], a     ; clear high byte to disable entry

    jr      .advanceToNextEntry

.obstacleStillVisible
    ld      [hli], a    ; store new xCoord
    add     8 - WORK_X_OFFSET ; add OAM x offset minus work space offset
    ld      c, a        ; cache xCoord in `c`

    ld      a, [hld]    ; get tile ID

    push    hl

    ld      hl, wOAMIndex   ; point to next free OAM entry
    ld      l, [hl]

    ld      [hl], b     ; first sprite
    inc     l
    ld      [hl], c
    inc     l
    ld      [hli], a
    add     2
    ld      d, a
    ;ld      a, OAMF_PAL0
    xor     a
    ld      [hli], a

    ld      [hl], b     ; second sprite
    inc     l
    ld      a, c
    add     8
    ld      [hli], a
    ld      [hl], d
    inc     l
    ;ld      a, OAMF_PAL0
    xor     a
    ld      [hli], a

    ld      a, l            ; Store next free OAM entry index from this frame
    ld      [wOAMIndex], a

    pop     hl

    ld      a, [wInvulnerableTimer]
    or      a
    jr      nz, .playerInvulnerable

    ; Perform collision for obstacles near the player
    ld      a, [hld]    ; get xCoord
    cp      OBSTACLE_X_HIGH_COLLIDE     ; check forward edge of player
    jr      nc, .notNearPlayer
    cp      OBSTACLE_X_LOW_COLLIDE      ; check back edge of player
    jr      c, .notNearPlayer
    ld      a, [hl]     ; get yCoord (not including +16 yOffset for screen space)
    ld      b, a
    ld      a, [wPlayerYVelocity]
    cp      $80
    ld      c, OBSTACLE_Y_COLLIDE_UP_OFF ; prepare for upwards collision
    jr      c, .movingUpwards
    ASSERT(OBSTACLE_Y_COLLIDE_UP_OFF + 1 == OBSTACLE_Y_COLLIDE_OFFSET)
    ;ld      c, OBSTACLE_Y_COLLIDE_OFFSET ; switch to downward collision
    inc     c
.movingUpwards
    ldh     a, [hPlayerYCoord]  ; use sprite-based coords as wPlayerYPosition is inverted
    add     c   ; offset player coord to bottom edge
    ; Note: Bottom 2/3 pixels of player are 'safe' from collision
    cp      b
    jr      c, .notNearPlayer

    ; Player collided, game over!

IF !DISABLE_OBSTACLE_DEATH
    push    hl      ; protect obstacle pointer
        ; Check if either final item is present
        ld      hl, wFinalWordCount
        ld      a, [hli]
        ld      e, [hl]
        or      e
    pop     hl      ; recover obstacle pointer

    ; If neither item is present, end the game immediately
    jp      z, GameOverWithPops

    ; Otherwise, notify the player of impending failure
    ; Note: This exists to require a START press before final item use,
    ;  to avoid the user accidentally using an item by hitting A/B.
    push    hl      ; protect obstacle pointer
        ld      hl, FallenText
        ld      a, LOW(vFallenTilemap)
        call    SetupTextBox.overrideTilemap

        ld      a, WAIT_FALLEN
        ldh     [hMessageBoxActive], a
    pop     hl      ; recover obstacle pointer

    ; Continue processing this frame (including other calls in the main
    ;  loop), to give everything a chance to run, but mainly so the
    ;  wOAMIndex reflects the index after all obstacles, so their OAM
    ;  entries aren't cleared by UpdateDynamicOAM.
ENDC

.playerInvulnerable
.notNearPlayer
.advanceToNextEntry
    ld      a, l    ; advance to next entry
    or      OBSTACLE_SIZE - 1
    ld      l, a
    inc     l

    pop     bc
    dec     b
    jp      nz, .obstacleLoop

    ld      a, c
    or      a
    jr      z, .singleOAMPassComplete   ; no physics tick, we only needed a single obstacle pass for dynamic OAM
    dec     c
    jp      nz, .obstacleTick


.singleOAMPassComplete

    pop     bc      ; recover pushed physics tick value (in `c`)

    ; Process pearl collision check if physics ticked or if we've scrolled 
    ;  enough to have reached a new row of pearls. If we don't check on 
    ;  physics ticks we can miss rows of pearls at times.

    ; TODO: This seems to result in checking pearls too early!
    ;  -> Do we adjust the `d` offset, or the d AND b offsets, or something else?
    ;ld      a, c
    ;or      a
    ;jr      nz, .updatePearlCollisions

    ; We check for collisions every 8 pixels because the 8 pixel scroll 
    ;  update can also bring us into range of pearls.
    ld      a, [wBGScrollPearlCounter]
    cp      8
    ret     c   ; Return if we haven't yet scrolled 8 pixels
    ; This is left un-modified so it can be re-checked in UpdateTimers
    ;  when determining if we should generate a new column of pearls.
    ;sub     8
    ;ld      [wBGScrollPearlCounter], a  ; store counter minus 8

.updatePearlCollisions
    ld      hl, wPearlBufferIndex
    ld      a, [hl]     ; get pearl insertion index

    ; Offset to the columns near the player (and then 1 at a time after that)
    ld      d, PEARL_INDEX_COLLISION_OFFSET
    lb      bc, 3, 0    ; check 3 columns of pearls, `c` is the pearls collected counter
.pearlColumnLoop
    sub     d
    jr      nc, .noBufferOverflow
    ; We wrapped around the beginning of the buffer, so compensate for that
    sub     256-32
.noBufferOverflow
    ld      l, a

    ld      a, [hl] ; get current pearl bits
    or      a       ; check if there are any pearls to collide with
    jp      z, .nextPearlColumn
    ld      e, a

    ; Check all 6 pearl slots in the column vs the player

    ; Note: This uses a somewhat unusual `push/pop af` sequence to persist
    ;  the carry flag through loop counter decrement to store the pearl 
    ;  state as we rotate through `e`. This also allows us to easily offset
    ;  `d` 8 pixels per loop without affecting the carry flag we care about.

    ld      d, 12       ; Upper Y coordinate of first (top) pearl
    ld      h, 6        ; check 6 pearls (we use `h` instead of `b` because if we `push bc` to protect `b` we can't use `c` to count pearls)
    push    af          ; required to make the skewed pop/push in the loop balanced
.pearlLoop
    pop     af          ; pop off protected pearl state in carry flag
    rr      e           ; Check if there's a pearl in this slot
    jr      nc, .noPearls

    ldh     a, [hPlayerYCoord]
    add     $10         ; offset to lower edge of player
    cp      d
    jr      c, .playerAbovePearl

    ld      a, d
    add     7           ; offset to lower edge of pearl
    ld      d, a
    ldh     a, [hPlayerYCoord]

    cp      d
    jr      nc, .playerBelowPearl
    inc     c           ; increment pearl collected counter
.playerBelowPearl
    ; If the player is below the pearl, the carry flag will be reset,
    ;  then we will `ccf` which will set the flag, and then the pearl
    ;  will be set when `rr e` rotates the carry flag back in.
    ; Otherwise the carry flag will be set, and `ccf` will clear it
    ;  and the empty value will be rotated into the pearl bits.
    ccf
.playerAbovePearl
.noPearls
    push    af          ; protect carry flag for pearl state
    ; Because of our goofy background alignment with 4 empty rows of pixels
    ;  at the top of the battlefield the pearls are every 8 pixels, but starting
    ;  at line 12. We also (when a pearl is present) can be at 0 or +7 into the
    ;  'struct' at this point, which means we need to subtract the 4 offset,
    ;  align the values, then re-add the offset.

    ld      a, d        ; advance to top Y coord of next pearl
    sub     4
    or      8-1
    add     5
    ld      d, a

    dec     h
    jr      nz, .pearlLoop

    pop     af          ; recover the final pearl bit
    rr      e           ; insert the final bit value in
    srl     e           ; re-align pearl bits to LSB
    srl     e
    ld      h, HIGH(wPearlBuffer)   ; Restore high byte of pointer
    ld      [hl], e     ; store updated pearl bits

    ; Refresh pearl display for this column
    push    bc      ; protect column and pearl collection counters
    push    hl      ; protect wPearlBuffer address
    ld      c, e    ; this call expects the pearl bits in `c`

    ; Point `de` to the BG tilemap start address
    ;  (without clobbering L, which writePearlColumn needs)

    ; Determine if we should use the primary or secondary tilemap
    ;  based on the relative values of `b` and wBGHandoffTimer.
    ld      a, [wBGHandoffTimer]
    sub     b   ; difference between handoff timer and column loop counter
    jr      nc, .useSecondaryTilemap
    ; The handoff has occured (both tilemaps are the same so either is valid),
    ;  or we're updating a column now covered by the primary tilemap.
    ld      a, [wBGTilemapPrimary]
    ld      e, a
    ld      a, [wBGTilemapPrimary+1]
    jr      .updatePearlColumn
.useSecondaryTilemap
    ; We're clearing pearls drawn over the old tilemap, so use the secondary
    ;  tilemap to 'clear' them.
    ld      a, [wBGTilemapSecondary]
    ld      e, a
    ld      a, [wBGTilemapSecondary+1]
.updatePearlColumn
    ld      d, a
    call    UpdateTimers.writePearlColumn
    pop     hl
    pop     bc

.nextPearlColumn
    ld      a, l
    ld      d, 1    ; Prepare to move one column left
    dec     b
    jp      nz, .pearlColumnLoop

    ld      a, c
    ld      [wPendingPearls], a
    or      a
    ret     z       ; no pearls collected
    ld      a, FX_PEARL
    call    audio_play_fx
    ret


; Update dynamically generated OAM entries for damage text and attack effects
UpdateDynamicOAM:
    ld      hl, wDamageText ; use `hl` for this pointer for some non-`a` loads
    ld      de, wOAMIndex   ; Point to next free OAM entry
    ld      a, [de]
    ld      e, a

    ld      b, MAX_DAMAGE_TEXT
.loop
    ld      a, [hl]
    or      a
    jr      nz, .processEntry
    ld      a, l    ; advance to next entry
    or      DAMAGE_TEXT_SIZE-1
    ld      l, a
    inc     l       ; will never overflow `h`

    ; TODO: Find a way to push/pop bc and structure this loop to avoid
    ;  this goofy double-jump
    dec     b
    jr      nz, .loop
    jr      .damageTextComplete

.processEntry
    dec     a       ; decrement frame counter
    ld      [hli], a

    push    bc
    ld      c, [hl]     ; get animation table low byte
    ld      b, HIGH(DAMAGE_TEXT_ANIMATIONS)
    ld      a, [bc]     ; get Y offset for this animation frame
    cp      ANIMATION_PATH_TERMINATOR
    jr      nz, .pathNotTerimated
    dec     c           ; path terminated, back up two bytes and re-read the Y offset
    dec     c
    ld      a, [bc]
.pathNotTerimated
    ld      h, a        ; cache Y offset in a register we can easily repair
    inc     c
    ld      a, [bc]     ; get X offset for this animation frame
    ld      b, h        ; done with `b` for a pointer, store Y offset there
    inc     c
    ld      h, HIGH(wDamageText)    ; repair damage text pointer
    ld      [hl], c     ; store new animation table low byte
    inc     l
    ld      c, a        ; store X offset

    ; ones digit
    ld      a, [hli]    ; get Y coord
    add     b           ; add Y offset
    ld      b, a        ; store offset Y coord
    ld      [de], a
    inc     e
    ld      a, [hli]    ; get X coord
    add     c           ; add X offset
    ld      c, a        ; store offset X coord
    ld      [de], a
    inc     e

    ld      a, [hli]    ; get ones digit tile
    ld      [de], a
    inc     e
    ld      a, OAMF_PAL1
    ld      [de], a
    inc     e

    ; tens digit
    ld      a, [hl]     ; get tens digit tile
    cp      $FF         ; check if empty
    jr      z, .entryDone

    ld      a, b        ; recover offset Y coord
    ld      [de], a
    inc     e
    ld      a, c        ; recover offset X coord
    sub     8
    ld      c, a        ; store offset X coord
    ld      [de], a
    inc     e
    ld      a, [hli]
    ld      [de], a
    inc     e
    ld      a, OAMF_PAL1
    ld      [de], a
    inc     e

    ; hundreds digit
    ld      a, [hl]     ; get hundreds digit tile
    cp      $FF         ; check if empty
    jr      z, .entryDone

    ld      a, b        ; recover offset Y coord
    ld      [de], a
    inc     e
    ld      a, c        ; recover offset X coord
    sub     8
    ld      c, a        ; store offset X coord
    ld      [de], a
    inc     e
    ld      a, [hli]
    ld      [de], a
    inc     e
    ld      a, OAMF_PAL1
    ld      [de], a
    inc     e

.entryDone
    pop     bc

    ld      a, l    ; advance to next entry
    or      DAMAGE_TEXT_SIZE-1
    ld      l, a
    inc     l

    dec     b
    jr      nz, .loop

.damageTextComplete
    ld      a, [wOAMEndIndex]  ; End of OAM used in the last frame
    ld      b, a
    
    ; Clear trailing old OAM entries
.clearLoop
    xor     a
    ld      [de], a
    inc     e
    inc     e
    inc     e
    inc     e

    ld      a, e
    cp      b
    jr      c, .clearLoop

    ld      a, e
    ld      [wOAMEndIndex], a   ; Store last OAM entry used this frame

    ;ld      hl, wOAMIndex   ; Point to next free OAM entry
    ;ld      l, [hl]

    ret

; Add pending damage/pearls to the scores and update the display
UpdateScore:
    ld      hl, wPendingDamage
    ld      a, [hli]
    ld      c, a
    ld      a, [hl]

    ld      b, a
    or      c
    jr      z, .noDamageUpdate

    xor     a       ; clear pending damage
    ld      [hld], a
    ld      [hl], a

    ld      hl, wBattleDamage
    call    AddBCHiScore

    ASSERT(HIGH(wBattleDamage) == HIGH(wBattleDamage + HISCORE_LENGTH))
    inc     l  ; skip un-shown largest 2 digits
    inc     l
    ld      d, h
    ld      e, l
    ld      hl, SCORE_TILEMAP
    ld      c, HISCORE_LENGTH - 2
    jp      PrintScore

.noDamageUpdate
    ld      a, [wPendingPearls]
    or      a
    ret     z       ; no pearl score update

    ld      c, a
    ld      b, 0

    ld      hl, wBattlePearls
    call    AddBCHiScore

    ;ld     a, 0    ; left over from AddBCHiScore loop counter checking
    ld      [wPendingPearls], a

    ld      d, h
    ld      e, LOW(wBattlePearls) + 4

    ld      hl, PEARLS_TILEMAP
    ld      c, HISCORE_LENGTH - 4
    ; fall through to write the tilemap

; Print the provided HiScore to the target tilemap address
; Note: This is located here so the pearl update can fall through into it.
; Note: This uses DE->HL ordering to match Memcpy registers.
; @param DE HiScore to print
; @param HL Tilemap address at which to print it
PrintScore::
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-

    ld      a, [de]
    add     a
    jr      c, .noDigit
    add     $80
.noDigit
    ; If there was a carry we had $80, and now have $0, so just write that as a blank
    ld      [hli], a
    inc     e
    dec     c
    jr      nz, PrintScore
    ret

UpdateEnemyHealth:
    ; Ensure we're past LY==7 to avoid tearing when updating the enemy health,
    ;  which is only really possible when using the FinalWord item given where
    ;  UpdateEnemyHealth is called in the mainloop.
.lyWait
    ldh     a, [rLY]
    cp      8
    jr      c, .lyWait

    ; Update enemy health bar, if required
    ; Instead of updating in response to damage, we just update once every frame if needed
    ; -> TODO: We could potentially lump this with energy ticks, if it's often enough
    ld      a, [wEnemyHealth]
    ld      c, a
    ld      a, [wEnemyHealth+1]
    ld      b, a
    ld      a, [wEnemyHealthShift]
    or      a
    jr      z, .noShift
    cp      $0F
    jr      nc, .leftShift
.rightShiftLoop
    srl     b
    rr      c
    dec     a
    jr      nz, .rightShiftLoop
    jr      .noShift
.leftShift
    swap    a
.leftShiftLoop
    sla     c
    rl      b
    dec     a
    jr      nz, .leftShiftLoop
.noShift
    ld      a, [wEnemyHealthDisplay]
    cp      b
    ; Current shifted enemy health equals last value used, nothing to update
    ret     z

    ld      hl, ENEMY_HP_TILEMAP
    ld      b, $FF  ; setup for +-1 smooth health bar updates
    jr      nc, .healthSmallerThanDisplay
    inc     b       ; switch B from -1 to +1
    inc     b
.healthSmallerThanDisplay
    add     b
    ld      b, a
    ld      [wEnemyHealthDisplay], a    ; Store value used to avoid extra updates
    srl     a       ; number of filled tiles
    srl     a
    srl     a
    jr      z, .lowHealth
    ld      d, a
.filledHealthLoop
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, TILE_BAR_FULL
    ld      [hli], a        ; wait_vram?
    dec     d
    jr      nz, .filledHealthLoop
.lowHealth
    ld      a, b
    and     %00000111       ; get fractional portion
    jr      z, .noFractionalHealthPortion
    add     TILE_BAR_EMPTY  ; offset to fractional tile ID
    ld      b, a
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, b
    ld      [hli], a        ; wait_vram?
.noFractionalHealthPortion
.fillEmptyHealthPortion
    ; fill to the end of the bar
    ld      a, l
    cp      LOW(ENEMY_HP_TILEMAP) + 8
    ret     z   ; max health

:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, TILE_BAR_EMPTY
    ld      [hli], a
    jr      .fillEmptyHealthPortion



; @param C  Enabled bitmask
; @param HL Tilemap base address for icon
UpdateLoadoutIconRow:
    ; `e` acts as the low byte of the icon index pointer when needed, and also
    ;  the loop counter, but we only check the lower 3 bits for the loop check.
.loop
    dec     e   ; decrement `e` here so the [de] pointer is correct
    xor     a   ; start with a base tile index
    srl     c   ; get enabled bit
    jr      nc, .notEnabled
    ; enabled, load tile ID from lookup table
    ;ld      d, HIGH(IconRowIndicies)
    ld      a, [de]
    dec     a   ; table values are offset by one for status screen which
                ;  also has a locked state to include, so account for that
.notEnabled
    add     LOW(vIconsTiny / 16) ; add base tile ID
    ld      b, a

:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-

    ld      a, b
    ld      [hli], a

    ld      a, e
    and     %111    ; check if lower 3 bits are zero
    jr      nz, .loop

    ret


GameOverWithPops:
    pop     bc      ; pop off obstacle loop counter
    pop     bc      ; pop off physics tick value

    ; Ensure the player sprite is shown where it collided with an obstacle
    call    UpdatePlayerSprite
GameOver:
    ; Restore the actual wSecondWindCount value, which will have changed
    ;  if the player used a Second Wind item.
    ld      hl, wSecondWindCache
    ld      a, [hld]
    dec     l   ; skip wGameSpeed
    ld      [hl], a

    ; Update overall damage HiScore for this game speed
    ld      de, wBattleDamage
    ld      a, [wGameSpeed]
    add     a   ; speed*8 (HISCORE_LENGTH == 8)
    add     a
    add     a
    ld      hl, wMaxDamageScore - HISCORE_LENGTH
    add     l
    ld      l, a
    call    CpHiScore
    jr      nc, .noNewHiScore
    ; New hiscore!
    ld      c, HISCORE_LENGTH   ; copy new hiscore
    rst     MemcpySmall
    ld      hl, song_new_hiscore
    push    hl  ; push song to play for later
    ld      hl, NewHiScoreText
    jr      .doneDamageScore
.noNewHiScore
    ld      hl, song_game_over
    push    hl  ; push song to play for later
    ld      hl, GameOverText
.doneDamageScore

    ld      a, LOW(vGameOverTilemap)
    call    SetupTextBox.overrideTilemap

    pop     hl  ; recover song to play
    call    hUGE_init

    ; Clear upper row lingering item tiles because the Game Over
    ;  text doesn't overlap it.
    ld      hl, vItemTilemap
    lb      bc, 0, 4
    call    LCDMemsetSmallFromB

    ; Show loadout (enabled skills/upgrades)
    ld      a, [wEnabledSkills]
    ld      c, a
    ld      hl, vSkillLoadoutTilemap
    ld      de, IconRowIndicies.skills + 8
    call    UpdateLoadoutIconRow

    ld      a, [wEnabledUpgrades]
    ld      c, a
    ld      hl, vUpgradeLoadoutTilemap
    ld      e, LOW(IconRowIndicies.upgrades) + 8
    call    UpdateLoadoutIconRow
    
    ld      a, [wItemsUsed]
    ld      c, a
    ld      hl, vItemsUsedTilemap
    ld      de, IconRowIndicies.items + 4
    call    UpdateLoadoutIconRow

    ; Show game speed (probably VRAM safe from above call, but check anyways
    ;  to ensure the game speed is reliably shown)
    ld      hl, vSpeedTilemap
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, LOW(vIconsTiny.speed / 16)
    ld      [hli], a
    ld      a, [wGameSpeed]
    add     a
    add     $80
    ld      [hli], a
    
    ; Add newly collected pearls to total
    ld      de, wBattlePearls
    ld      hl, wCurrentPearls
    call    AddHiScore

    ; If we overflowed to 6 digits, cap at 99999
    ld      l, LOW(wCurrentPearls) + HISCORE_LENGTH - MAX_PEARL_DIGITS - 1
    ld      a, [hl]
    cp      $80
    jr      z, .noPearlOverflow
    ld      l, LOW(wCurrentPearls)  ; ensure ALL larger digits are clear
    ld      a, $80
    ld      c, HISCORE_LENGTH - MAX_PEARL_DIGITS
    rst     MemsetSmall
    ld      a, 9
    ld      c, MAX_PEARL_DIGITS
    rst     MemsetSmall
.noPearlOverflow

    ; Save new hiscore and pearl counts to SRAM
    ; Note: Done here because I find there's a natural tendency to power
    ;  off the game at this stage and not return to the status screen, where
    ;  the save was previously updated.
    call    UpdateSavedGame

    ld      a, WAIT_GAME_OVER
    ldh     [hMessageBoxActive], a
    ret

ShowFinalItems:
    ; Ensure the fallen string and A tile on the panel are cleared
    ld      hl, vFallenTilemap
    lb      bc, 0, vAButtonTilemap - vFallenTilemap + 1
    call    LCDMemsetSmallFromB

    ld      hl, wFinalWordCount
    lb      bc, 4, LOW(vItemTiles.SecondWind / 16)
    ld      d, WAIT_FINAL_ITEMS
    jp      SetupItemPanel

InputProcessing:
    ldh     a, [hMessageBoxActive]
    or      a
    jp      z, .normalInput

    ; Item prompt input handling
    ldh     a, [hPressedKeys]
    and     PADF_START
    jr      nz, .hideMessageBoxBasedOnState

    ; Don't process A/B presses until a counter has elapsed when showing Fallen or Game Over
    ldh     a, [hMessageBoxActive]
    or      a
    jr      z, .normalInput
    cp      WAIT_FALLEN
    jr      nc, .hideMessageBoxBasedOnStateDelayed

    ; Override hAvailableSkills (reset every frame) with wAvailableItems,
    ;  to restrict which buttons will work.
    ld      hl, wAvailableItems
    ld      a, [hli]
    ldh     [hAvailableSkills], a
    ; Note that the timer is intentionally processed after the WAIT_FALLEN
    ;  bailout above because we don't want Fallen/Game Over to automatically exit.
    dec     [hl]    ; decrease wItemUseTimer
    jr      z, .hideMessageBoxTimed

    ldh     a, [hPressedKeys] ; A locks/unlocks cursor on tiles
    and     PADF_A
    jp      nz, .APressed

    ldh     a, [hPressedKeys]
    and     PADF_B
    jp      nz, .BPressed
    ret

.hideMessageBoxBasedOnStateDelayed
    ld      a, [wPanelCloseABCounter]
    or      a
    jr      z, .abCounterElapsed
    dec     a
    ld      [wPanelCloseABCounter], a
    ret     nz
    ; Show the 'A' tile so the player knows they can now use A to advance
    ld      hl, vAButtonTilemap
    lb      bc, LOW(vAButtonTile / 16), 1
    jp      LCDMemsetSmallFromB ; smaller than a one-byte direct load
.abCounterElapsed
    ldh     a, [hPressedKeys] ; A locks/unlocks cursor on tiles
    and     PADF_A
    jr      nz, .hideMessageBoxBasedOnState

    ldh     a, [hPressedKeys]
    and     PADF_B
    jr      nz, .hideMessageBoxBasedOnState
    ret

.hideMessageBoxTimed
    ; Skip hiding the prompt and ending the game until the 0th wDamageText
    ;  entry is done showing, which allows the FinalWord animation to complete
    ; Note: Since hMessageBoxActive is still >=2, updates will not run,
    ;  which means no background scrolling or movement, but if resume that
    ;  we'd need a different flag to know it was the final item set shown,
    ;  and we'd also have to make the player invulnerable (or something else),
    ;  to prevent chained game overs. So... leaving that as is right now.

    ; Also keep setting the wItemUseTimer to 1 to ensure we don't wait a
    ;  long time if the user uses an item quickly (this is pretty ugly).
    ld      a, 1
    ld      [wItemUseTimer], a

    ld      a, [wDamageText]
    or      a
    ret     nz
    ; Fall through to .hideMessageBoxBasedOnState

.hideMessageBoxBasedOnState
    ; Decide where to go based on which message box was shown
    ldh     a, [hMessageBoxActive]
    dec     a
    ASSERT(WAIT_INITIAL_ITEMS == 1)
    jr      z, .hideMessageBoxDirect
    dec     a
    ASSERT(WAIT_FINAL_ITEMS == 2)
    jp      z, GameOver
    dec     a
    ASSERT(WAIT_FALLEN == 3)
    jr      z, ShowFinalItems
    ASSERT(WAIT_GAME_OVER == 4)
    ; Fall-through to return to status

    ; Resume audio updates in VBlank (before we fade or it lags audio)
    ld      a, l
    ASSERT(LOW(wSecondWindCache) - 1 != 0)
    ldh     [hVBlankUpdateAudio], a

    call    FadeOut

    ld      a, MODE_BATTLE
    ldh     [hLastMode], a
    ASSERT(MODE_BATTLE + 1 == MODE_STATUS)
    inc     a
    ldh     [hGameMode], a

    pop     af      ; pop off return address to battle loop
    ret             ; return to mode handler

.hideMessageBoxDirect
    ; Allow the user to close the prompt if they want to get on with battle
    call    HideLowerMessageBox

    ; Reset pre-item pair/direction (matters if sticky DPad is disabled)
    ld      hl, wButtonPairCache
    ld      a, [hli]
    ldh     [hButtonPair], a
    ld      a, [hl]
    ldh     [hDirectionBit], a

    xor     a
    ldh     [hMessageBoxActive], a

    ret

.normalInput
    ; If using 'hold' input, snap direction to UP before checking dpad state
    ld      a, [wEnabledMisc]
    and     OPTIONF_STICKY_DPAD
    jr      z, .retainDirection
    xor     a
    ldh     [hButtonPair], a
    inc     a
    ldh     [hDirectionBit], a
.retainDirection

    ldh     a, [hPressedKeys]
    and     PADF_UP
    call    nz, .UpPressed
    ldh     a, [hHeldKeys]
    and     PADF_UP
    call    nz, .UpHeld

    ldh     a, [hPressedKeys]
    and     PADF_DOWN
    call    nz, .DownPressed
    ldh     a, [hHeldKeys]
    and     PADF_DOWN
    call    nz, .DownHeld

    ldh     a, [hPressedKeys]
    and     PADF_LEFT
    call    nz, .LeftPressed
    ldh     a, [hHeldKeys]
    and     PADF_LEFT
    call    nz, .LeftHeld

    ldh     a, [hPressedKeys]
    and     PADF_RIGHT
    call    nz, .RightPressed
    ldh     a, [hHeldKeys]
    and     PADF_RIGHT
    call    nz, .RightHeld
    
    ldh     a, [hPressedKeys] ; A locks/unlocks cursor on tiles
    and     PADF_A
    jp      nz, .APressed
    
    ldh     a, [hPressedKeys]
    and     PADF_B
    jp      nz, .BPressed
    
    ldh     a, [hPressedKeys]
    and     PADF_START
    jr      nz, .StartPressed

    ret

.StartPressed:
    ; Pause game until Start is pressed again
    ld      a, FX_PAUSE
    call    audio_play_fx

    ld      hl, PausedText
    call    SetupTextBox
.pauseLoop

    ; 6 bytes to keep up manual updates vs 3+3 to resume automatic VBlank
    ;  updates and resume them, so... just call them.
    call    audio_update
    call    _hUGE_dosound

    rst     WaitVBlank

    ldh     a, [hPressedKeys]
    and     PADF_START
    jr      z, .pauseLoop

    ld      a, FX_UNPAUSE
    call    audio_play_fx

    jp      HideLowerMessageBox

; Note: The hButtonPair values are 0-3, but since we only ever use their
;  values multiplied by 4 and 8, we just load them pre-multiplied by 4 here.
.UpPressed
.UpHeld
    xor     a
    ld      b, %00000001
    jr      .dnmv
.DownPressed
.DownHeld
    ld      a, 3 * 4
    ld      b, %01000000
    jr      .dnmv
.RightPressed
.RightHeld
    ld      a, 1 * 4
    ld      b, %00000100
    jr      .dnmv
.LeftPressed
.LeftHeld
    ld      a, 2 * 4
    ld      b, %00010000
.dnmv
    ldh     [hButtonPair], a
    ld      a, b
    ldh     [hDirectionBit], a
    ret

.BPressed
    ld      hl, SkillHandlers.odd
    ldh     a, [hDirectionBit]
    sla     a       ; B skills are interlaced one bit over
    ld      c, 0    ; CursorTemplate offset
    jr      .callSkillHandler
.APressed
    ld      hl, SkillHandlers.even
    ldh     a, [hDirectionBit]
    ld      c, 4    ; CursorTemplate offset
.callSkillHandler
    ld      b, a
    ldh     a, [hAvailableSkills]
    and     b   ; check if the button pressed is for an available skill
    ret     z   ; if not available, do nothing

    ldh     a, [hButtonPair]    ; pair * 8
    ld      b, a    ; cache for skill activation

    ; Don't create activation sprites for item use (as the player can spam
    ;  them for FinalWord to prevent game over, and they linger for initial
    ;  items which is annoying).
    ldh     a, [hMessageBoxActive]
    or      a
    jr      nz, .activateSkill

    ld      a, b    ; recover pair * 8
    add     a

    ; Create activation sprite
    ld      de, CursorTemplates ; add to de (aligned so we can ignore carry)
    add     e
    add     c   ; add offset based on button pressed
    ld      e, a

    ; Set horizontal button offset based on `c` (0=A pressed, !0=B pressed)
    ld      a, c
    or      a
    ld      a, 10
    jr      z, .bOffset
    sub     12      ; for A pressed the offset is 10 - 12 = -2 ($FE)
.bOffset
    ld      c, a

    push    hl

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
    ld      a, LOW(DAMAGE_TEXT_ANIMATIONS.skillActivation)
    ld      [hli], a

    ld      a, [de]
    add     4           ; add vertical offset for skill buttons
    ld      [hli], a    ; Y coord
    inc     e
    ld      a, [de]
    add     c           ; add horizontal offset for skill buttons
    ld      [hli], a    ; X coord

    ld      a, LOW(vSkillActivateTiles / 16) + 2
    ld      [hli], a
    sub     2
    ld      [hli], a
    ld      a, $FF
    ld      [hli], a

.outOfEntries
    pop     hl
    
.activateSkill
    ld      a, b    ; recover from above
    add     l
    ld      l, a
    adc     h
    sub     l
    ld      h, a

    ld      a, [hli]
    ld      h, [hl]
    ld      l, a
    rst     CallHL
    ret

  
; Setup the text box for pause/gameover
; Input: HL = Pointer to text to print
SetupTextBox:
    ld      a, LOW(vPausedTilemap)
.overrideTilemap
    push    af  ; cache tilemap low byte on stack
    lb      bc, LOW(vMessageTiles / 16), LOW(vMessageTiles.end / 16) - 1
    lb      de, 1, $80
    ld      a, TEXT_WIDTH_TILES * 8 + 1
    call    TextInit

    ld      a, TEXT_NEW_STR
    call    PrintVWFText
    ;ld      hl, vPausedTilemap
    ld      h, HIGH(vLoadoutTilemap)
    pop     af  ; recover tilemap low byte
    ld      l, a
    call    SetPenPosition

    call    PrintVWFChar
    call    DrawVWFChars

    ; Clear any lingering item tilemap tiles
    ld      hl, vItemTilemap + $20
    lb      bc, 0, 4
    call    LCDMemsetSmallFromB

    ; Setup counter until A/B can close panel
    ; This is done so the player spamming skills doesn't accidentally use
    ;  an item or skip the game over panel.
    ld      a, AB_CLOSE_FRAMES
    ld      [wPanelCloseABCounter], a

    jp      ShowLowerMessageBox


SECTION "Raster Data", ROMX

DEF LY_HUD_END          EQU 7
DEF LY_BG_START         EQU 11
DEF LY_GROUND           EQU 59
DEF LY_BAR_SHOCK        EQU 63+16*0
DEF LY_BAR_ELECTRIFY    EQU 63+16*1
DEF LY_BAR_EMPOWER      EQU 63+16*2
DEF LY_BOTTOM_MESSAGE   EQU 63+16*2+8
DEF LY_BAR_INVIGORATE   EQU 63+16*3
DEF LY_BAR_FOCUS        EQU 63+16*4

DEF WX_LEFT_EDGE        EQU 7
DEF WX_LOWER_HUD        EQU 48+7
DEF WX_RIGHT_EDGE       EQU 160+7-2
DEF WX_OFF_SCREEN       EQU $FF

DEF SCX_TOP_DIALOG      EQU 96

; Each entry is: LY, SCX, WX, LCDC
BaseRasterLookup:
    ; Setup HUD state
    db LCDC_HUD_ENABLE, WX_LEFT_EDGE
    ; Disable BG to avoid 4 pixels of overflow tiles
    db LY_HUD_END, 0, WX_OFF_SCREEN, LCDC_BG_DISABLE
    ; Enable BG once we need it for the scrolling background
    db LY_BG_START, 0, WX_OFF_SCREEN, LCDC_BG_ENABLE
    ; Enable window to show the enemy
    db 23, 0, WX_RIGHT_EDGE, LCDC_ENEMY_ENABLE
    ; Toggle BG tilemap to show attack line (matches background by default)
    db 47, 0, WX_RIGHT_EDGE, LCDC_ENEMY_ENABLE
    db 48, 0, WX_RIGHT_EDGE, LCDC_ENEMY_ENABLE
    ; Disable window to stop showing enemy
    db 55, 0, WX_OFF_SCREEN, LCDC_ENEMY_DISABLE

    ; Entry for independent ground scrolling
    db LY_GROUND, 0, WX_OFF_SCREEN, LCDC_GROUND_ENABLE

    ; Enable window for lower HUD/etc, and apply timer bar SCX effect
    db LY_BAR_SHOCK, 0, WX_LOWER_HUD, LCDC_BAR_ENABLE_NO_OBJ
    db LY_BAR_ELECTRIFY, 0, WX_LOWER_HUD, LCDC_BAR_ENABLE
    db LY_BAR_EMPOWER, 0, WX_LOWER_HUD, LCDC_BAR_ENABLE
    db LY_BAR_INVIGORATE, 0, WX_LOWER_HUD, LCDC_BAR_ENABLE
    db LY_BAR_FOCUS, 0, WX_LOWER_HUD, LCDC_BAR_ENABLE

    db 255, 0, 0, 0 ; terminate
.end

SECTION "Cursor Templates", ROMX, ALIGN[5]
; This simply stores the 8 OAM bytes to locate the two cursors based on the selected button pair
; The tile IDs and attr bytes are super redundant. If we move to dynamic cursor
;  coordinates we could likely trim all that (or store it just once).
CursorTemplates:
    db $6C, $66, TILE_B_CURSOR, 0, $6C, $82, TILE_A_CURSOR, 0
    db $7C, $7E, TILE_B_CURSOR, 0, $7C, $9A, TILE_A_CURSOR, 0
    db $7C, $4E, TILE_B_CURSOR, 0, $7C, $6A, TILE_A_CURSOR, 0
    db $8C, $66, TILE_B_CURSOR, 0, $8C, $82, TILE_A_CURSOR, 0

    ; Item cursor templates
    ; Note: Initial and final item cursors are identical, which seems
    ;  wasteful, but the only alternative I could come up with was checking
    ;  hMessageBoxActive in shared handlers and branching based on that,
    ;  which would be 12 bytes of code (10 if I use HRAM), and this is only 8!
    db $84, $46, TILE_B_CURSOR, 0, $84, $62, TILE_A_CURSOR, 0
    db $84, $46, TILE_B_CURSOR, 0, $84, $62, TILE_A_CURSOR, 0


SECTION "Timer Template", ROMX
; wTimers includes the timers as well as handler addresses for each timer.
; This template is copied over the timers when initializing the battle so the
;  handler addresses are correct.

; Each timer is made up of:
;  - 1 byte frame counter (counts down from 60)
;  - 1 byte shift nibbles (low nibble Timer shift, high nibble Frame shift)
;  - 2 byte BCD for wBattleTimer, 2 byte decimal (only low byte used) for all others
;  - Address of tick handler
;  - 2 padding bytes
TimerTemplate:
    db FRAME_COUNTER_MAX, $00, 0, 4 ; First increase is 'slow' for every speed setting
    dw SpeedTimerTick, 0
    db 0, $33, 0, 0
    dw ShockTimerTick, 0
    db 0, $42, 0, 0
    dw ElectrifyTimerTick, 0
    db 0, $51, 0, 0
    dw EmpowerTimerTick, 0
    db 0, $51, 0, 0
    dw InvigorateTimerTick, 0
    db 0, $33, 0, 0
    dw FocusBuffTimerTick, 0
    db 0, $00, 0, 0
    dw FocusCooldownTimerTick, 0


; Define the energy/chage requirements for skills
SECTION "Skill Requirements", ROMX
SkillRequirements:
.jet
    db 0, 0
.zap
    db COST_ZAP, 0
.shock
    db COST_SHOCK, 0
.discharge
    db COST_DISCHARGE, 1
.electrify
    db COST_ELECTRIFY, 1
.empower
    db COST_EMPOWER, 1
.invigorate
    db 0, 0
.focus
    db 0, 0

; For each skill, define the:
;  - tilemap address of the top-left corner
;  - base tile ID of the top-left corner
;  - initial tile ID of the top-left corner at the start of a battle
SECTION "Skill Button Tilemap and Tile IDs", ROMX
DEF DISABLED_TILE_OFFSET EQU $20
SkillButtonTilemapsAndTiles:
.jet
    dw BUTTON_ICON_SKILL_0
    db LOW(vSkillTiles.jet / 16)
.zap
    dw BUTTON_ICON_SKILL_4
    db LOW(vSkillTiles.zap / 16)
.shock
    dw BUTTON_ICON_SKILL_1
    db LOW(vSkillTiles.shock / 16)
.discharge
    dw BUTTON_ICON_SKILL_5
    db LOW(vSkillTiles.discharge / 16)
.electrify
    dw BUTTON_ICON_SKILL_2
    db LOW(vSkillTiles.electrify / 16)
.empower
    dw BUTTON_ICON_SKILL_6
    db LOW(vSkillTiles.empower / 16)
.invigorate
    dw BUTTON_ICON_SKILL_3
    db LOW(vSkillTiles.invigorate / 16)
.focus
    dw BUTTON_ICON_SKILL_7
    db LOW(vSkillTiles.focus / 16)


; Shift bytes are comprised of a high nibble for left shift count and
;  a low nibble for right shift counts. Only the low or high nibble should
;  be defined. The result of the shifts should result in the max health
;  ending up as $40 (64).
DEF HEALTH_SHIFT_256 EQU $60
DEF HEALTH_SHIFT_512 EQU $50
DEF HEALTH_SHIFT_1024 EQU $40
DEF HEALTH_SHIFT_2048 EQU $30
DEF HEALTH_SHIFT_4096 EQU $20
DEF HEALTH_SHIFT_8192 EQU $10
DEF HEALTH_SHIFT_16384 EQU $00
DEF HEALTH_SHIFT_32768 EQU $01

SECTION UNION "8000 tiles", VRAM[$8000]

vLobsterTiles:
    ds 16 * 4 * 4

vCursorTiles:
    ds 16 * 4

vSkillActivateTiles:
    ds 16 * 4

vBuffTiles:
.empower    ds 16 * 2
.invigorate ds 16 * 2
.focus      ds 16 * 2
.clarity    ds 16 * 2
.secondWind ds 16 * 2

vObstacleTiles:
    ds 16 * 4 * 8


SECTION UNION "8800 tiles", VRAM[$8800]

vDigitTiles:
    ds 16 * 10 * 2

vPadding0:
    ds 16 * 7

; Placeholder to match/protect lingering tiles from RoomStatus
vDisabledTiles:
    ds 16 * 4

vMessageTiles:
    ds 16 * (18 * 3 - 7)
.end

vIconsTiny:
.skills     ds 16 * 9
.items      ds 16 * 4
.speed      ds 16

vAButtonTile: ds 16

vStartTiles:
    ds 16 * 3

vItemTiles:
.FirstStrike    ds 16 * 4
.Blitz          ds 16 * 4
.FinalWord      ds 16 * 4
.SecondWind     ds 16 * 4

vFillingBarTiles:
    ds 16 * 9

vPearlTile:
    ds 16

vClarityTile:
    ds 16

SECTION UNION "9000 tiles", VRAM[$9000]

vBackgroundTiles:
    ds 16 * 23

vTerrainTiles:
    ds 16 * 3

vTimerBarTiles:
    ds 16 * 6

vEnemyTiles::
    ds 16 * 16

vSkillTiles:
.jet        ds 16 * 4
.zap        ds 16 * 4
.shock      ds 16 * 4
.discharge  ds 16 * 4
.electrify  ds 16 * 4
.empower    ds 16 * 4
.invigorate ds 16 * 4
.focus      ds 16 * 4

vSkillTilesDim:
    ds 16 * 4 * 8

vUITiles:
    ds 16 * 16
.end