;
; Post-bootrom entry point for Shock Lobster
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
INCLUDE "res/logo_animation_paths_generated.asm"

SECTION "Header", ROM0[$100]

    ; This is your ROM's entry point
    ; You have 4 bytes of code to do... something
    sub     $11 ; This helps check if we're on CGB more efficiently
    jr      EntryPoint

    ; Make sure to allocate some space for the header, so no important
    ; code gets put there and later overwritten by RGBFIX.
    ; RGBFIX is designed to operate over a zero-filled header, so make
    ; sure to put zeros regardless of the padding value. (This feature
    ; was introduced in RGBDS 0.4.0, but the -MG etc flags were also
    ; introduced in that version.)
    ds      $150 - @, 0

EntryPoint:
    ldh     [hConsoleType], a

Reset::
    di      ; Disable interrupts while we set up

    ld      hl, OAMDMA
    lb      bc, OAMDMA.end - OAMDMA, LOW(hOAMDMA)
.copyOAMDMA
    ld      a, [hli]
    ldh     [c], a
    inc     c
    dec     b
    jr      nz, .copyOAMDMA

    ldh     a, [hConsoleType]
    or      a
    jp      z, .skipLogoEffect

    ; Play with the Nintendo logo a little (using clunky non-interrupt 'vblank')
    DEF LEFT_TILEMAP_OFFSET EQU $010A
    DEF SPLIT_LINE EQU SCRN_Y/2
    DEF END_LINE EQU 22
    DEF WY_START EQU SCRN_Y/2 - 8
    ;DEF SPRITE_START EQU DURATION - 30
    DEF SPRITE_Y_COORD EQU $50
    DEF SPRITE_TILE_ID EQU $19
    DEF WINDOW_CENTER EQU 7 + SCRN_X/2

    DEF LCDC_SHOWN EQU LCDCF_ON | LCDCF_BG8000 | LCDCF_BGON | LCDCF_BG9800 | LCDCF_WINON | LCDCF_WIN9C00 | LCDCF_OBJ8 | LCDCF_OBJON
    DEF LCDC_HIDDEN EQU LCDCF_ON | LCDCF_BG8000 | LCDCF_BGOFF | LCDCF_BG9800 | LCDCF_WINOFF | LCDCF_WIN9C00 | LCDCF_OBJ8 | LCDCF_OBJON

    ; Copy right half of logo to second tilemap for window
    ld      de, _SCRN0 + LEFT_TILEMAP_OFFSET
    ld      hl, _SCRN1 + $0000
    ld      c, 6
    call    LCDMemcpySmall
    ld      e, LOW(_SCRN0 + LEFT_TILEMAP_OFFSET + $20)
    ld      l, LOW(_SCRN1 + $0000 + $20)
    ld      c, 6
    call    LCDMemcpySmall

    ; Position window to overlap right half of logo
    ld      a, WINDOW_CENTER
    ldh     [rWX], a
    ld      a, WY_START
    ldh     [rWY], a

    ; Initialize variables
    xor     a
    ldh     [hSCYCache], a
    ldh     [hFrameCounterLogo], a
    ld      a, SPLIT_LINE+1
    ldh     [hResumeLY], a
    ld      a, LOW(SplitAnimationPath)
    ldh     [hSplitLowByte], a

    ; Enable window/objects safely
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, LCDC_SHOWN
    ldh     [rLCDC], a

    ; Clear right half of first tilemap logo
    ld      hl, _SCRN0 + LEFT_TILEMAP_OFFSET
    lb      bc, 0, 6
    call    LCDMemsetSmallFromB
    ld      l, LOW(_SCRN0 + LEFT_TILEMAP_OFFSET + $20)
    ld      c, 6
    call    LCDMemsetSmallFromB

    ; Position sprite to overlap (R)
    ld      de, SpriteAnimationPath
    ld      hl, wShadowOAM
    ld      a, SPRITE_Y_COORD
    ld      [hli], a
    ld      a, [de]
    ld      [hli], a
    ld      a, SPRITE_TILE_ID
    ld      [hli], a
    ld      a, e
    ldh     [hSpriteLowByte], a

    ; Clear remaining wShadowOAM
    ld      a, c    ; zero from MemcpySmall
    ld      c, OAM_COUNT * sizeof_OAM_ATTRS - 3
    rst     MemsetSmall

    ; Set object palette for effect
    dec     a   ; $FF
    ldh     [rOBP0], a

    ; Animate!
    ld      b, SPLIT_LINE
    ld      h, d
.logoLoop
    ld      a, HIGH(wShadowOAM)
    call    hOAMDMA

.waitVBlankLogo
    ldh     a, [rLY]
    cp      SCRN_Y
    jr      c, .waitVBlankLogo

    ; Clear (R) tile (done after OAM so the replacement sprite is in place),
    ;  and repeated every frame even though it's redundant after the first pass.
    ;ld      a, 0   ; zero from hOAMDMA
    ld      [_SCRN0 + $0110], a

    ldh     a, [hFrameCounterLogo]
    inc     a
    ldh     [hFrameCounterLogo], a
    and     1
    jr      z, .noAnimationTick

    ; Update all animation frames
    dec     b

    ; Update vertical split
    ldh     a, [hSCYCache]
    inc     a
    ldh     [hSCYCache], a

    ; Update horizontal split
    ld      a, b
    cp      SplitAnimationPath.end - SplitAnimationPath + END_LINE - 1
    jr      nc, .noSplitMovement
    ldh     a, [hSplitLowByte]
    inc     a
    ldh     [hSplitLowByte], a
.noSplitMovement

    ; see if the sprite should make sound or be moving
    ld      a, b
    cp      SpriteAnimationPath.end - SpriteAnimationPath + END_LINE
    jr      nz, .noFirstSound
    ld      a, $64
    ldh     [rNR13], a
    ld      a, $87
    ldh     [rNR14], a
.noFirstSound
    jr      nc, .noSpriteMovement
    cp      SpriteAnimationPath.end - SpriteAnimationPath - 2 + END_LINE
    jr      nz, .noSecondSound
    ld      a, $A2
    ldh     [rNR13], a
    ld      a, $87
    ldh     [rNR14], a
.noSecondSound
    ldh     a, [hSpriteLowByte]
    inc     a
    ldh     [hSpriteLowByte], a
.noSpriteMovement

    ldh     a, [hResumeLY]
    inc     a   ; increase gap for next frame
    ldh     [hResumeLY], a

.noAnimationTick

    ; Apply top of vertical split
    ldh     a, [hSCYCache]
    ldh     [rSCY], a
    cpl
    add     WY_START + 1
    ldh     [rWY], a

    ; Apply horizontal split
    ldh     a, [hSplitLowByte]
    ld      l, a
    ld      a, [hl]
    ldh     [rSCX], a
    add     WINDOW_CENTER
    ldh     [rWX], a

    ; Update sprite
    ldh     a, [hSpriteLowByte]
    ld      l, a
    ld      a, [hl]
    ld      [wShadowOAM+1], a

    ; Wait for split line
.waitSplit
    ldh     a, [rLY]
    cp      b
    jr      nz, .waitSplit

    ; Disable background/window safely
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, LCDC_HIDDEN
    ldh     [rLCDC], a

    ; Wait for resume line
    ldh     a, [hResumeLY]
    ld      c, a
.waitResume
    ldh     a, [rLY]
    cp      c
    jr      nz, .waitResume

    ; Enable background/window safely
:   ldh     a, [rSTAT]
    and     STATF_BUSY
    jr      nz, :-
    ld      a, LCDC_SHOWN
    ldh     [rLCDC], a

    ; Move background down
    ld      a, c
    cpl
    add     SPLIT_LINE+1
    ldh     [rSCY], a

    ; Note: No need to move the window because it resume where it left off

    ld      a, b
    cp      END_LINE
    jp      nz, .logoLoop


.skipLogoEffect

    ; Wait for VBlank and turn LCD off
.waitVBlank
    ldh     a, [rLY]
    cp      SCRN_Y
    jr      c, .waitVBlank
    xor     a
    ldh     [rLCDC], a
    ; Goal now: set up the minimum required to turn the LCD on again
    ; A big chunk of it is to make sure the VBlank handler doesn't crash

    ld      sp, wStackBottom

    ; Set Palettes
    xor     a   ; we fade into the credits
    ldh     [rBGP], a
    ldh     [rOBP0], a
    ldh     [rOBP1], a

    ; You will also need to reset your handlers' variables below
    ; I recommend reading through, understanding, and customizing this file
    ; in its entirety anyways. This whole file is the "global" game init,
    ; so it's strongly tied to your own game.
    ; I don't recommend clearing large amounts of RAM, nor to init things
    ; here that can be initialized later.

    ; Reset variables necessary for the VBlank handler to function correctly
    ; But only those for now
    xor     a
    ldh     [hVBlankFlag], a
    ldh     [hOAMHigh], a
    ldh     [hCanSoftReset], a
    ldh     [hVBlankUpdateAudio], a
    dec     a ; ld a, $FF
    ldh     [hHeldKeys], a

    ; Initialize basic raster lookup before interrupts are enabled
    ld      a, LCDCF_ON | LCDCF_BGON
    call    ResetRasterLookup

    ; Select wanted interrupts here
    ; You can also enable them later if you want
    ld      a, STATF_LYC
    ldh     [rSTAT], a

    ld      a, IEF_VBLANK | IEF_LCDC
    ldh     [rIE], a
    xor     a
    ei      ; Only takes effect after the following instruction
    ldh     [rIF], a ; Clears "accumulated" interrupts

    ; Init sound effect driver
    call    audio_init

    ; Init shadow regs
    ; xor a
    ldh     [hSCY], a
    ldh     [hSCX], a


    ; Clear OAM, so it doesn't display garbage
    ; This will get committed to hardware OAM after the end of the first
    ; frame, but the hardware doesn't display it, so that's fine.
    ld      hl, wShadowOAM
    ld      c, NB_SPRITES * 4
    xor     a
    rst     MemsetSmall
    ld      a, h ; ld a, HIGH(wShadowOAM)
    ldh     [hOAMHigh], a

    ; `Intro`'s bank has already been loaded earlier
    jp      Intro

; Since we just leave the STAT interrupt running we need a simple way
;  to reset it to be essentially 'disabled'
; TODO: See if this is used much at all and remove it (or inline it),
;  if the usage is incredibly limited.
ResetRasterLookup::
    ld      hl, wRasterLookup
    ldh     [rLCDC], a  ; turn on the LCD!
    ld      [hli], a
    xor     a
    ld      [hli], a    ; WX
    dec     a
    ld      [hli], a    ; LYC
    ret

SECTION "OAM DMA routine", ROM0

; OAM DMA prevents access to most memory, but never HRAM.
; This routine starts an OAM DMA transfer, then waits for it to complete.
; It gets copied to HRAM and is called there from the VBlank handler
OAMDMA:
    ldh     [rDMA], a
    ld      a, NB_SPRITES
.wait
    dec     a
    jr      nz, .wait
    ret
.end

SECTION "Global vars", HRAM

; 0 if CGB (including DMG mode and GBA), non-zero for other models
hConsoleType:: db

SECTION "OAM DMA", HRAM

hOAMDMA::
    ds OAMDMA.end - OAMDMA


SECTION UNION "Shadow OAM", WRAM0,ALIGN[8]

wShadowOAM::
    ds NB_SPRITES * 4
; Battle mode has 2 player sprites, 2 cursor sprites, up to 6 obstacle sprites
;  and 16 wDamageText entries of 1-3 sprites each. This gives 10 base sprites and
;  between 16 and 48 "damage" sprites. This means we could overflow OAM, but 
;  since we have WRAM to spare I'm just defining some overflow space so that 
;  isn't an issue (though the sprites clearly won't be shown).
wOAMOverflow:
    ds 18 * 4
wOAMIndex::         ; Index of next free entry in OAM for dynamically generated objects
    ds 1
wOAMEndIndex::      ; Index of last enty used in the previous frame
    ds 1

; This ensures that the stack is at the very end of WRAM
SECTION "Stack", WRAM0[$E000 - STACK_SIZE]

    ds STACK_SIZE
wStackBottom:

