;
; Saved player state for Shock Lobster
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

INCLUDE "hiscore.inc"
INCLUDE "engine.inc"
INCLUDE "defines.asm"

DEF DEBUG_FULL_UNLOCK EQU 0

; This contains all data persisted in SRAM to track player progress
SECTION "Working Player State", WRAM0, ALIGN[8]
wPlayerState:

wUnlockedSkills::   ds 1 ; Bits representing unlocked skills
; 7654 3210
; ||||-|||+- Jet
; ||||-||+-- Shock
; ||||-|+--- Electrify
; ||||-+---- Invigorate
; |||+------ Zap
; ||+------- Discharge
; |+-------- Empower
; +--------- Focus

; Players have the option of disabling skills/upgrades even once they're
;  unlocked to challenge themselves to higher scores with limited options
;  without having to reset the save.
wEnabledSkills::    ds 1 ; Bits represending enabled skills

wUnlockedUpgrades:: ds 1 ; Bits representing unlocked upgrades
; 7654 3210
; ||||-|||+- Amplify (+20% zap damage to debuffed enemies)
; ||||-||+-- Detonate (+30% crit chance on discharge)
; ||||-|+--- High Pressure (Jet height increased and damage doubled)
; ||||-+---- Overcharge (Double charges on crit)
; |||+------ Residual Charge (Electrify ticks can crit)
; ||+------- Expertise (+30% critical chance) -> 60% total
; |+-------- Clarity (Chance for next skill to cost zero energy)
; +--------- Refresh (Electrify +2sec on zap crit up to +6sec max)

wEnabledUpgrades::  ds 1 ; Bits representing enabled upgrades

wUnlockedMisc::     ds 1 ; Bits indicating which misc items must be
                         ;  unlocked (items), or toggled (options)

wEnabledMisc::      ds 1 ; Bits representing enabled options, since
                         ;  items are never truly unlocked.
; 7654 3210
; |||+-++++- <unused>
; ||+------- Palette invert
; |+-------- Music enable/disable
; +--------- Sticky dpad enable/disable

; Item counts (BCD, max count: 99)
wFirstStrikeCount:: ds 1
wBlitzCount::       ds 1
wFinalWordCount::   ds 1
wSecondWindCount::  ds 1

wGameSpeed::        ds 1 ; Placed here to make it easier to display the value in RoomStatus
wSecondWindCache::  ds 1 ; Actually used as a cache, stored here for optimized access

; Hiscore is tracked for each game speed setting
wMaxDamageScore::
.slow               ds HISCORE_LENGTH
.medium             ds HISCORE_LENGTH
.fast               ds HISCORE_LENGTH
wCurrentPearls::    ds HISCORE_LENGTH


SECTION "Saved Player State", SRAM, ALIGN[8]

sSaveID:            ds 4

sPlayerState:
sUnlockedSkills:    ds 1
sEnabledSkills:     ds 1
sUnlockedUpgrades:  ds 1
sEnabledUpgrades:   ds 1

sUnlockedMisc:      ds 1
sEnabledMisc:       ds 1

sFirstStrikeCount:  ds 1
sBlitzCount:        ds 1
sFinalWordCount:    ds 1
sSecondWindCount:   ds 1

sGameSpeed:         ds 1
sSecondWindCache:   ds 1 ; dummy entry to match WRAM stored layout

sMaxDamageScore::
.slow               ds HISCORE_LENGTH
.medium             ds HISCORE_LENGTH
.fast               ds HISCORE_LENGTH
sCurrentPearls:     ds HISCORE_LENGTH

sEnd:

; We overflow into here when copying the default save state
sFillOverflow:      ds HISCORE_LENGTH


SECTION "Save Code", ROM0

InitSRAM::
    ld      hl, sSaveID
.overrideIDPointer::
    ld      de, SaveRef

    xor     a
    ld      [$4000], a  ; set to ram bank 0
    ld      a, $0A
    ld      [$00], a    ; enable SRAM access

    IF DEBUG_FULL_UNLOCK
    jr      .LoadDefaultSave    ; Skip check, load debug save state
    ENDC

    ld      b, 4        ; check all 4 bytes of the SaveID
.loop
    ld      a, [de]
    inc     de
    cp      [hl]
    inc     hl          ; 16bit inc won't affect flags
    jr      nz, .LoadDefaultSave
    dec     b
    jr      nz, .loop

    ; Save exists, copy the player state from SRAM to WRAM
    ld      de, sPlayerState
    ld      hl, wPlayerState
    ld      c, sEnd - sPlayerState
    rst     MemcpySmall

    xor     a
    ld      [$00], a    ; disable SRAM access

    ret
    
.LoadDefaultSave::
    ; Copy default save state directly to WRAM
    ld      de, PlayerNew
    ld      hl, wPlayerState
    ld      c, PlayerNew.end - PlayerNew
    rst     MemcpySmall

    ; Fill wSecondWindCache and initial scores/pearls
    ; 12 bytes of code to replace 33 bytes of ROM data
    ld      b, 5
