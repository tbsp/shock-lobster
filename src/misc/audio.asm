;
; Sound effects driver for GB
;
; Copyright 2018, 2019 Damian Yerrick
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

; Alterations made by Dave VanEe:
; - New sound effect data for Shock Lobster, replacing Libbet sounds
; - Additional comments regarding the structure of the sfx_table
; - Additional comments detailing the quick/deep/pitch paramters for
;   sound effects
; - Addition of duty and volume envelope defines to streamline effect
;   definition
; - Muting/unmuting of hUGEDriver channels during sound effect playback
; - Change from using Libbet's pitch_table to hUGEDriver's note_table
; - Removal of global.inc import (used for sharing of local HRAM variables)
; - Commented out unused wavebank data

include "hardware.inc/hardware.inc"
;include "src/global.inc"

LOG_SIZEOF_CHANNEL equ 3
LOG_SIZEOF_SFX equ 2
NUM_CHANNELS equ 4

ENVB_DPAR equ 5
ENVB_PITCH equ 4
ENVF_QPAR equ $C0
ENVF_DPAR equ $20
ENVF_PITCH equ $10
ENVF_DURATION equ $0F

section "audio_wram", WRAM0, ALIGN[LOG_SIZEOF_CHANNEL]
audio_channels: ds NUM_CHANNELS << LOG_SIZEOF_CHANNEL
Channel_envseg_cd = 0
Channel_envptr = 1
Channel_envpitch = 3

section "wavebank", ROM0, ALIGN[4]
wavebank:
  ; DVE: Commented out since it's unused
  ;db $FF,$EE,$DD,$CC,$BB,$AA,$99,$88,$77,$66,$55,$44,$33,$22,$11,$00

; Notes on sfx_table:
; - First byte is the channel to use for the effect (0-4)
; - Second byte is currently padding so each table entry is 4 bytes
; - Final word is the address of the effect segments

SECTION "Sound Effect Index", ROM0
; The battle music tries to leave ch0 open as much as possible so we can
;  use it for SFX without clobbering the music. In cases where we want SFX
;  to not clobber each other we resort to ch1 for them, giving up music
;  to ensure the SFX is heard (clarity being the main example).
sfx_table:
  db 0, 0
  dw fx_jet
  db 0, 0
  dw fx_jet_upgraded
  db 0, 0
  dw fx_zap
  db 3, 0
  dw fx_discharge
  db 0, 0
  dw fx_shock
  db 0, 0
  dw fx_empower
  db 3, 0
  dw fx_electrify
  db 0, 0
  dw fx_focus
  db 0, 0
  dw fx_invigorate

  db 1, 0   ; played on channel 1 since it's uncommon and shouldn't overlap skill FX
  dw fx_clarity

  db 0, 0
  dw fx_first_strike
  db 0, 0
  dw fx_blitz
  db 3, 0
  dw fx_final_word
  db 0, 0
  dw fx_second_wind

  db 0, 0
  dw fx_pearl
  db 1, 0   ; played on channel 1 since it's uncommon and shouldn't overlap skill FX
  dw fx_enemy_defeated

  db 0, 0
  dw fx_venture_forth
  db 0, 0
  dw fx_start_battle
  db 0, 0
  dw fx_descr_show
  db 0, 0
  dw fx_descr_hide
  db 0, 0
  dw fx_cursor_move
  db 0, 0
  dw fx_confirm
  db 0, 0
  dw fx_cancel
  db 0, 0
  dw fx_unlock
  db 0, 0
  dw fx_error
  db 0, 0
  dw fx_pause
  db 0, 0
  dw fx_unpause

SECTION "Sound Effect Data", ROM0

sgb_sfx_table:
  ; To be filled in later

; Notes on FX:
; - Each sound effect is comprised of segments
; - There are up to 3 possible bytes for a segment:
;   - The first byte contains the 'quick parameter' as well as flags
;     indicating if deep paramter and/or pitch bytes are present
;   - The second/third bytes are the deep parameter and pitch, in that
;     order, if their flags are set (ENVF_DPAR and ENVF_PITCH)
; - Segment events with values from $F0-$FF are 'special', but all of them
;   just end the effect right now and act like $FF
; - The noise channel has no quick parameter (only a deep parameter and pitch),
;   although the duration is still used to decide when to advance segments
; - Although pulse 1 & 2 channels allow for 6 bits of length in the sound
;   registers, only 4 bits are exposed in this sound effect driver
; - The sweep feature is disabled for channel, making channel 1 & 2
;   essentially identical.

