include "include/hUGE.inc"

SECTION "Song Game Over", ROMX

song_game_over::
db 6
dw order_cnt
dw order1, order2, order3, order4
dw duty_instruments, wave_instruments, noise_instruments
dw routines
dw waves

order_cnt: db 6
order1: dw P0c,P30,P70
order2: dw P1,P31,P31
order3: dw P0c,P0c,P0c
order4: dw P0c,P0c,P0c

P1:
 dn C_5,1,$E89
 dn ___,0,$000
 dn E_5,1,$E8A
 dn ___,0,$000
 dn B_5,1,$E8B
 dn ___,0,$000
 dn C_6,1,$E8C
 dn ___,0,$000
 dn B_5,1,$E8D
 dn ___,0,$000
 dn G_5,1,$E8C
 dn ___,0,$000
 dn C_5,1,$E8B
 dn ___,0,$000
 dn E_5,1,$E8A
 dn ___,0,$000
 dn B_4,1,$E88
 dn ___,0,$000
 dn D_5,1,$E87
 dn ___,0,$000
 dn G_5,1,$E86
 dn ___,0,$000
 dn A_5,1,$E85
 dn ___,0,$000
 dn G_5,1,$E84
 dn ___,0,$000
 dn D_5,1,$E85
 dn ___,0,$000
 dn E_5,1,$E86
 dn ___,0,$000
 dn F#5,1,$E87
 dn ___,0,$000
 dn G_5,1,$E89
 dn ___,0,$000
 dn B_4,1,$E8A
 dn ___,0,$000
 dn E_5,1,$E8B
 dn ___,0,$000
 dn F#5,1,$E8C
 dn ___,0,$000
 dn G_5,1,$E8D
 dn ___,0,$000
 dn B_4,1,$E8C
 dn ___,0,$000
 dn A_5,1,$E8B
 dn ___,0,$000
 dn G_5,1,$E8A
 dn ___,0,$000
 dn F#5,1,$E88
 dn ___,0,$000
 dn F#4,1,$E87
 dn ___,0,$000
 dn B_4,1,$E86
 dn ___,0,$000
 dn E_5,1,$E85
 dn ___,0,$000
 dn F#5,1,$E84
 dn ___,0,$000
 dn A_4,1,$E85
 dn ___,0,$000
 dn B_4,1,$E86
 dn ___,0,$000
 dn E_5,1,$E87
 dn ___,0,$000

P30:
 dn E_6,1,$C0F
 dn ___,0,$000
 dn E_6,1,$C0C
 dn ___,0,$000
 dn E_6,1,$C0A
 dn ___,0,$000
 dn E_6,1,$C07
 dn ___,0,$000
 dn E_6,1,$C04
 dn ___,0,$000
 dn E_6,1,$C0F
 dn ___,0,$000
 dn E_6,1,$C0B
 dn ___,0,$000
 dn D_6,1,$C0F
 dn ___,0,$000
 dn D_6,1,$C0E
 dn ___,0,$000
 dn D_6,1,$C0C
 dn ___,0,$000
 dn D_6,1,$C0B
 dn ___,0,$000
 dn D_6,1,$C0A
 dn ___,0,$000
 dn D_6,1,$C08
 dn ___,0,$000
 dn D_6,1,$C07
 dn ___,0,$000
 dn D_6,1,$C0F
 dn ___,0,$000
 dn D_6,1,$C07
 dn ___,0,$000
 dn G_6,1,$C0F
 dn G_6,1,$C07
 dn G_6,1,$C04
 dn G_6,1,$C02
 dn G_6,1,$C0F
 dn G_6,1,$C07
 dn G_6,1,$C0F
 dn G_6,1,$C07
 dn G_6,1,$C06
 dn G_6,1,$C04
 dn C_6,1,$C0F
 dn ___,0,$000
 dn C_6,1,$C07
 dn ___,0,$000
 dn B_5,1,$C0F
 dn ___,0,$000
 dn B_5,1,$C0E
 dn ___,0,$000
 dn B_5,1,$C0C
 dn ___,0,$000
 dn B_5,1,$C0B
 dn ___,0,$000
 dn B_5,1,$C0A
 dn ___,0,$000
 dn D#5,1,$C0B
 dn D#5,1,$C03
 dn F#5,1,$C0B
 dn F#5,1,$C03
 dn A_5,1,$C0F
 dn A_5,1,$C03
 dn B_5,1,$C0F
 dn B_5,1,$C03

