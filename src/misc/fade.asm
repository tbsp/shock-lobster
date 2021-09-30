; Dead simple fading to/from white (nothing fancy)

DEF FADE_DELAY  EQU 4   ; How many frames per fade step

SECTION "Fade Variables", WRAM0
wFadeDelay:     ds 1

SECTION "Fade Code", ROM0

; Fade to a solid white screen
FadeOut::
    ld      hl, wFadeDelay
    ld      d, %11100100
    ld      e, %11010000
.loop
    ld      a, FADE_DELAY-1
    ld      [hl], a
    
    ldh     a, [rBGP]
    or      a
    ret     z   ; Done fading when the BG palette is zero

    sla d       ; shift palettes 1 entry over
    sla d
    sla e
    sla e

    ; We don't use palette shadow registers, so wait for VBlank
    ;  and then set the palettes immediately after.
    rst     WaitVBlank

    ld      a, d
    ldh     [rBGP], a
    ldh     [rOBP1], a
    ld      a, e
    ldh     [rOBP0], a

.delayLoop    
    rst     WaitVBlank
    dec     [hl]
    jr      nz, .delayLoop
    jr      .loop

; Fade in from a solid white screen to the standard palette
FadeIn::
    ld      hl, wFadeDelay
    ld      b, %00000000    ; starting palette
    ld      c, %00111001    ; palette entries to rotate in (BGP/OBP1)
    ld      d, %00110100    ; palette entries to rotate in (OBP0)
    ld      e, 3            ; number of fade steps
    
.loop
    ld      a, FADE_DELAY-1
    ld      [hl], a

    sra     c   ; move one palette entry into the current palette
    rr      b
    sra     c
    rr      b

    ldh     a, [rOBP0]
    sra     d
    rra
    sra     d
    rra

    push    af
    push    bc
    rst     WaitVBlank
    pop     bc
    pop     af

    ldh     [rOBP0], a
    ld      a, b
    ldh     [rBGP], a
    ldh     [rOBP1], a

    dec     e
    ret     z

.delayLoop
    push    bc
    rst     WaitVBlank
    pop     bc

    dec     [hl]
    jr      nz, .delayLoop
    jr      .loop