; Pulse 1 channel:
; - Quick parameter: Duty (rNR11)
;   7654 3210
;   ||||-++++- Sound length data
;   |||+------ Pitch flag (ENVF_PITCH)
;   ||+------- Deep parameter flag (ENVF_DPAR)
;   ++-------- Wave pattern duty (12.5%, 25%, 50%, 75%)
; - Deep parameter: Volume envelope (rNR12)
;   7654 3210
;   ||||-|+++- Envelope sweep speed
;   ||||-+---- Envelope direction
;   ++++------ Initial envelope volume
; - Pitch:

; Pulse 2 channel:
; - Quick parameter: Duty (rNR21)
;   7654 3210
;   ||||-++++- Sound length data
;   |||+------ Pitch flag (ENVF_PITCH)
;   ||+------- Deep parameter flag (ENVF_DPAR)
;   ++-------- Wave pattern duty (12.5%, 25%, 50%, 75%)
; - Deep parameter: Volume envelope (rNR22)
;   7654 3210
;   ||||-|+++- Envelope sweep speed
;   ||||-+---- Envelope direction
;   ++++------ Initial envelope volume
; - Pitch:

; Wave channel:
; - Quick parameter: Volume
;   7654 3210
;   ||||-||++- Volume level (0%, 100%, 50%, 25%) (NR32 bits 6-5)
;   ||||-++--- Unused (???)
;   |||+------ Pitch flag (ENVF_PITCH)
;   ||+------- Deep parameter flag (ENVF_DPAR)
; - Deep parameter: New wave data to copy (index, I think?)
; - Pitch: Lower 8 bits of 11 bit frequency (rNR33)

; Noise channel:
; - Quick parameter: Duration only
;   7654 3210
;   ||||-++++- Sound length data
;   ++++------ Unused
; - Deep parameter: Volume envelope sweep + shift clock frequency (rNR42)
;   7654 3210
;   ||||-|+++- Frequency dividing ratio
;   ||||-+---- Width (7bit or 16bit)
;   ++++------ Shift clock frequency
; - Pitch: (rNR43)

; Defines to help with effect creation (added by Dave Van Ee)

; Pulse Channels
DEF DUTY_12_5 EQU $00
DEF DUTY_25   EQU $40
DEF DUTY_50   EQU $80
DEF DUTY_75   EQU $C0

DEF VOLUME_ENVELOPE_DECREASE  EQU $00
DEF VOLUME_ENVELOPE_INCREASE  EQU $08

DEF VOLUME_ENVELOPE_SPEED_0   EQU $00
DEF VOLUME_ENVELOPE_SPEED_1   EQU $01
DEF VOLUME_ENVELOPE_SPEED_2   EQU $02
DEF VOLUME_ENVELOPE_SPEED_3   EQU $03
DEF VOLUME_ENVELOPE_SPEED_4   EQU $04
DEF VOLUME_ENVELOPE_SPEED_5   EQU $05
DEF VOLUME_ENVELOPE_SPEED_6   EQU $06
DEF VOLUME_ENVELOPE_SPEED_7   EQU $07

; Wave Channel

; Noise Channel

; Shock Lobster sounds

; These are sorted by which channel they're used with to make
;  understanding the values easier.

; channel 1&2 (pulse)
fx_jet:
  DEF BASE_PITCH EQU 19
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|0, $59, BASE_PITCH
  db ENVF_PITCH|DUTY_50|0, BASE_PITCH+2
  db ENVF_PITCH|DUTY_50|0, BASE_PITCH+3
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|0, $81, BASE_PITCH+4
  db ENVF_PITCH|DUTY_50|0, BASE_PITCH+5
  db ENVF_PITCH|DUTY_50|0, BASE_PITCH+7
  PURGE BASE_PITCH
  db $FF

