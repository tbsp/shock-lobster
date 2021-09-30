;
; Status/loadout screen for Shock Lobster
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
INCLUDE "charmap.asm"
INCLUDE "hiscore.inc"
INCLUDE "sound_fx.inc"

DEF STATUS_HEIGHT_TILES EQU 14
DEF STATUS_WIDTH_TILES  EQU 8

DEF MAX_MENU_DEPTH      EQU 3
DEF MAX_SELECTION_INDEX EQU 7

DEF DESCRIPTION_HEIGHT_TILES    EQU 9
EXPORT DESCRIPTION_HEIGHT_TILES ; Exported for vwf.asm TextClear

DEF WX_LEFT_EDGE        EQU 7

DEF SKILL_ICON_Y        EQU $60
DEF UPGRADE_ICON_Y      EQU $70
DEF ENABLED_ICON_BASE_X EQU $18

DEF vBorderTopTilemap    EQU $9800
DEF vBorderMiddleTilemap EQU $9820

DEF vSelectTilemap      EQU $9822
DEF vStartTilemap       EQU $9802

DEF vDamageTilemap      EQU $99A4
DEF vPearlTilemap       EQU $980B

; The name+description are drawn first on the tilemap because they will appear
;  on the window, and we can't change the start line of the window, but we can
;  change the start line of the background!
DEF vNameTilemap        EQU $9841
DEF vStateTilemap       EQU $984D
DEF vDescriptionTilemap EQU $9881
EXPORT vDescriptionTilemap  ; Exported for vwf.asm TextClear
DEF vLabelsTilemap      EQU $99A2
DEF vMiscTilemap        EQU $9AAA

DEF vSkillIconTilemap   EQU $9A02
DEF vUpgradeIconTilemap EQU $9A62
DEF vMiscIconTilemap    EQU $9AC2

DEF vItemCountTilemap   EQU $9B02

RSRESET
DEF OAM_OFFSET_CURSOR   RB sizeof_OAM_ATTRS * 3 ; top bracket, A button, bottom bracket
DEF OAM_OFFSET_DETAILS  RB sizeof_OAM_ATTRS * 9 ; details popup

DEF START_CURSOR_Y      EQU 8
DEF START_CURSOR_X      EQU $18
DEF START_CURSOR_A_Y    EQU $10
DEF START_CURSOR_A_X    EQU $30

DEF STATE_A_Y           EQU $8F ; Cursor/panel shifted 1 pixel up verticall off grid
                                ;  to avoid signed shift issue in cursor update code.
DEF STATE_A_Y_SHOWN     EQU $48
DEF STATE_A_X           EQU $90

DEF CURSOR_BASE_Y       EQU $37
DEF CURSOR_BASE_X       EQU $08
DEF CURSOR_BASE_Y_DESCRIPTION   EQU $24 ; Y coordinate of cursor when description is shown

DEF START_BUTTON_Y      EQU $10
DEF START_BUTTON_X      EQU $20
DEF SELECT_BUTTON_Y     EQU $88
DEF SELECT_BUTTON_X     EQU $80

DEF A_BUTTON_Y          EQU $48
DEF A_BUTTON_X          EQU $6F
DEF STATE_Y             EQU $90
DEF STATE_BASE_X        EQU $78
DEF COST_BASE_X         EQU $98

DEF SCY_HIDDEN          EQU 89
DEF SCY_SKILLS          EQU 88+20
DEF SCY_UPGRADES        EQU 88+44
DEF SCY_MISC            EQU 88+68

DEF DETAILS_POPUP_DELAY EQU 60 * 2  ; Frames before details popup appears
DEF DETAILS_Y           EQU $88 - 1
DEF DETAILS_BASE_X      EQU $40 ; SCRN_X-16

; Cap pearls at lower than the full HISCORE_LENGTH
DEF MAX_PEARL_DIGITS    EQU 5
EXPORT MAX_PEARL_DIGITS ; also used in RoomBattle

;******************************************************************************
;**                                  Variables                               **
;******************************************************************************

SECTION "Status Variables", WRAM0, ALIGN[4]
wSelectionDepth:    ds 1 ; Depth of the menu selection (0=Start, 1=Skills, 2=Upgrades, 3=Palette/Item, 4=Options)
wSelectedIndex:     ds 1 ; Current menu selection index
wSelectedItemAction:ds 1 ; Action to be performed on current item (0=toggle enable, 1=unlock)
wDescriptionVisible:ds 1 ; Flag indicating if the description is visible or not

wCursorTargetCoords:ds 6 ; Target Y/X coordinates of the two cursor sprites (and A)
wSCYTarget:         ds 1 ; Target SCY value
wLYTarget:          ds 1 ; Target LY value to show description panel
wItemCostHiScore:   ds HISCORE_LENGTH   ; Item cost used to deduct pearl costs

wResetSaveCounter:  ds 1 ; Count how many times the player has pressed A to reset the save
wDetailsLowByte:    ds 1 ; Low byte of pointer to details popup animation path

SECTION UNION "8000 tiles", VRAM[$8000]
vPadding:   ds 16 * 16
vDetailsTiles:  ds 16 * 9
vUICursors:
.bracket    ds 16
.aButton    ds 16
    
SECTION UNION "8800 tiles", VRAM[$8800]
vDigitTiles:    ds 16 * 10 * 2

SECTION UNION "8800 tiles", VRAM[$8800]
; Due to limited tile VRAM we interlace the start/select tiles between
;  the digits, which are spaced out in battle for 8x16 sprites, and done
;  so elsewhere so we can reuse code such as PrintScore.
vZeroDigitTile: ds 16
vStartTiles:    ds 16 * 3 * 2
vSelectTiles:   ds 16 * 4 * 2
; vCheckbox:
; .empty          ds 16
; .full           ds 16
vInterlaceEnd:  ds 16 * 5

vUITiles:
.corner         ds 16
.horizontal     ds 16
.vertical       ds 16

vIconTiles:
.locked         ds 16 * 4
.disabled       ds 16 * 4
.skills         ds 16 * 4 * 8
.items          ds 16 * 4 * 4
.speed          ds 16 * 4
.music          ds 16 * 4
.dpad           ds 16 * 4
.reset          ds 16 * 4

vStatusTiles:   ds 16 * 14
.end
vNameTiles:     ds 16 * 12
.end

   
vStateTiles:
.enable         ds 16 * 3
.disable        ds 16 * 4
.end
    

SECTION UNION "9000 tiles", VRAM[$9000]
vBlankTile:         ds 16
vDescriptionTiles:  ds 16 * (16 * 8 - 6)
.end
vPearlTile:         ds 16
vMiscTiles:         ds 16 * 4
.end

;******************************************************************************
;**                                    Data                                  **
;*****************************************************************************

SECTION "Status Data", ROMX
StatusText:
    db "High<NEWLINE><NEWLINE>"
    db "Skills<NEWLINE><NEWLINE><NEWLINE>"
    db "Upgrades<NEWLINE><NEWLINE><NEWLINE>"
    db "Items<END>"

MiscText:
    db "Misc<END>"

ItemIcons::
    INCBIN "res/gfx/item_icons_linear.2bpp"
.end::

MiscIcons::
    INCBIN "res/gfx/misc_icons_linear.2bpp.pb16"
.end

DetailsTiles:
    INCBIN "res/gfx/details.2bpp"
.end

UICursors::
    INCBIN "res/gfx/ui_cursors.2bpp"
.end

StartSelectTiles::
    INCBIN "res/gfx/start_select.2bpp"
.end

UITiles::
    INCBIN "res/gfx/ui.2bpp"
.end::

DigitTiles::
    INCBIN "res/gfx/digits.2bpp"
.end

EnableDisable:
    db "EnableDisable<END>"

DEF LCDC_WINDOW_ON EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ8 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9800
DEF LCDC_WINDOW_OFF EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ8 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINOFF | LCDCF_WIN9800

; LY values for the description box when hidden/shown
DEF LY_HIDDEN   EQU 118
DEF LY_SHOWN    EQU 47

; Each entry is: LY, SCX, WX, LCDC
StatusRasterTable:
    db LCDC_WINDOW_ON, WX_LEFT_EDGE
    db    7, 0, WX_LEFT_EDGE+1, LCDC_WINDOW_OFF
.description
    db LY_HIDDEN, 0, WX_LEFT_EDGE, LCDC_WINDOW_ON
    ;db LCDC_WINDOW_ON, WX_LEFT_EDGE
    db $FF
.end

; SCY Values for the 3 sections of the status screen when the description is shown
SCYTable:
    db SCY_SKILLS, SCY_SKILLS, SCY_UPGRADES, SCY_MISC

; The base tile IDs upgrades use from the skill icons
UpgradeBaseTileIDs:
    db LOW((vIconTiles.skills + 16 * 4 * 0) / 16)
    db LOW((vIconTiles.skills + 16 * 4 * 2) / 16)
    db LOW((vIconTiles.skills + 16 * 4 * 4) / 16)
    db LOW((vIconTiles.skills + 16 * 4 * 1) / 16)
    db LOW((vIconTiles.skills + 16 * 4 * 3) / 16)
    db LOW((vIconTiles.skills + 16 * 4 * 5) / 16)
    db LOW((vIconTiles.skills + 16 * 4 * 7) / 16)
    db LOW((vIconTiles.skills + 16 * 4 * 1) / 16)

MiscBaseTileIDs:
    db LOW((vIconTiles.items + 16 * 4 * 0) / 16)
    db LOW((vIconTiles.items + 16 * 4 * 1) / 16)
    db LOW((vIconTiles.items + 16 * 4 * 2) / 16)
    db LOW((vIconTiles.items + 16 * 4 * 3) / 16)
    db LOW((vIconTiles.speed) / 16)
    db LOW((vIconTiles.music) / 16)
    db LOW((vIconTiles.dpad) / 16)
    db LOW((vIconTiles.reset) / 16)

; The initial OAM state of the dynamic cursor
CursorInitialState:
    db 1, 0, LOW(vUICursors.bracket / 16), OAMF_PAL0
    db 1, 0, LOW(vUICursors.bracket / 16), OAMF_YFLIP | OAMF_XFLIP | OAMF_PAL0
    db START_CURSOR_A_Y, START_CURSOR_A_X, LOW(vUICursors.aButton / 16), OAMF_PAL1
.end

StartCursorCoordinates:
    db START_CURSOR_Y, START_CURSOR_X
    db START_CURSOR_Y, START_CURSOR_X
    db START_CURSOR_A_Y, START_CURSOR_A_X
.end

; Note: If we have to drop to ALIGN[5], just have to add LOW(ItemCosts) to
;  E after .itemLocked
SECTION "Item Costs", ROM0, ALIGN[8]
; Cost of skills/upgrades/palettes in pearls/10 (max cost 2550)
; Note: No price can include zero digits, as they won't be drawn correctly
ItemCosts:
.Jet            db 0
.Zap            db 0
.Shock          db 0
.Discharge      db 0
.Electrify      db 12
.Empower        db 14
.Invigorate     db 26
.Focus          db 32

.Amplify        db 4
.Detonate       db 6
.HighPressure   db 11
.Overcharge     db 19
.ResidualCharge db 21
.Expertise      db 26
.Clarity        db 34
.Refresh        db 37

.firstStrike    db 15
.blitz          db 21
.finalWord      db 36
.secondWind     db 52


GameStartText:
    db "Start game<END>"

; Note: These IDs are backwards as we use a downward counting loop
;  counter as the address low byte
SECTION "Icon Row Base IDs", ROMX, ALIGN[8]
IconRowIndicies::
.skills::   db (LOW((vIconTiles.skills + 16 * 4 * 7) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 6) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 5) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 4) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 3) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 2) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 1) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 0) / 16) - LOW((vIconTiles.locked) / 16)) / 4

.upgrades:: db (LOW((vIconTiles.skills + 16 * 4 * 1) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 7) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 5) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 4) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 2) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 0) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 3) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 1) / 16) - LOW((vIconTiles.locked) / 16)) / 4            

; This table is reused for the game over loadout display, though with tiny icons
;  and a slight offset. These item entries aren't used for the status screen and
;  only make sense in the game over loadout context.
.items::    db (LOW((vIconTiles.skills + 16 * 4 * 11) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 10) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 9) / 16) - LOW((vIconTiles.locked) / 16)) / 4
            db (LOW((vIconTiles.skills + 16 * 4 * 8) / 16) - LOW((vIconTiles.locked) / 16)) / 4

SECTION "Details Popup Hiscore Threshold", ROMX
; The hiscore above which the details popup stops showing as the player is
;  believed to be good enough that they're likely aware of where to find details.
DetailsPopupHiscoreThreshold:
    db $80, $80, $80, $80, $01, $00, $00, $00
.end
ASSERT(DetailsPopupHiscoreThreshold.end - DetailsPopupHiscoreThreshold == HISCORE_LENGTH)

;******************************************************************************
;**                                    Code                                  **
;*****************************************************************************

SECTION "Status Code", ROM0

CopyDigitTiles::
    ; Copy digits with spaces in-between for use with 8x16 sprites
    ld      de, DigitTiles
    ld      hl, vDigitTiles
    ld      b, 10
.digitLoop
    push    bc
    ld      c, 16
    call    LCDMemcpySmall
    lb      bc, 0, 16
    call    LCDMemsetSmallFromB
    pop     bc
    dec     b
    jr      nz, .digitLoop

    ret

BorderColumnCopy:
    lb      bc, LOW(vUITiles.vertical / 16), 28
    ld      de, $20
.loop
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-

    ld      [hl], b
    add     hl, de

    dec     c
    jr      nz, .loop
    ret

