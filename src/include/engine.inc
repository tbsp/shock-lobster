;******************************************************************************
;**                                   Defines                                **
;******************************************************************************

IF !DEF(ENGINE_INC)
ENGINE_INC      SET 1

; Engine modes
RSRESET
MODE_CREDITS    RB 1
MODE_TITLE      RB 1
MODE_BATTLE     RB 1
MODE_STATUS     RB 1

; Skill/upgrade flags

DEF SKILLF_JET          EQU %00000001
DEF SKILLF_ZAP          EQU %00000010
DEF SKILLF_SHOCK        EQU %00000100
DEF SKILLF_DISCHARGE    EQU %00001000
DEF SKILLF_ELECTRIFY    EQU %00010000
DEF SKILLF_EMPOWER      EQU %00100000
DEF SKILLF_INVIGORATE   EQU %01000000
DEF SKILLF_FOCUS        EQU %10000000

DEF UPGRADEF_AMPLIFY            EQU %00000001
DEF UPGRADEF_DETONATE           EQU %00000010
DEF UPGRADEF_HIGH_PRESSURE      EQU %00000100
DEF UPGRADEF_OVERCHARGE         EQU %00001000
DEF UPGRADEF_RESIDUAL_CHARGE    EQU %00010000
DEF UPGRADEF_EXPERTISE          EQU %00100000
DEF UPGRADEF_CLARITY            EQU %01000000
DEF UPGRADEF_REFRESH            EQU %10000000

; Item flags (only used for game over display)
DEF ITEMF_FIRST_STRIKE  EQU %00000001
DEF ITEMF_BLITZ         EQU %00000010
DEF ITEMF_FINAL_WORD    EQU %00000100
DEF ITEMF_SECOND_WIND   EQU %00001000

; Item bit (used to set items used)
DEF ITEMB_FIRST_STRIKE  EQU 0
DEF ITEMB_BLITZ         EQU 1
DEF ITEMB_FINAL_WORD    EQU 2
DEF ITEMB_SECOND_WIND   EQU 3

; These aren't ever locked, but are mainly used to indicate which of the
;  misc items is a toggle (vs a cost, like items)
DEF OPTIONF_UNLOCK_SPEED        EQU %00010000
DEF OPTIONF_UNLOCK_MUSIC        EQU %00100000
DEF OPTIONF_UNLOCK_DPAD         EQU %01000000
DEF OPTIONF_UNLOCK_RESET_SAVE   EQU %10000000

; Used to bit test for options
DEF OPTIONB_SPEED               EQU 4
DEF OPTIONB_MUSIC               EQU 5
DEF OPTIONB_RESET_SAVE          EQU 7

DEF OPTIONF_MUSIC_ENABLE        EQU %00100000
DEF OPTIONF_STICKY_DPAD         EQU %01000000
DEF OPTIONF_RESET_SAVE          EQU %10000000

;******************************************************************************
    ENDC ; ENGINE_INC
;******************************************************************************