fx_jet_upgraded:
  DEF BASE_PITCH EQU 24
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|0, $59, BASE_PITCH
  db ENVF_PITCH|DUTY_50|0, BASE_PITCH+2
  db ENVF_PITCH|DUTY_50|0, BASE_PITCH+3
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|0, $81, BASE_PITCH+4
  db ENVF_PITCH|DUTY_50|0, BASE_PITCH+5
  db ENVF_PITCH|DUTY_50|0, BASE_PITCH+7
  db ENVF_PITCH|DUTY_50|0, BASE_PITCH+9
  db ENVF_PITCH|DUTY_50|0, BASE_PITCH+11
  PURGE BASE_PITCH
  db $FF

fx_zap:
  DEF BASE_PITCH EQU 38
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|3, $78, BASE_PITCH
  db ENVF_PITCH|DUTY_50|2, BASE_PITCH+1
  db ENVF_PITCH|DUTY_50|1, BASE_PITCH-2
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $7B, BASE_PITCH+5
  PURGE BASE_PITCH
  db $FF

fx_shock:
  DEF BASE_PITCH EQU 80
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|1, $59, BASE_PITCH
  db ENVF_PITCH|DUTY_50|1, BASE_PITCH-10
  db ENVF_PITCH|DUTY_50|1, BASE_PITCH-6
  db ENVF_PITCH|DUTY_50|1, BASE_PITCH-16
  db ENVF_PITCH|DUTY_50|1, BASE_PITCH-12
  db ENVF_PITCH|DUTY_50|1, BASE_PITCH-22
  PURGE BASE_PITCH
  db $FF

fx_empower:
  DEF BASE_PITCH EQU 20
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|3, $59, BASE_PITCH
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+10
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+15
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+20
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+15
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+20
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+25
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+20
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+25
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+30
  PURGE BASE_PITCH
  db $FF

fx_focus:
  DEF BASE_PITCH EQU 40
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|1, $F1, BASE_PITCH
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|1, $F1, BASE_PITCH+9
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|1, $F1, BASE_PITCH-4
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|1, $F1, BASE_PITCH-5
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|1, $F1, BASE_PITCH-5+9
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|1, $F1, BASE_PITCH-5-4
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|1, $F1, BASE_PITCH+7
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|1, $F1, BASE_PITCH+7+9
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|1, $F1, BASE_PITCH+7-4
  PURGE BASE_PITCH
  db $FF

fx_invigorate:
  DEF BASE_PITCH EQU 50
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $E3, BASE_PITCH
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+2
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+4
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+2
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+4
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+6
  PURGE BASE_PITCH
  db $FF

fx_clarity:
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|$0, $F1, 45
  db ENVF_PITCH|DUTY_50|$0, 49
  db ENVF_PITCH|DUTY_50|$2, 60
  db ENVF_PITCH|DUTY_50|$3, 55
  db ENVF_PITCH|DUTY_50|$3, 55
  db $FF

fx_first_strike:
  DEF BASE_PITCH EQU 25
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|3, $F1, BASE_PITCH
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|3, $F1, BASE_PITCH+9
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|3, $F1, BASE_PITCH+4
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|3, $F1, BASE_PITCH+3
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|3, $F1, BASE_PITCH+3+9
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|3, $F1, BASE_PITCH+3+4
  PURGE BASE_PITCH
  db $FF

fx_blitz:
  DEF BASE_PITCH EQU 25
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|2, $F1, BASE_PITCH
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|2, $F1, BASE_PITCH+9
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|2, $F1, BASE_PITCH+4
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|2, $F1, BASE_PITCH-3
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|2, $F1, BASE_PITCH-3+9
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|2, $F1, BASE_PITCH-3+4
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|2, $F1, BASE_PITCH+6
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|2, $F1, BASE_PITCH+6+9
  db ENVF_DPAR|ENVF_PITCH|DUTY_25|2, $F1, BASE_PITCH+6+4
  PURGE BASE_PITCH
  db $FF

fx_second_wind:
  DEF BASE_PITCH EQU 27
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|5, $F9, BASE_PITCH
  db ENVF_DPAR|DUTY_50|1, 0
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|5, $F9, BASE_PITCH
  db ENVF_DPAR|DUTY_50|1, 0
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|3, $F9, BASE_PITCH+5
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+7
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+10
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+14
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+19
  db ENVF_PITCH|DUTY_50|2, BASE_PITCH+1
  db ENVF_PITCH|DUTY_50|2, BASE_PITCH+5
  db ENVF_PITCH|DUTY_50|2, BASE_PITCH+11
  db ENVF_PITCH|DUTY_50|2, BASE_PITCH+19
  db ENVF_PITCH|DUTY_50|2, BASE_PITCH+27
  PURGE BASE_PITCH
  db $FF