P31:
 dn C_5,1,$E89
 dn ___,0,$000
 dn E_5,1,$E8A
 dn ___,0,$000
 dn B_5,1,$E8B
 dn ___,0,$000
 dn C_6,1,$E8C
 dn ___,0,$000
 dn B_5,1,$E8D
 dn ___,0,$000
 dn G_5,1,$E8C
 dn ___,0,$000
 dn C_5,1,$E8B
 dn ___,0,$000
 dn E_5,1,$E8A
 dn ___,0,$000
 dn B_4,1,$E88
 dn ___,0,$000
 dn D_5,1,$E87
 dn ___,0,$000
 dn G_5,1,$E86
 dn ___,0,$000
 dn A_5,1,$E85
 dn ___,0,$000
 dn G_5,1,$E84
 dn ___,0,$000
 dn D_5,1,$E85
 dn ___,0,$000
 dn E_5,1,$E86
 dn ___,0,$000
 dn F#5,1,$E87
 dn ___,0,$000
 dn G_5,1,$E89
 dn ___,0,$000
 dn B_4,1,$E8A
 dn ___,0,$000
 dn E_5,1,$E8B
 dn ___,0,$000
 dn F#5,1,$E8C
 dn ___,0,$000
 dn G_5,1,$E8D
 dn ___,0,$000
 dn B_4,1,$E8C
 dn ___,0,$000
 dn A_5,1,$E8B
 dn ___,0,$000
 dn G_5,1,$E8A
 dn ___,0,$000
 dn F#5,1,$E88
 dn ___,0,$000
 dn F#4,1,$E87
 dn ___,0,$000
 dn B_4,1,$E86
 dn ___,0,$000
 dn E_5,1,$E85
 dn ___,0,$000
 dn F#5,1,$E84
 dn ___,0,$000
 dn A_4,1,$E85
 dn ___,0,$000
 dn B_4,1,$E86
 dn ___,0,$000
 dn E_5,1,$E87
 dn ___,0,$000

P70:
 dn E_6,1,$C0F
 dn ___,0,$000
 dn E_6,1,$C0C
 dn ___,0,$000
 dn E_6,1,$C0A
 dn ___,0,$000
 dn E_6,1,$C07
 dn ___,0,$000
 dn E_6,1,$C04
 dn ___,0,$000
 dn E_6,1,$C0F
 dn ___,0,$000
 dn E_6,1,$C0B
 dn ___,0,$000
 dn D_6,1,$C0F
 dn ___,0,$000
 dn D_6,1,$C0E
 dn ___,0,$000
 dn D_6,1,$C0C
 dn ___,0,$000
 dn D_6,1,$C0B
 dn ___,0,$000
 dn D_6,1,$C0A
 dn ___,0,$000
 dn D_6,1,$C08
 dn ___,0,$000
 dn D_6,1,$C07
 dn ___,0,$000
 dn D_6,1,$C0F
 dn ___,0,$000
 dn D_6,1,$C07
 dn ___,0,$000
 dn G_6,1,$C0F
 dn G_6,1,$C07
 dn G_6,1,$C04
 dn G_6,1,$C02
 dn G_6,1,$C0F
 dn G_6,1,$C07
 dn G_6,1,$C0F
 dn G_6,1,$C07
 dn G_6,1,$C06
 dn G_6,1,$C04
 dn B_6,1,$C0C
 dn C_7,1,$C0F
 dn C_7,1,$C07
 dn ___,0,$000
 dn B_6,1,$C0F
 dn ___,0,$000
 dn B_6,1,$C0E
 dn ___,0,$000
 dn F#6,1,$C0F
 dn F#6,1,$C0C
 dn F#6,1,$C0A
 dn F#6,1,$C07
 dn F#6,1,$C04
 dn F#6,1,$C02
 dn B_5,1,$C0B
 dn B_5,1,$C03
 dn E_6,1,$C0B
 dn E_6,1,$C03
 dn F#6,1,$C0F
 dn F#6,1,$C03
 dn A_6,1,$C0F
 dn A_6,1,$B02

duty_instruments:
itSquareinst1: db 8,64,240,128

wave_instruments:

noise_instruments:

routines:

waves:
