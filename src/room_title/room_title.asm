;
; Credits/title screen for Shock Lobster
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
INCLUDE "sound_fx.inc"

DEF CREDITS_WIDTH_TILES EQU 17
DEF CREDITS_HEIGHT_TILES EQU 13
DEF MENU_HEIGHT_TILES EQU 3
DEF CURSOR_BASE_Y   EQU 105
DEF CURSOR_X        EQU 47

DEF LCDC_SHOWN      EQU LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINOFF | LCDCF_WIN9800

DEF vCreditsTilemap EQU $9822
DEF vCreditsTilemap2 EQU $99E2
DEF vTitleTilemap   EQU $9A41
DEF vPearlTilemap   EQU $9B66
DEF vMenuTilemap    EQU $9B87

;******************************************************************************
;**                                  Variables                               **
;******************************************************************************

SECTION UNION "8000 tiles", VRAM[$8000]
vSeaweedTiles: ds 16 * 2

SECTION UNION "8800 tiles", VRAM[$8800]
vCreditsTiles:  ds 16 * 16 * 8
.end

SECTION UNION "9000 tiles", VRAM[$9000]

vTitleTiles: ds 16 * (16 * 6 + 5)
vMenuTiles:  ds 16 * 6
.end
vCreditsTiles2: ds 16 * 21
.end

SECTION "Seaweed Animation Pointers", WRAM0, ALIGN[2]
wSeaweedAnimationPointers: ds 4

;******************************************************************************
;**                                    Data                                  **
;*****************************************************************************

SECTION "Credits Data", ROM0
CreditsText:
    db "Shock Lobster (C) 2021 Dave VanEe<NEWLINE><NEWLINE><NEWLINE>"
    db "Special thanks to Calindro, SuperDisk, PinoBatch, and ISSOtm<NEWLINE><NEWLINE>"
    db "Music used:<NEWLINE>"
    db "\"Serious Ping Pong Matches\" and<NEWLINE>\"Tape It Together\" by DeerTears<NEWLINE>"
    db "\"FridgeMusic\" by Tomas Danko<NEWLINE>"
    db "\"Darkstone Remix\" by Tronimal<NEWLINE><NEWLINE>"
    db "Monster graphics by LuckyCassette<END>"

SECTION "Credits Data 2", ROM0
; Written by itself since we can out of tile space in the $8800 block
CreditsText2:
    db "MinimalPixel font by Mounir Tohami<END>"

SECTION "Title Data", ROMX
SeaweedTiles:
    INCBIN "res/gfx/seaweed.2bpp"
.end

TitleTiles:
    INCBIN "res/gfx/title_map.2bpp.pb16"
.end

TitleTilemap:
    INCBIN "res/gfx/title_map.tilemap"
.end

MenuText:
    db "Press Start<END>"

;******************************************************************************
;**                                    Code                                  **
;*****************************************************************************

SECTION "Title Code", ROM0

InitTitle::

    ; Clear tilemap contents lingering from bootrom
    ld      hl, $9800
    ld      bc, $400
    xor     a
    call    LCDMemset

    ld      hl, wShadowOAM
    ld      c, $A0
    rst     MemsetSmall

    ; Clear raster table for maximum VRAM access time during heavy writes to follow
    ld      a, LCDCF_ON
    call    ResetRasterLookup

    ; Write credits text
    ld      a, CREDITS_WIDTH_TILES * 8 + 1
    lb      bc, LOW(vCreditsTiles / 16), LOW(vCreditsTiles.end / 16) - 1
    lb      de, CREDITS_HEIGHT_TILES, $80
    call    TextInit

    ld      hl, CreditsText
    ld      a, TEXT_NEW_STR
    call    PrintVWFText
    ld      hl, vCreditsTilemap
    call    SetPenPosition

    call    PrintVWFChar
    call    DrawVWFChars

    ; Write font credit line (ran out of tile space in the first block)
    ld      a, CREDITS_WIDTH_TILES * 8 + 1
    lb      bc, LOW(vCreditsTiles2 / 16), LOW(vCreditsTiles2.end / 16) - 1
    lb      de, 1, $90
    call    TextInit

    ld      hl, CreditsText2
    ld      a, TEXT_NEW_STR
    call    PrintVWFText
    ld      hl, vCreditsTilemap2
    call    SetPenPosition

    call    PrintVWFChar
    call    DrawVWFChars


    ld      de, SeaweedTiles
    ld      hl, vSeaweedTiles
    ld      c, SeaweedTiles.end - SeaweedTiles
    call    LCDMemcpySmall

    ASSERT(SeaweedTiles.end == TitleTiles)
    ; Unpack title tiles to VRAM
    ;ld      de, TitleTiles
    ld      hl, vTitleTiles
    INCLUDE "res/gfx/title_map.2bpp.pb16.size"
	ld      b, NB_PB16_BLOCKS
	PURGE NB_PB16_BLOCKS
    call    pb16_unpack_block_lcd

    ; Copy title tilemap
    ld      de, TitleTilemap
    ld      hl, vTitleTilemap
    ld      b, 7