fx_pearl:
  DEF BASE_PITCH EQU 35
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $71, BASE_PITCH
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|8, $71, BASE_PITCH+5
  PURGE BASE_PITCH
  db $FF

fx_enemy_defeated:
  DEF BASE_PITCH EQU 15
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|5, $F9, BASE_PITCH
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+4
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+8
  db ENVF_PITCH|DUTY_50|5, BASE_PITCH+2
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+6
  db ENVF_PITCH|DUTY_50|3, BASE_PITCH+10
  db ENVF_PITCH|DUTY_50|5, BASE_PITCH+4
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+8
  db ENVF_PITCH|DUTY_50|5, BASE_PITCH+12
  PURGE BASE_PITCH
  db $FF

fx_venture_forth:
  DEF BASE_PITCH EQU 20
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|6, $59, BASE_PITCH
  db ENVF_PITCH|DUTY_50|6, BASE_PITCH+5
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+0
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+2
  db ENVF_PITCH|DUTY_50|10, BASE_PITCH+10
  PURGE BASE_PITCH
  db $FF

fx_start_battle:
  DEF BASE_PITCH EQU 25
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|6, $59, BASE_PITCH
  db ENVF_PITCH|DUTY_50|6, BASE_PITCH+5
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+0
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH+2
  db ENVF_PITCH|DUTY_50|10, BASE_PITCH+10
  PURGE BASE_PITCH
  db $FF

fx_descr_show:
  DEF BASE_PITCH EQU 33
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C1, BASE_PITCH
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C1, BASE_PITCH+3
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C1, BASE_PITCH+4
  PURGE BASE_PITCH
  db $FF

fx_descr_hide:
  DEF BASE_PITCH EQU 33
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C1, BASE_PITCH+4
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C1, BASE_PITCH+3
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C1, BASE_PITCH
  PURGE BASE_PITCH
  db $FF

fx_cursor_move:
  DEF BASE_PITCH EQU 33
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C1, BASE_PITCH
  PURGE BASE_PITCH
  db $FF

fx_confirm:
  DEF BASE_PITCH EQU 30
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $A1, BASE_PITCH
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|8, $A1, BASE_PITCH+5
  PURGE BASE_PITCH
  db $FF

fx_cancel:
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C1, 22
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C1, 24
  db $FF

fx_unlock:
  DEF BASE_PITCH EQU 30
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $F1, BASE_PITCH
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $F1, BASE_PITCH-10
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $F1, BASE_PITCH+9
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $F1, BASE_PITCH-7
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $F1, BASE_PITCH+12
  PURGE BASE_PITCH
  db $FF

fx_error:
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C1, 30
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C1, 25
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|8, $C1, 20
  db $FF

fx_pause:
  DEF BASE_PITCH EQU 40
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C3, BASE_PITCH
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH-5
  db ENVF_PITCH|DUTY_50|6, BASE_PITCH+2
  PURGE BASE_PITCH
  db $FF

fx_unpause:
  DEF BASE_PITCH EQU 40
  db ENVF_DPAR|ENVF_PITCH|DUTY_50|4, $C3, BASE_PITCH
  db ENVF_PITCH|DUTY_50|4, BASE_PITCH-5
  db ENVF_PITCH|DUTY_50|6, BASE_PITCH-7
  PURGE BASE_PITCH
  db $FF

; channel 3 (noise)
fx_electrify:
  db ENVF_DPAR|ENVF_PITCH|3, $94, $53
  db ENVF_PITCH|6, $59
  db ENVF_DPAR|ENVF_PITCH|2, $A6, $58
  db ENVF_DPAR|ENVF_PITCH|4, $93, $2A
  db ENVF_DPAR|ENVF_PITCH|2, $82, $58
  db ENVF_DPAR|ENVF_PITCH|1, $71, $38
  db ENVF_PITCH|7, $64
  db ENVF_PITCH|5, $57
  db $FF

fx_final_word:
  db ENVF_DPAR|ENVF_PITCH|$04, $F2, $81
  db ENVF_DPAR|ENVF_PITCH|$0F, $F2, $91
  ; fall through to discharge sound, so sneaky
fx_discharge:
  db ENVF_DPAR|ENVF_PITCH|$06, $F2, $71
  db ENVF_DPAR|ENVF_PITCH|$04, $F2, $81
  db ENVF_DPAR|ENVF_PITCH|$0F, $F2, $91
  db $FF



section "audioengine", ROM0

; Starting sequences ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

audio_init::
  ; Init PSG
  ld a,$80
  ldh [rNR52],a  ; bring audio out of reset
  ld a,$FF
  ldh [rNR51],a  ; set panning
  ld a,$77
  ldh [rNR50],a
  ld a,$08
  ldh [rNR10],a  ; disable sweep

  ; Silence all channels
  xor a
  ldh [rNR12],a
  ldh [rNR22],a
  ldh [rNR32],a
  ldh [rNR42],a
  ld a,$80
  ldh [rNR14],a
  ldh [rNR24],a
  ldh [rNR34],a
  ldh [rNR44],a

  ; Clear sound effect state
  xor a
  ld hl,audio_channels
  ld c,NUM_CHANNELS << LOG_SIZEOF_CHANNEL
  jp MemsetSmall

;;
; Plays sound effect A.
; Trashes ABCHLE
audio_play_fx::
  ld h,high(sfx_table >> 2)
  add low(sfx_table >> 2)
  jr nc,.nohlwrap
    inc h
  .nohlwrap:
  ld l,a
  add hl,hl
  add hl,hl
  ld a,[hl+]  ; channel ID
  inc l

  ; Mute channel for hUGEDriver music playback
  ld b, a     ; channel to update
  ld c, 1     ; 1=mute channel
  push af     ; protect A (channel)
  push hl     ; protect HL (pointer to effect)
  call hUGE_mute_channel ; also trashes E
  pop hl
  pop af

  ld c,[hl]   ; ptr lo
  inc l
  ld b,[hl]   ; ptr hi

  ; Get pointer to channel
  rept LOG_SIZEOF_CHANNEL
    add a
  endr
  add low(audio_channels+Channel_envseg_cd)
  ld l,a
  ld a,0
  adc high(audio_channels)
  ld h,a

  xor a  ; begin effect immediately
  ld [hl+],a
  ld a,c
  ld [hl+],a
  ld [hl],b
  ret

; Sequence reading ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

audio_update::
  ld a,0
  call audio_update_ch_a
  ld a,1
  call audio_update_ch_a
  ld a,2
  call audio_update_ch_a
  ld a,3

audio_update_ch_a:
  ; Get pointer to current position in effect
  ld l,a
  ld h,0
  rept LOG_SIZEOF_CHANNEL
    add hl,hl
  endr
  ld de,audio_channels+Channel_envseg_cd
  add hl,de

  ; Each segment has a duration in frames.  If this segment's
  ; duration has not expired, do nothing.
  ld a,[hl]
  or a
  jr z,.read_next_segment
    dec [hl]
    ret
  .read_next_segment:

  inc l
  ld e,[hl]
  inc l
  ld a,[hl-]
  ld d,a
  or e
  ret z  ; address $0000: no playback

  ; HL points at low byte of effect position
  ; DE = effect pointer
  ld a,[de]
  cp $F0
  jr c,.not_special
    ; Currently all specials mean stop playback
    xor a
    ld [hl+],a
    ld [hl+],a  ; Clear pointer to sound sequence
    ld d,a

    ; Unmute channel for hUGEDriver
    ; To do so we need the channel ID, which would normally be calculated
    ;  in .call_updater. Instead we duplicate that code here, unmute the
    ;  channel, and jump past it to continue.

    ; Seek to the appropriate audio channel's updater
    ld a,l
    sub low(audio_channels)
    ; rgbasm's nightmare of a parser can't subtract.
    ; Parallels to lack of "sub hl,*"?
    rept LOG_SIZEOF_CHANNEL + (-1)
      rra
    endr
    and $06

    push af ; preserve A for .call_updater_late_entry
    rrca
    ld b, a ; channel to update
    ld c, 0 ; 0=unmute channel
    call hUGE_mute_channel
    pop af
    
    ld bc,($C0 | ENVF_DPAR) << 8

    jr .call_updater_late_entry
  .not_special:
  inc de

  ; Save this envelope segment's duration
  ld b,a
  and ENVF_DURATION
  dec l
  ld [hl+],a

  ; Is there a deep parameter?
  bit ENVB_DPAR,b
  jr z,.nodeep
    ld a,[de]
    inc de
    ld c,a
  .nodeep:

  bit ENVB_PITCH,b
  jr z,.nopitch
    ld a,[de]
    inc de
    inc l
    inc l
    ld [hl-],a
    dec l
  .nopitch:

  ; Write back envelope position
  ld [hl],e
  inc l
  ld [hl],d
  inc l
  ld d,[hl]
  ; Regmap:
  ; B: quick parameter and flags
  ; C: deep parameter valid if BIT 5, B
  ; D: pitch, which changed if BIT 4, B