BorderRowCopy:
    ld      b, LOW(vUITiles.corner / 16)
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
    inc     l
    inc     b
    ld      c, SCRN_X_B - 2
    call    LCDMemsetSmallFromB
    dec     b
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      [hl], b
    ret

; @param B  Unlocked bitmask
; @param C  Enabled bitmask
; @param HL Tilemap base address for icon
UpdateIconRow:
    ; `e` acts as the low byte of the icon index pointer when needed, and also
    ;  the loop counter, but we only check the lower 3 bits for the loop check.
.loop
    dec     e   ; decrement `e` here so the [de] pointer is correct
    xor     a   ; start with a base tile index
    srl     b   ; get unlocked bit
    adc     0   ; +1 to tile index if unlocked
    srl     c   ; get enabled bit
    jr      nc, .notEnabled
    ; enabled, load tile ID from lookup table
    ld      d, HIGH(IconRowIndicies)
    ld      a, [de]
.notEnabled
    add     a   ; baseTileIndex * 4
    add     a
    add     LOW(vIconTiles.locked / 16) ; add tile ID of 0th tile
    ld      d, a

:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-

    ld      a, d
    ld      [hli], a
    inc     a
    ld      [hld], a

    ; move down a row!
    ld      d, a
    ld      a, l
    add     $20
    ld      l, a

    ; I just can't find a way to make this fast enough (while still supporting
    ;  the two mis-aligned rows of icons to not need two STAT checks).
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, d

    inc     a
    ld      [hli], a
    inc     a
    ld      [hli], a

    ; move back up a row!
    ld      a, l
    sub     $20
    ld      l, a

    ld      a, e
    and     %111    ; check if lower 3 bits are zero
    jr      nz, .loop

    ret


; @param HL target tilemap address
; @param DE table of base tile IDs
; @param B  delta to apply to table tile ID
IconRowCopyFromTable:
    ld      c, 8
.loop
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-

    ld      a, [de]
    add     b
    ld      [hli], a
    inc     a
    ld      [hli], a
    inc     de

    dec     c
    jr      nz, .loop
    ret


; @param    A  Binary value of bit (0-7)
; @returns  D  Bitmask with the given bit set
; @destroys ADF
GetBitmaskFromA:
    ; Get bitmask for selection (TODO: Really no smaller way?)
    ld      d, 1
    or      a
    jr      z, .firstItem
.shiftLoop
    sla     d
    dec     a
    jr      nz, .shiftLoop
.firstItem
    ret

; Print damage hiscore for current game speed
PrintDamageHiscore:
    ld      a, [wGameSpeed]
    add     a   ; speed*8 (HISCORE_LENGTH == 8)
    add     a
    add     a
    ld      de, wMaxDamageScore - HISCORE_LENGTH
    add     e
    ld      e, a
    ld      hl, vDamageTilemap
    ld      c, HISCORE_LENGTH
    call    PrintScore
    ret


InitStatus::

    ; Clear tilemap contents lingering from prior mode (battle or title)
    ld      hl, $9800
    ld      bc, $640
    xor     a
    call    LCDMemset

    ; Clear raster table for maximum VRAM access time during heavy writes to follow
    ld      a, LCDCF_ON
    call    ResetRasterLookup

    ; TODO: Remove if we end up using the cursor sprite slots from
    ;  the loadout screen, since they're the only lingering ones.
    ld      hl, wShadowOAM
    ld      c, $A0
    rst     MemsetSmall

    call    CopyDigitTiles

    ld      hl, wDetailsPanelShown
    ld      a, [hli]
    or      a
    ld      a, 0    ; preserve flags
    jr      nz, .dontShowDetailsPopup
    push    hl
        ; Don't show the popup if player's hiscore is high enough
        ld      a, [wGameSpeed]
        add     a   ; speed*8 (HISCORE_LENGTH == 8)
        add     a
        add     a
        ld      hl, wMaxDamageScore - HISCORE_LENGTH
        add     l
        ld      l, a
        ld      de, DetailsPopupHiscoreThreshold
        call    CpHiScore
    pop     hl
    ld      a, 0    ; preserve flags
    jr      nc, .dontShowDetailsPopup
    ld      a, DETAILS_POPUP_DELAY
.dontShowDetailsPopup
    ld      [hl], a

    ; TODO: Line up this data in order for straight-through copies
    ld      de, DetailsTiles
    ld      hl, vDetailsTiles
    ld      c, DetailsTiles.end - DetailsTiles
    call    LCDMemcpySmall

    ;ld      de, UICursors
    ;ld      hl, vUICursors
    ld      c, UICursors.end - UICursors
    call    LCDMemcpySmall

    ; ld      de, StartSelectTiles
    ASSERT(StartSelectTiles == UICursors.end)
    ld      hl, vStartTiles
    ld      b, 7 ; start + select
.startSelectInterlaceLoop
    ld      c, 16
    call    LCDMemcpySmall
    ld      a, l
    add     16      ; skip digit tile
    ld      l, a
    dec     b
    jr      nz, .startSelectInterlaceLoop

    ; TODO: Consider settling on a standard location for UI data between
    ;  Loadout/Status/Score/Battle and copying it as few times as necessary.
    ld      de, UITiles + 16 * 5
    ld      hl, vUITiles
    ld      c, 16 * 9
    call    LCDMemcpySmall

    ; Disabled/Locked tiles
    ld      hl, vIconTiles
    ld      de, LockedSkillTile
    ld      c, 64 * 2
    call    LCDMemcpySmall

    ; Skill tiles
    ld      de, SKILL_TILES
    ld      bc, 16 * 4 * 8
    call    LCDMemcpy

    ; Item icons
    ld      de, ItemIcons
    ;ld      c, 0
    call    LCDMemcpySmall

    ; Misc icons
    ld      de, MiscIcons
    INCLUDE "res/gfx/misc_icons_linear.2bpp.pb16.size"
	ld      b, NB_PB16_BLOCKS
	PURGE NB_PB16_BLOCKS
    call    pb16_unpack_block_lcd

    ; Pearl tile
    ld      de, PEARL_TILE
    ld      hl, vPearlTile
    ld      c, 16
    call    LCDMemcpySmall

    ; Build borders
    ld      hl, vBorderTopTilemap
    push    hl
    call    BorderColumnCopy
    ld      hl, vBorderTopTilemap + 19
    call    BorderColumnCopy
    pop     hl
    call    BorderRowCopy
    ld      l, LOW(vBorderMiddleTilemap)
    call    BorderRowCopy

    ; Start button label
    ; Fails often on inaccessible VRAM, so include a check
    ld      hl, vStartTilemap
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, LOW(vStartTiles / 16)
    ld      [hli], a
    inc     a
    inc     a
    ld      [hli], a
    inc     a
    inc     a
    ld      [hl], a

    ; TODO: Generate icon tilemaps based on unlocked/enabled/etc state,
    ;  using the same code we'll then use to update the states later.

    ; Inputs: tilemap address, base ID, unlock/enable flags somehow
    ;  -> Can we use the adc trick from before somehow?

    ld      hl, wUnlockedSkills
    ld      a, [hli]
    ld      b, a
    ld      c, [hl]
    ld      hl, vSkillIconTilemap
    ld      e, LOW(IconRowIndicies.skills) + 8
    call    UpdateIconRow

    ld      hl, wUnlockedUpgrades
    ld      a, [hli]
    ld      b, a
    ld      c, [hl]
    ld      hl, vUpgradeIconTilemap
    ld      e, LOW(IconRowIndicies.upgrades) + 8
    call    UpdateIconRow

    ; Draw the crazy items/palette/options row
    ld      hl, vMiscIconTilemap
    ld      de, MiscBaseTileIDs
    ld      b, 0
    push    de
    call    IconRowCopyFromTable
    pop     de
    ld      l, LOW(vMiscIconTilemap + $20)
    ld      b, 2
    call    IconRowCopyFromTable

    ; Select button label
    ; Fails often on inaccessible VRAM, so include a check
    ld      hl, vSelectTilemap
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, LOW(vSelectTiles / 16)
    ld      [hli], a
    inc     a
    inc     a
    ld      [hli], a
    inc     a
    inc     a
    ld      [hli], a
    inc     a
    inc     a
    ld      [hli], a

    ; Write bulk text
    ld      a, STATUS_WIDTH_TILES * 8 + 1
    lb      bc, LOW(vStatusTiles / 16), LOW(vStatusTiles.end / 16) - 1
    lb      de, STATUS_HEIGHT_TILES, $80
    call    TextInit

    ld      hl, StatusText
    ld      a, TEXT_NEW_STR
    call    PrintVWFText
    ld      hl, vLabelsTilemap
    call    SetPenPosition

    call    PrintVWFChar
    call    DrawVWFChars

    ld      a, STATUS_WIDTH_TILES * 8 + 1
    lb      bc, LOW(vMiscTiles / 16), LOW(vMiscTiles.end / 16) - 1
    lb      de, 1, $90
    call    TextInit

    ld      hl, MiscText
    ld      a, TEXT_NEW_STR
    call    PrintVWFText
    ld      hl, vMiscTilemap
    call    SetPenPosition

    call    PrintVWFChar
    call    DrawVWFChars

    ; Initialize text engine
    ld      a, TEXT_WIDTH_TILES * 8 + 1
    lb      bc, LOW(vStateTiles / 16), LOW(vStateTiles.end / 16) - 1
    lb      de, 1, $80
    call    TextInit

    ; Write enable/disable tiles (but no tilemap, as we'll show them with sprites)
    ld      hl, EnableDisable
    ld      a, TEXT_NEW_STR
    call    PrintVWFText
    call    PrintVWFChar

    ; Print score for current game speed
    call    PrintDamageHiscore

    ; Print pearl with end caps
    ASSERT(HIGH(wMaxDamageScore) == HIGH(wCurrentPearls))
    ; There's some register juggling here to pack VRAM writes cleanly 
    ;  into a single STAT check.
    ld      e, LOW(wCurrentPearls) + 3
    lb      bc, LOW(vUITiles.corner / 16), HISCORE_LENGTH - 3
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      hl, vPearlTilemap + 6
    ld      [hl], b
    ld      l, LOW(vPearlTilemap) - 1
    ld      [hl], b
    inc     l
    ld      a, LOW(vPearlTile / 16)
    ld      [hli], a
    call    PrintScore

    ; Setup HRAM entries for UpdateEnabledOverlay
    ld      a, SKILL_ICON_Y
    ldh     [hEnabledOAMY], a
    ld      a, ENABLED_ICON_BASE_X
    ldh     [hEnabledOAMBaseX], a
    ld      a, 8
    ldh     [hEnabledOAMDeltaX], a
    xor     a ; ld      a, sizeof_OAM_ATTRS * 0
    ldh     [hEnabledOAMLowByte], a

    ld      a, UPGRADE_ICON_Y
    ldh     [hEnabledOAMY], a
    ;ld      a, ENABLED_ICON_BASE_X
    ;ldh     [hEnabledOAMBaseX], a
    ;ld      a, 8
    ;ldh     [hEnabledOAMDeltaX], a
    ld      a, sizeof_OAM_ATTRS * 8
    ldh     [hEnabledOAMLowByte], a

    call    UpdateItemCounts

    ; Default cursor state
    ld      de, CursorInitialState
    ld      hl, wShadowOAM + OAM_OFFSET_CURSOR
    ld      c, CursorInitialState.end - CursorInitialState
    rst     MemcpySmall

    ld      a, HIGH(wShadowOAM)
    ldh     [hOAMHigh], a

    ; Init menu
    xor     a
    ld      hl, wSelectionDepth
    ; ld      [hli], a
    ; ld      [hli], a
    ; ld      [hli], a
    ; ld      [hli], a

    ; Initialize smooth cursor target coords
    ;ld      hl, wCursorTargetCoords
    ;ld      c, 6
    ld      c, 4+6 ; Zero wSelectionDepth items plus wCursorTargetCoords
    rst     MemsetSmall

    ; HL = wSCYTarget
    ld      a, SCY_HIDDEN
    ldh     [hSCY], a
    ld      [hli], a    ; set wSCYTarget
    ld      a, LY_HIDDEN
    ld      [hli], a    ; set wLYTarget

    ;ld      hl, wItemCostHiScore ; HL already points here
    call    ResetHiScore
    ld      [hli], a    ; wResetSaveCounter
    ld      [hli], a    ; wDetailsLowByte

    ; Init music (only if returning from battle)
    ldh     a, [hLastMode]
    cp      MODE_BATTLE
    jr      nz, .noMusicInit

    ; No longer needed as song_title now uses the noise channel in the first pattern

    ; ; Mute the noise channel, which may be lingering from battle
    ; ; (saves storing an entire pattern just for that in song_title)
    ; lb      bc, 3, 1 ; channel index, 1=mute enabled
    ; call    hUGE_mute_channel ; also trashes E
  
    ld      hl, song_title
    call    hUGE_init
.noMusicInit

    ; Initial PPU state
    xor     a
    ldh     [hSCX], a
    ldh     [rWY], a

    ; Load status raster LUT
    ld      de, StatusRasterTable
    ld      hl, wRasterLookup
    ld      c, StatusRasterTable.end - StatusRasterTable
    rst     MemcpySmall

    call    FadeIn

    call    InputProcessing.updateCursorFull

RoomStatus::
    ; TODO: The sprite/SCY/raster updates share a chunk of code, is there
    ;  any way we can reuse that to reduce the size of this block?

    ; Update smooth cursor position every frame
    ld      hl, wShadowOAM + OAM_OFFSET_CURSOR
    ld      de, wCursorTargetCoords
    ld      b, 3   ; number of sprites to update
.cursorLoop
    ld      c, 2    ; number of coords to update
.coordLoop
    ld      a, [de]
    inc     de
    sub     [hl]
    jr      z, .yEqual
    cp      1
    jr      z, .finalDelta
    ; Note: Since the A button sprite moved $80 pixels vertically
    ;  when moving from the start position to down low, this `sra`
    ;  changes the $80 to $C0 and leads to a vertical wrap. We can't
    ;  use `srl` because we need the sign bit for bracket movement.
    ; The solution to this issue was to merely move the hidden panel
    ;  and A button sprite up one pixel so the delta is $7F!
    sra     a   ; half the delta (unless it's one)
.finalDelta
    add     [hl]
    ld      [hl], a
.yEqual
    inc     l
    dec     c
    jr      nz, .coordLoop
    inc     l   ; advance to second sprite
    inc     l
    dec     b
    jr      nz, .cursorLoop

    ld      a, HIGH(wShadowOAM)
    ldh     [hOAMHigh], a

    ; Update SCY position every frame (ideally before LY=8)
    ld      c, LOW(hSCY)
    ldh     a, [c]
    ld      b, a
    ld      a, [de]
    sub     b
    jr      z, .regEqual
    cp      1
    jr      z, .finalRegDelta
    sra     a   ; half the delta (unless it's one)
.finalRegDelta
    add     b
    ldh     [c], a
.regEqual

    ; Update raster entry which starts the description every frame
    inc     de
    ld      hl, wRasterLookup + (StatusRasterTable.description - StatusRasterTable)
    ld      a, [hl]
    ld      b, a
    ld      a, [de]
    sub     b
    jr      z, .lyEqual
    cp      1
    jr      z, .finalLYDelta
    sra     a   ; half the delta (unless it's one)
.finalLYDelta
    add     b
    ld      [hl], a
.lyEqual

    ld      a, [wDetailsCounter]
    or      a
    jr      z, .detailCounterInactive
    dec     a
    ld      [wDetailsCounter], a
    jr      nz, .detailsCounterCounting

    ; Details popup counter expired, initialize details popup animation

    ; Start at the end of the animation path so we can use the low byte as
    ;  the 'active' flag as well.
    ld      a, LOW(DetailsAnimationPath.end - 1)
    ld      [wDetailsLowByte], a

.detailCounterInactive
.detailsCounterCounting

    ld      a, [wDetailsLowByte]
    or      a
    jr      z, .noPopupAnimation
    ld      l, a
    ld      h, HIGH(DetailsAnimationPath)
    ld      a, [hld]
    ld      b, a    ; get X coord of first sprite from table
    ld      a, l
    ld      [wDetailsLowByte], a

.notFinishedPopupYet
    ld      hl, wShadowOAM + OAM_OFFSET_DETAILS
    ld      c, LOW(vDetailsTiles / 16)
.detailsLoop
    ld      a, DETAILS_Y
    ld      [hli], a
    ld      [hl], b
    inc     l
    ld      a, b
    add     8
    ld      b, a
    ld      [hl], c
    inc     l
    inc     c
    xor     a
    ld      [hli], a

    ld      a, l
    cp      LOW(wShadowOAM + OAM_OFFSET_DETAILS + sizeof_OAM_ATTRS * 9)
    jr      nz, .detailsLoop

.noPopupAnimation


    ; Wait until LY==8, so the AutoDelay doesn't get confused and yield every frame
    ; If music is enabled we end up here between LY=152 to 6 (usually 0-3)
    ; If music is disabled we end up here around LY==152
    ; Note: This cannot be LY==7, or the STAT interrupt which fires on that line
    ;  will tie up the CPU for the full scanline and this loop would then stall.
; .lyWait
;     ldh     a, [rLY]
;     cp      8
;     jr      nz, .lyWait
    ; Oh wait! Since the first interrupt to fire every frame in RoomStatus is
    ;  a STAT interrupt on scanline 7, we can just halt and will always end up
    ;  exactly where we need to be to avoid the AutoDelay bug.
    halt

    ; The description text uses the AutoDelay feature to print long strings
    ;  without blocking input. Therefore we need to call these every loop to
    ;  get the full string on screen.
    call    PrintVWFChar
    call    DrawVWFChars

    rst     WaitVBlank

    call    InputProcessing

    jp      RoomStatus

InputProcessing:
    ld      hl, wSelectionDepth

    ldh     a, [hPressedKeys]
    and     PADF_UP
    jr      nz, .upPressed

    ldh     a, [hPressedKeys]
    and     PADF_DOWN
    jr      nz, .downPressed

    ldh     a, [hPressedKeys]
    and     PADF_START
    jr      nz, .startBattle

    ldh     a, [hPressedKeys]
    and     PADF_SELECT
    jr      nz, .selectPressed

    ldh     a, [hPressedKeys]
    and     PADF_A
    jp      nz, .aPressed

    inc     l  ; advance to wSelectedIndex for following handlers
    ldh     a, [hPressedKeys]
    and     PADF_LEFT
    jr      nz, .leftPressed

    ldh     a, [hPressedKeys]
    and     PADF_RIGHT
    jr      nz, .rightPressed

    ldh     a, [hPressedKeys]
    and     PADF_B
    ret     z

.returnToTitle
    ld      a, FX_CANCEL
    call    audio_play_fx

    ; Return to title
    ld      b, MODE_TITLE
    jr      .updateMode

.startBattle
    ld      a, FX_START_BATTLE
    call    audio_play_fx

    ; Store level sequence pointer for the upcoming battle
    ; Note: The level initialization occurs in InitBattle
    ld      hl, LevelSequence
    ld      a, l
    ld      [wLevelSequenceAddr], a
    ld      a, h
    ld      [wLevelSequenceAddr+1], a

    ld      b, MODE_BATTLE
.updateMode
    call    FadeOut
    ld      a, b
    ldh     [hGameMode], a
    ld      a, MODE_STATUS
    ldh     [hLastMode], a
    pop     af          ; pop off InputProcessing return address
    ret

.leftPressed
    ld      a, $FF
.rightPressed
    swap    a           ; right: PADF_RIGHT is $10, swap to $01 offset
                        ; left: swap $FF to $FF offset
                        ; (this would be more clever if swap wasn't 2 bytes)
    ld      c, [hl]     ; get wSelectedIndex
    add     c           ; add offset to current index
    and     7           ; will drop $FF down to $07, wrapping to the max
                        ; will drop $08 down to $00, wrapping to the min
    ld      c, a        ; cache new selected index
    dec     l
    ld      a, [hli]    ; get wSelectionDepth
    or      a
    ret     z           ; return if we're at the top depth
    ld      [hl], c     ; store new wSelectedIndex

    ld      a, FX_CURSOR_MOVE
    call    audio_play_fx
    jr      .updateCursorFull

.upPressed
    ld      a, $FF
.downPressed
    rlca                ; down: PADF_DOWN is $80, rlca to $01 offset
                        ; up: rlca $FF to $FF offset
    ld      c, [hl]
    add     c           ; add offset to current depth
    and     3           ; will drop $FF down to $03, wrapping to the max
                        ; will drop $04 down to $00, wrapping to the min
    ld      [hl], a     ; store new depth

    ld      a, FX_CURSOR_MOVE
    call    audio_play_fx

    jr      .updateDescriptionPane

.selectPressed
    ; Toggle description visibility
    ld      a, [wDescriptionVisible]
    xor     1
    ld      [wDescriptionVisible], a
    ; We need to know which sound to play when select is pressed, so we
    ;  have to check the visible state here and then again in the update
    ;  code below (which is reused) by up/down code.
    or      a
    ld      a, FX_DESCR_HIDE
    jr      z, .descriptionToggleSound
    ASSERT(FX_DESCR_HIDE - FX_DESCR_SHOW == 1)
    dec     a
.descriptionToggleSound
    call    audio_play_fx

    ; Clear the details popup and/or ensure it won't be shown
    ; (no harm in doing all this every time select is pressed)
    xor     a
    ld      hl, wShadowOAM + OAM_OFFSET_DETAILS
    ld      c, sizeof_OAM_ATTRS * 9
    rst     MemsetSmall             ; clear shadow OAM entries
    ld      [wDetailsLowByte], a    ; clear any pending animation updates
    ld      hl, wDetailsCounter
    ld      [hld], a                ; clear countdown timer
    inc     a
    ASSERT(wDetailsCounter - 1 == wDetailsPanelShown)
    ld      [hl], a                 ; flag the panel as having been shown

.updateDescriptionPane
    ld      a, [wDescriptionVisible]
    or      a
    ld      a, SCY_HIDDEN   ; setup for hidden case
    ld      c, LY_HIDDEN
    jr      z, .descriptionHidden

    ld      a, [wSelectionDepth]
    ld      d, HIGH(SCYTable)
    add     LOW(SCYTable)
    ld      e, a
    ld      a, [de]
    ld      c, LY_SHOWN
.descriptionHidden
    ld      hl, wSCYTarget
    ld      [hli], a
    ld      [hl], c

    ; Update the cursor for the new state
.updateCursorFull
    ; We try to line up HL correctly here, but with SFX there are too many
    ;  edge cases, so it's just loaded now.
    ld      hl, wSelectionDepth ; setup HL and A for .updateCursor
    ld      a, [hli]
.updateCursor
    or      a   ; check for top depth
    jr      z, .topCursor
.updateForSelectionChange
    dec     a
    ld      e, [hl] ; get wSelectedIndex
    ld      d, a    ; (depth-1) * 3
    add     a
    add     d
    add     a       ; (depth-1) * 24
    add     a
    add     a
    add     CURSOR_BASE_Y
    ld      b, a

    ; Overwrite all that work to get Y if the description is shown
    ld      a, [wDescriptionVisible]
    or      a
    jr      z, .useYValue
    ld      b, CURSOR_BASE_Y_DESCRIPTION
.useYValue

    ; calculate X coordinate based on selected index
    ld      a, CURSOR_BASE_X
    inc     e           ; increment to loop at least once
.cursorOffsetLoop
    add     $10
    dec     e
    jr      nz, .cursorOffsetLoop

    ld      hl, wCursorTargetCoords
    ld      [hl], b         ; top-left bracket
    inc     l
    ld      [hli], a
    add     8   ; height
    ld      c, a

    ld      a, b            ; bottom-right bracket
    add     8   ; width
    ld      [hli], a
    ld      [hl], c
    inc     l

    ld      a, [wDescriptionVisible]
    or      a
    ld      a, STATE_A_Y
    jr      z, .lowerACursor
    ld      a, STATE_A_Y_SHOWN
.lowerACursor
    ld      [hli], a
    ld      a, STATE_A_X
    ld      [hl], a

    ; Reset the save reset counter every time the cursor updates
    xor     a
    ld      [wResetSaveCounter], a

.updateNameDescription
    call    UpdateSelectionStatus
    call    UpdateItemDescription
    ret

.topCursor
    ld      de, StartCursorCoordinates
    ld      hl, wCursorTargetCoords
    ld      c, StartCursorCoordinates.end - StartCursorCoordinates
    rst     MemcpySmall
    jr      .updateNameDescription

.aPressed
    ld      a, [hli]
    or      a   ; check if we're at the top level
    jp      z, .startBattle
    ;cp      3
    ;jr      z, .miscIcons
    ; Standard handling of skill/upgrade rows (toggle/unlock)

    dec     a           ; most things want depth-1 below
    ld      e, a        ; cache depth-1
    ld      a, [hli]    ; get wSelectedIndex
    call    GetBitmaskFromA

    ld      a, [hl]     ; get wSelectedItemAction
    or      a           ; check if unlocking or toggling
    jr      nz, .unlockSelection

    ; See if we're adjusting game speed
    ld      a, e    ; check if we're on the misc row
    cp      2
    jr      nz, .notMiscRow
    bit     OPTIONB_RESET_SAVE, d   ; check if we're resetting the save
    jr      nz, .resetSaveIncrement
    bit     OPTIONB_MUSIC, d    ; check if we're operating on the music bit
    jr      nz, .toggleMusic
    bit     OPTIONB_SPEED, d    ; check if we're operating on the GameSpeed bit
    jr      z, .notMiscIndex
    ; Cycle game speed
    ld      hl, wGameSpeed
    ld      a, [hl]
    inc     a
    and     %00000011
    jr      nz, .notSpeedZero
    inc     a           ; increment zero values up to 1
.notSpeedZero
    ld      [hl], a
    call    PrintDamageHiscore
    jp      UpdateItemCounts
.notMiscRow
.notMiscIndex
.musicMuteHandled
    ; Normal toggle
    add     a           ; add section offset for correct byte pair
    inc     a           ; advance to enabled flags
    ld      l, a
    ld      h, HIGH(wUnlockedSkills)
    ld      a, [hl]     ; get current enabled flags
    xor     d           ; toggle bit
    ld      [hld], a    ; store new enabled flags

    bit     1, e        ; check if we're on the misc row (but leave A alone!)
    jr      nz, .updateStatusOnly
.updateIconRowAfterChange
    ld      c, a        ; setup enabled flags for UpdateIconRow
    ld      b, [hl]     ; setup unlocked flags for UpdateIconRow
    ld      hl, vSkillIconTilemap
    ld      a, e
    or      a           ; check if we're on the skill row
    jr      z, .skillRow
    ld      a, l        ; offset the tilemap target for upgrades (can likely be cleaner)
    add     vUpgradeIconTilemap - vSkillIconTilemap
    ld      l, a
    ld      a, e        ; recover depth-1
.skillRow
    inc     a           ; we actually want depth (not -1) for UpdateIconRow
    add     a           ; depth * 8
    add     a
    add     a
    add     LOW(IconRowIndicies.skills) ; we actually want +8, but get that because depth is 1 higher
    ld      e, a
    call    UpdateIconRow
.updateStatusOnly
    call    UpdateSelectionStatus

    ld      a, FX_CONFIRM
    jp      audio_play_fx

.toggleMusic
    ; We have to mute all channels after disabling music or sounds could linger
    ; Note: the bit hasn't been toggled yet, so we check the inverse of what we want
    push    de          ; protect depth-1
    ld      a, [wEnabledMisc]
    and     OPTIONF_MUSIC_ENABLE
    lb      bc, 4, 0    ; channel+1, 0=mute disabled
    jr      z, .muteMusic   ; music currently disabled, it will now be enabled
    ; music currently enabled, we'll disable it soon, so mute all channels
    inc     c           ; switch to 1=mute enabled
.muteMusic
    ; TODO: Fix this broken mute/unmute code!
    push    bc          ; protect channel/mute state
    dec     b           ; drop +1
    call    hUGE_mute_channel
    pop     bc
    dec     b
    jr      nz, .muteMusic
    pop     de          ; recover depth-1
    ld      a, e        ; recover row byte
    jr      .musicMuteHandled

.resetSaveIncrement
    ; Details panel must be visible to reset the save, so the warning is visible.
    ld      a, [wDescriptionVisible]
    or      a
    ret     z

    ld      hl, wResetSaveCounter
    ld      a, [hl]
    inc     a
    ld      [hl], a
    cp      4
    jr      nz, .updateStatusOnly

    ; User has pressed A four times, so reset to the default save state and
    ;  return to the title screen.

    ; Call the standard InitSRAM code, but leave HL pointing where it already
    ;  is, which won't match the SaveRef (I mean it's pretty unlikely, right?),
    ;  which will trigger loading the default save.
    call    InitSRAM.overrideIDPointer

    jp      .returnToTitle

.unlockSelection
    ; `d` bitmask for selection
    ; `e` menu depth-1
    push    de      ; protect for use after unlocking
    ld      hl, wCurrentPearls
    ld      de, wItemCostHiScore
    call    CpHiScore
    jr      nc, .sufficientPearls
    pop     de      ; re-balance stack

    ld      a, FX_ERROR
    jp      audio_play_fx

.sufficientPearls
    ; TODO: Confirm unlock, right? We kinda want that...

    ; Deduct pearls from wCurrentPearls!

    ; Sadly there's no call for HiScore subtraction in the HiScore library,
    ;  but this is the only place we'll do it so just sort it out inline.

    ld      hl, wCurrentPearls + HISCORE_LENGTH - 1
    ld      de, wItemCostHiScore + HISCORE_LENGTH - 1

    ld      c, HISCORE_LENGTH
    ;and     a   ; clear carry (already cleared due to `CpHiScore` above)
.subtractLoop
    ld      a, [de]
    res     7, a    ; clear 'empty' bit without touching flags
    ld      b, a
    ld      a, [hl]
    res     7, a    ; clear 'empty' bit without touching flags
    sbc     b
    jr      nc, .noSubCarry
    add     10  ; take 10 from the next digit over
.noSubCarry
    ld      [hld], a
    dec     de
    dec     c
    jr      nz, .subtractLoop

    ; Set leading values to $80
    ; TODO: Find some way to do this in the subtraction loop above as we go
    inc     l       ; get back to first byte of wCurrentPearls
    xor     a       ; probably zero as the most significant digit of pearls, but let's be safe
    lb      bc, $80, HISCORE_LENGTH - 1 ; don't $80 the last digit if zero
.leadingValueLoop
    cp      [hl]
    jr      nz, .hitNonZeroValue
    ld      [hl], b
    inc     hl
    dec     c
    jr      nz, .leadingValueLoop
.hitNonZeroValue

    ; Update pearl display
    ld      hl, vPearlTilemap + 1
    ld      de, wCurrentPearls + HISCORE_LENGTH - MAX_PEARL_DIGITS
    ld      c, MAX_PEARL_DIGITS
    call    PrintScore

    pop     de      ; restore bitmask/menu depth

    ld      a, e        ; recover depth-1
    cp      2
    jr      nz, .normalUnlock
    ; Item purchase, don't update unlocked/enabled flag, but do increment
    ;  the item count and refresh the display
    ld      hl, wFirstStrikeCount - 1
.seekItemLoop
    inc     l
    srl     d
    jr      nc, .seekItemLoop

    ld      b, FX_UNLOCK; queue up sound effect ID
    xor     a           ; clear flags so `daa` works correctly
    ld      a, [hl]
    inc     a
    daa
    jr      nz, .noOverflow
    ld      a, $99      ; player wasted pearls, but at least they're not at zero
                        ; TODO: Block purchases at 99 items
    ld      b, FX_ERROR ; switch sound effect ID due to error
.noOverflow
    ld      [hl], a

    ld      a, b
    call    audio_play_fx

    jp      UpdateItemCounts

.normalUnlock
    add     a           ; add section offset for correct byte pair
    ld      l, a
    ld      h, HIGH(wUnlockedSkills)
    ld      a, [hl]     ; get current unlocked flags
    or      d           ; set unlocked flag
    ld      [hli], a
    ld      a, [hl]
    or      d           ; set enabled flag for newly unlocked item
    ld      [hl], a

    push    hl          ; protect enabled flag pointer
    push    de          ; protect depth in `e`
    ld      a, FX_UNLOCK
    call    audio_play_fx
    pop     de
    pop     hl
    
    ld      a, [hld]    ; re-get enabled flags (faster than push/pop af)
    jp      .updateIconRowAfterChange


; Update the enable/disable/cost state of the selected item, as well as cache 
;  the action to take on A press, and the cost of the item (if applicable)
UpdateSelectionStatus:
    ld      hl, wSelectionDepth
    ld      a, [hli]
    or      a
    jr      nz, .bottomMenu

    ; Top menu, clear state tilemap
    ld      hl, vStateTilemap
    lb      bc, 0, 5
    call    LCDMemsetSmallFromB
    ret

.bottomMenu
    push    hl          ; cache wSelectedIndex pointer

        ; Get unlocked/enabled bitmasks for section
        ; TODO: Is this "get the bitmasks" used enough to make it call?
        ; This is annoying because it trashes HL...
        dec     a           ; ignore 'start' menu depth
        ld      e, a        ; cache wSelectionDepth-1
        add     a           ; add section offset for correct byte pair
        ld      l, a
        ld      h, HIGH(wUnlockedSkills)
        ld      a, [hli]    ; get current unlocked flags
        ld      b, a
        ld      c, [hl]     ; get current enabled flags

    pop     hl      ; recover wSelectedIndex pointer
    ld      a, [hl] ; get wSelectedIndex
    call    GetBitmaskFromA
    ld      a, d
    and     b       ; check if item is unlocked
    jr      z, .itemLocked
    
    inc     l       ; increment to wSelectedItemAction
    ld      b, 0    ; can't destroy `a` right now and no register is zero, sadly
    ld      [hl], b ; set item's action to `toggle`

    ld      hl, vStateTilemap

    bit     1, e ; check if we're on the misc row (without touching `a`)
    jr      z, .notMiscRow
    ; Check if Game Speed
    bit     OPTIONB_RESET_SAVE, d
    jr      nz, .resetSave
    bit     OPTIONB_SPEED, d
    jr      z, .notSpeed
    lb      bc, 0, 4
    call    LCDMemsetSmallFromB
    ret
.notMiscRow
.notSpeed
    and     c       ; check if item is enabled
    ; Setup to show 'Enable', with the registers to be tweaked for 'Disable'
    lb      bc, LOW(vStateTiles.enable / 16), 0
    jr      z, .statusTileIDReady
    ; Tweak registers to show 'Disable'
    inc     b
    inc     b
    inc     b
    ld      c, LOW(vStateTiles.disable / 16) + 3
.statusTileIDReady
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-

    ld      a, b
    ld      [hli], a
    inc     a
    ld      [hli], a
    inc     a
    ld      [hli], a
    ld      [hl], c
    ret
.resetSave
    ; Can't find a clever way to reuse the 'standard' code to draw the checkboxes,
    ;  so just use custom code for the reset save checkbox visuals.

    ; Clear all 4 tiles first
    ld      d, l
    lb      bc, 0, 4
    call    LCDMemsetSmallFromB
    ld      l, d

    ld      a, [wResetSaveCounter]
    or      a
    ret     z
    ld      b, a

:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, LOW(vPearlTile / 16)
.resetSaveTileLoop
    ld      [hli], a
    dec     b
    jr      nz, .resetSaveTileLoop

    ret

.itemLocked
    ; Show cost to unlock
    ; E = depth-1
    ld      a, e
    rla         ; (depth-1) * 8 to locate item cost (carry is 0 because of `and b` above)
    rla
    rla
    ld      e, a
    ld      a, [hli]    ; get wSelectedIndex
    add     e
    ld      e, a        ; this is now the low byte of the item cost in ItemCosts

    ld      a, l
    ld      [hl], a     ; set wSelectedItemAction as 'unlock'

    ld      d, HIGH(ItemCosts)
    ld      a, [de]     ; get cost to unlock item

    ; Convert the cost to BCD values cached in wItemCostHiScore,
    ;  and generate the cost display OAM entries.
    ; 99 bytes, 516/540 (but also leaves us with a BCD'd cost ready to use!)
    ld      hl, wItemCostHiScore + HISCORE_LENGTH - 4
    call    bcd8bit_baa

    ld      c, a    ; cache ones/tens
    ld      a, b
    and     %00000011
    jr      nz, .hasHundreds
    ld      a, $80  ; flag as empty digit
.hasHundreds
    ; Note: won't handle enclosed 0's, do we price things to never have that?
    ld      [hli], a
    ld      a, c
    and     $F0
    jr      nz, .hasTens
    ld      a, $08  ; flag as empty digit (pending swap)
.hasTens
    swap    a
    ld      [hli], a
    ld      a, c
    and     $0F
    jr      nz, .hasOnes    ; TODO: Do we ever NOT have ones?
    ld      a, $80
.hasOnes
    ld      [hl], a

    ld      de, wItemCostHiScore + 4
    ld      hl, vStateTilemap
    ld      c, HISCORE_LENGTH - 4
    call    PrintScore
    
    ret

; Update the name and description for the selected item. Also ensure
;  the correct icons are visible for the section being shown, along
;  with any overlay icons required.
UpdateItemDescription:
    ; Clear old (longer?) name
    ld      hl, vNameTilemap
    lb      bc, 0, 12
    call    LCDMemsetSmallFromB

    ; Called directly to avoid including <CLEAR> at the start
    ;  of a bunch of strings.
    call    TextClear

    ; Initialize text engine
    ld      a, TEXT_WIDTH_TILES * 8 + 1
    lb      bc, LOW(vNameTiles / 16), LOW(vNameTiles.end / 16) - 1
    lb      de, 1, $80
    call    TextInit

    ; Determine the stacked item index
    ld      hl, wSelectionDepth
    ld      a, [hli]
    or      a
    ld      c, a        ; cache depth
    ld      a, [hli]    ; get wSelectedIndex
    jr      nz, .bottomMenu

    ld      hl, GameStartDescription
    push    hl  ; push description to stack for use below
    ld      hl, GameStartName
    jr      .printNameAndDescription

.bottomMenu
    ; Write the selected item's name, and description if the description
    ;  window is visible.
    dec     c   ; ignore top item for offset
    sla     c   ; (depth-1) * 8
    sla     c
    sla     c
    add     c   ; add to selection index offset
    add     a   ; double index to address offset

    push    af  ; cache offset
        ; setup pointer to description and push to stack
        ld      hl, StatusDescriptions
        add     l
        ld      l, a
        ld      a, [hli]
        ld      h, [hl]
        ld      l, a
    pop     af  ; recover item index offset
    push    hl

    ; setup pointer to name
    ld      hl, StatusNames
    add     l
    ld      l, a
    ld      a, [hli]
    ld      h, [hl]
    ld      l, a

.printNameAndDescription
    ; HL currently points to the name, and a pointer to the description is
    ;  sitting on the stack waiting for use.
    ld      a, TEXT_NEW_STR
    call    PrintVWFText
    ld      hl, vNameTilemap
    call    SetPenPosition

    call    PrintVWFChar
    call    DrawVWFChars

    ; Initialize text engine
    ld      a, TEXT_WIDTH_TILES * 8 + 1
    lb      bc, LOW(vDescriptionTiles / 16), LOW(vDescriptionTiles.end / 16) - 1
    lb      de, DESCRIPTION_HEIGHT_TILES, $90
    call    TextInit
    ; Allow description printing to yield the frame for responsive user input
    ; Note: 110 is a rough number which seems to generally prevent overflowing
    ;  VBlank during the VWF writes, though slightly higher numbers would likely
    ;  work well too (and give slightly faster text output).
    ld      a, 110
    ld      [wAutoDelayLY], a

    pop     hl  ; recover pointer to description

    ; Check to see if we actually want to write the description after the
    ;  stack has been balanced and A is safe.
    ld      a, [wDescriptionVisible]
    or      a
    ret     z

    ld      a, TEXT_NEW_STR
    call    PrintVWFText
    ld      hl, vDescriptionTilemap
    call    SetPenPosition

    ; Note: Actual printing occurs in the RoomStatus mainloop

    ret

; Update the displayed count of each item (plus the game speed)
UpdateItemCounts:
    ld      de, wFirstStrikeCount
    ld      hl, vItemCountTilemap

    ld      b, 5
.loop
    ld      a, [de]
    swap    a
    and     $0F
    add     a
    or      a
    jr      z, .leadingZero
    add     $80
.leadingZero
    ld      c, a

:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-

    ld      [hl], c
    inc     l
    ld      a, [de]
    and     $0F
    add     a
    add     $80
    ld      [hli], a

    inc     e
    dec     b
    jr      nz, .loop

    ret