:   ld      c, 18
    call    LCDMemcpySmall
    push    de
    ld      de, SCRN_VX_B - 18
    add     hl, de
    pop     de
    dec     b
    jr      nz, :-

    ; Initialize text engine
    ld      a, TEXT_WIDTH_TILES * 8 + 1
    lb      bc, LOW(vMenuTiles / 16), LOW(vMenuTiles.end / 16) - 1
    lb      de, MENU_HEIGHT_TILES, $90
    call    TextInit

    ; Write menu text
    ld      hl, MenuText
    ld      a, TEXT_NEW_STR
    call    PrintVWFText
    ld      hl, vMenuTilemap
    call    SetPenPosition

    call    PrintVWFChar
    call    DrawVWFChars

    ; Init music only if starting fresh or returning from battle
    ldh     a, [hLastMode]
    cp      MODE_STATUS
    ASSERT(MODE_STATUS > MODE_BATTLE && MODE_STATUS > MODE_TITLE)
    jr      nc, .noMusicInit
    ld      hl, song_title
    call    hUGE_init
.noMusicInit

    ; Start updating audio
    ldh     [hVBlankUpdateAudio], a

    ; Initial PPU state
    xor     a
    ldh     [hSCX], a
    ldh     [hSCY], a
    dec     a    ; ensure all effects initialize the first frame
    ldh     [hFrameCounter], a

    ; For credits we don't use the raster effect
    ld      a, LCDC_SHOWN
    call    ResetRasterLookup

    ldh     a, [hGameMode]
    cp      MODE_TITLE
    call    z, InitTitleDirect

    call    FadeIn

RoomTitle::
    call    rand        ; use time spent on the credits/title to further randomize

    ld      a, HIGH(wShadowOAM)
    ldh     [hOAMHigh], a

    rst     WaitVBlank

    ldh     a, [hGameMode]
    cp      MODE_TITLE
    jr      z, .titleHandling

    ; Credits handling
    ldh     a, [hPressedKeys]
    and     PADF_A | PADF_START
    jr      z, RoomTitle

    call    FadeOut
    call    InitTitleDirect
    call    FadeIn

    ; Set mode to title
    ld      a, MODE_CREDITS
    ldh     [hLastMode], a
    ASSERT(MODE_CREDITS + 1 == MODE_TITLE)
    inc     a
    ldh     [hGameMode], a
    jr      RoomTitle

.titleHandling
    call    UpdateAnimation

    ldh     a, [hPressedKeys]
    and     PADF_A | PADF_START
    jr      z, RoomTitle

.confirm
    ld      a, FX_VENTURE_FORTH
    call    audio_play_fx

    ld      a, MODE_TITLE
    ldh     [hLastMode], a
    ld      a, MODE_STATUS
    ld      [hGameMode], a
    jp      FadeOut
    ; Return to the mode handler

; Special initialization when initializating directly into title mode
;  (bypassing the credits, as from the status screen)
InitTitleDirect:
    ; Scroll to title background
    ld      a, 128
    ldh     [hSCY], a

    ; Randomize seaweed pointer start positions
    ld      de, randstate
    ld      hl, wSeaweedAnimationPointers
    ld      b, 4
.seedRandLoop
    ld      a, [de]
    inc     de
    and     64-1
    ld      [hli], a
    dec     b
    jr      nz, .seedRandLoop

    ; Setup raster effect
    xor     a
    ldh     [hCurveLowByte0], a
    ldh     [hCurveLowByte1], a

    ; Ensure the curves/seaweed are visible during the fade in
    call    UpdateAnimation

    ld      a, HIGH(wShadowOAM)
    ldh     [hOAMHigh], a

    ; Wait until shadow register is applied and OAM DMA has occurred
    rst     WaitVBlank

    ret

UpdateAnimation:
    DEF CURVE_START_LY  EQU $0F
    DEF CURVE_LINES     EQU 56

    ldh     a, [hFrameCounter]
    inc     a
    ldh     [hFrameCounter], a
    and     1
    ret     nz

    ld      hl, wRasterLookup + 2
    ld      d, HIGH(TitleCurve0)

    ldh     a, [hCurveLowByte0]
    ld      e, a
    inc     a                   ; increment low byte for next frame
    and     64-1                ; wrap low byte to 64 byte table
    ldh     [hCurveLowByte0], a

    and     1                   ; update secondary curve half as often

    ldh     a, [hCurveLowByte1]
    ld      c, a
    jr      nz, .skipSecondaryCurveIncrement
    inc     a                   ; increment low byte for next frame
    and     32-1                ; wrap low byte to 32 byte table
    ldh     [hCurveLowByte1], a
.skipSecondaryCurveIncrement

    ld      b, CURVE_START_LY
.fillRaster
    ld      [hl], b     ; LY
    inc     l
    inc     b
    ld      a, [de]
    ld      [hl], a     ; SCX (from primary curve)
    push    bc          ; protect LY
    ld      b, HIGH(TitleCurve1)
    ld      a, [bc]
    add     [hl]        ; add secondary curve offset
    ld      [hli], a    ; store combined offset
    pop     bc          ; recover LY

    inc     e
    ld      a, e
    and     64-1        ; wrap low byte to 64 byte table as we go as well
    ld      e, a

    inc     c
    ld      a, c
    and     32-1        ; wrap low byte to 32 byte table as we go as well
    ld      c, a

    xor     a
    ld      [hli], a    ; WX
    ld      a, LCDC_SHOWN
    ld      [hli], a    ; LCDC

    ld      a, l
    cp      4 * CURVE_LINES + 2 ; 4 bytes per entry, plus half first entry
    jr      nz, .fillRaster

    ; Zero final entry so trailing text is static
    ld      [hl], b
    inc     l
    xor     a
    ld      [hli], a
    ld      [hli], a
    ld      a, LCDC_SHOWN
    ld      [hli], a

    ; Ensure next entry doesn't fire
    ld      a, $FF
    ld      [hli], a

    ; Seaweed updates every 4th frame
    ldh     a, [hFrameCounter]
    and     3
    ret     nz

    ; Update seaweed sprites
    ld      de, wSeaweedAnimationPointers
    ld      hl, wShadowOAM
.columnLoop
    ; Calculate base X coord from pointer index
    ld      a, e
    and     3
    add     a   ; index*32
    swap    a
    add     $24
    ld      c, a

    ld      a, [de]
    push    hl  ; protect shadow OAM pointer
        ld      l, a
        inc     a
        and     64-1        ; wrap to 64 entries
        ld      [de], a
        ;and     32-1        ; wrap to 32 entries
        ldh     [hSeaweedLowByte], a    ; cache for use below
        inc     de
        ld      h, HIGH(TitleCurve0)
        ld      a, [hl]     ; get X coordinate offset from curve
    pop     hl

    add     c           ; add X offset to X base coordinate
    ld      c, a

    push    de  ; protect animation pointers pointer
        ld      b, $10
        ld      d, 9    ; each column is 9 sprites tall

        ld      a, e    ; use the LSBit of the pointers pointer to alternate
        and     1       ;  priority for columns, which is set by bit 7
        rra
        rra
        ldh     [hSeaweedAttrs], a

    .segmentLoop
        ld      [hl], b
        inc     l
        ld      a, b
        add     16
        ld      b, a
        push    de
            ldh     a, [hSeaweedLowByte]
            ld      e, a
            ld      d, HIGH(TitleCurve0)
            ld      a, [de]
            add     c   ; add to column X coordinate
            ld      [hli], a
            ld      a, e
            add     6   ; advance quickly for more variety
            ;and     32-1
            and     64-1
            ldh     [hSeaweedLowByte], a
        pop     de
        ASSERT(LOW(vSeaweedTiles / 16) == 0)
        xor     a
        ld      [hli], a
        ldh     a, [hSeaweedAttrs]
        ld      [hli], a
        dec     d
        jr      nz, .segmentLoop
    pop de

    ld      a, e
    cp      LOW(wSeaweedAnimationPointers) + 4
    jr      nz, .columnLoop

    ret