.call_updater:
  ; Seek to the appropriate audio channel's updater
  ld a,l
  sub low(audio_channels)
  ; rgbasm's nightmare of a parser can't subtract.
  ; Parallels to lack of "sub hl,*"?
  rept LOG_SIZEOF_CHANNEL + (-1)
    rra
  endr
  and $06

.call_updater_late_entry:
  ld hl,channel_writing_jumptable
  add l
  jr nc,.nohlwrap
    inc h
  .nohlwrap:
  ld l,a
  jp hl

; Channel hardware updaters ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

update_noise:
  ; Noise has no quick parameter.  Change pitch and timbre first
  ld a,d
  ldh [rNR43],a
  ; If no deep parameter, return quickly
  bit ENVB_DPAR,b
  ret z

  ; New deep parameter
  ld a,c
  ldh [rNR42],a
  ; See note below about turning off the DAC
  ld a,8
  cp c
  jr c,.no_vol8fix
    ldh [rNR42],a
  .no_vol8fix:
  ld a,$80
  ldh [rNR44],a
  ret

update_pulse1:
  ld hl,rNR11
  jr update_pulse_hl
update_pulse2:
  ld hl,rNR21
update_pulse_hl:
  ld [hl],b  ; Quick parameter is duty
  inc l
  bit ENVB_DPAR,b
  jr z,.no_new_volume
    ; Deep parameter is volume envelope
    ; APU turns off the DAC if the starting volume (bit 7-4) is 0
    ; and increase mode (bit 3) is off, which corresponds to NRx2
    ; values $00-$07.  Turning off the DAC makes a clicking sound as
    ; the level gradually returns to 7.5 as the current leaks out.
    ; But LIJI32 in gbdev Discord pointed out that if the DAC is off
    ; for only a few microseconds, it doesn't have time to leak out
    ; appreciably.
    ld a,8
    cp c
    ld [hl],c
    jr c,.no_vol8fix
      ld [hl],a
    .no_vol8fix:
  .no_new_volume:
  inc l
set_pitch_hl_to_d:
  ; Write pitch
  ld a,d
  add a
  ld de,note_table
  add e
  ld e,a
  jr nc,.nodewrap
    inc d
  .nodewrap:
  ld a,[de]
  inc de
  ld [hl+],a
  ld a,[de]
  bit ENVB_DPAR,b
  jr z,.no_restart_note
    set 7,a
  .no_restart_note:
  ld [hl+],a
  ret

;;
; @param B quick parameter and flags
; @param C deep parameter if valid
; @param D current pitch
channel_writing_jumptable:
  jr update_pulse1
  jr update_pulse2
  jr update_wave
  jr update_noise

update_wave:
  ; First update volume (quick parameter)
  ld a,b
  add $40
  rra
  ldh [rNR32],a

  ; Update wave 9
  bit ENVB_DPAR,b
  jr z,.no_new_wave

  ; Get address of wave C
  ld h,high(wavebank >> 4)
  ld a,low(wavebank >> 4)
  add c
  ld l,a
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl

  ; Copy wave
  xor a
  ldh [rNR30],a  ; give CPU access to waveram
WAVEPTR set _AUD3WAVERAM
  rept 16
    ld a,[hl+]
    ldh [WAVEPTR],a
WAVEPTR set WAVEPTR+1
  endr
  ld a,$80
  ldh [rNR30],a  ; give APU access to waveram

.no_new_wave:
  ld hl,rNR33
  jr set_pitch_hl_to_d