.scoreFill
    xor     a
    ld      [hli], a
    ld      a, $80
    ld      c, HISCORE_LENGTH - 1
    rst     MemsetSmall
    dec     b
    jr      nz, .scoreFill

    ; If SELECT is held at startup, unlock and enable all skills/upgrades
    ;  so players without SRAM (primarily) can jump right to playing that
    ;  way if they so desire without having to unlock everything every time.
    ldh     a, [hHeldKeys]
    and     PADF_SELECT
    jr      z, .noFullUnlock
    ld      l, LOW(wPlayerState)
    ld      a, $FF  ; full unlock/enable
    ld      [hli], a
    ld      [hli], a
    ld      [hli], a
    ld      [hli], a
.noFullUnlock

    ; Next try to copy the SaveID to SRAM (this will fail if the cartridge lacks
    ;  SRAM, but even if it fails the default save is already in WRAM)
    ld      de, SaveRef
    ld      hl, sSaveID
    ld      c, PlayerNew - SaveRef
    rst     MemcpySmall

    ; Fall through to copy the default state from WRAM to SRAM, and then return
    ; Note: This will include a redundant SRAM enable, but that's fine

; Copy the current player state to SRAM
UpdateSavedGame::
    ld      a, $0A
    ld      [$00], a    ; enable SRAM access

    ; Copy the player state from WRAM to SRAM
    ld      de, wPlayerState
    ld      hl, sPlayerState
    ld      c, sEnd - sPlayerState
    rst     MemcpySmall

    xor     a
    ld      [$00], a    ; disable SRAM access

    ret


SECTION "Initial Player State", ROMX

IF DEBUG_FULL_UNLOCK
SaveRef:
    db $A4, $2E, $19, $F6
PlayerNew:
    db SKILLF_ZAP | SKILLF_JET | SKILLF_SHOCK | SKILLF_DISCHARGE | SKILLF_ELECTRIFY | SKILLF_EMPOWER | SKILLF_INVIGORATE | SKILLF_FOCUS ; Unlocked skills
    db SKILLF_ZAP | SKILLF_JET | SKILLF_SHOCK | SKILLF_DISCHARGE | SKILLF_ELECTRIFY | SKILLF_EMPOWER | SKILLF_INVIGORATE | SKILLF_FOCUS ; Enabled skills
    db UPGRADEF_AMPLIFY | UPGRADEF_DETONATE | UPGRADEF_HIGH_PRESSURE | UPGRADEF_OVERCHARGE | UPGRADEF_RESIDUAL_CHARGE | UPGRADEF_EXPERTISE | UPGRADEF_CLARITY | UPGRADEF_REFRESH ; Unlocked upgrades
    db UPGRADEF_AMPLIFY | UPGRADEF_DETONATE | UPGRADEF_HIGH_PRESSURE | UPGRADEF_OVERCHARGE | UPGRADEF_RESIDUAL_CHARGE | UPGRADEF_EXPERTISE | UPGRADEF_CLARITY | UPGRADEF_REFRESH ; Enabled upgrades
    db OPTIONF_UNLOCK_SPEED | OPTIONF_UNLOCK_MUSIC | OPTIONF_UNLOCK_DPAD | OPTIONF_UNLOCK_RESET_SAVE
    db OPTIONF_MUSIC_ENABLE | OPTIONF_STICKY_DPAD | 2 ; Options
    ;db $10, $10, $10, $10 ; Item counts
    db 0, 0, 0, 0
    db $02 ; game speed
.end

ELSE

; 4 bytes used to identify that valid saved data is present in SRAM
SaveRef:
    db $A4, $2E, $19, $F4
PlayerNew:
    db SKILLF_ZAP | SKILLF_JET | SKILLF_SHOCK | SKILLF_DISCHARGE ; Unlocked skills
    db SKILLF_ZAP | SKILLF_JET | SKILLF_SHOCK | SKILLF_DISCHARGE ; Enabled skills
    db $0 ; Unlocked upgrades
    db $0 ; Enabled upgrades
    db OPTIONF_UNLOCK_SPEED | OPTIONF_UNLOCK_MUSIC | OPTIONF_UNLOCK_DPAD | OPTIONF_UNLOCK_RESET_SAVE
    db OPTIONF_MUSIC_ENABLE | OPTIONF_STICKY_DPAD | 2 ; Options
    db $00, $00, $00, $00 ; Item counts
    db $02 ; game speed

    ; Omit the $00*1, $80*7 repeated 4 times pattern to save ROM space

    ; db $00 ; dummy
    ; db $80, $80, $80, $80, $80, $80, $80, $00 ; max damage score (slow)
    ; db $80, $80, $80, $80, $80, $80, $80, $00 ; max damage score (medium)
    ; db $80, $80, $80, $80, $80, $80, $80, $00 ; max damage score (fast)
    ; db $80, $80, $80, $01, $00, $00, $00, $00 ; current pearls
.end

ENDC
