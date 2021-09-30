include "include/hUGE.inc"

SECTION "Song New Hiscore", ROMX

song_new_hiscore::
db 6
dw order_cnt
dw order1, order2, order3, order4
dw duty_instruments, wave_instruments, noise_instruments
dw routines
dw waves

order_cnt: db 4
order1: dw P20,P30
order2: dw P21,P31
order3: dw P0c,P0c
order4: dw P0c,P0c

P20:
 dn A_6,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A_6,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A_6,1,$C02
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A_6,1,$C00
 dn ___,0,$000
 dn F_6,1,$C0F
 dn E_6,1,$C0F
 dn D_6,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn D_6,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn D_6,1,$C02
 dn ___,0,$000
 dn C_6,1,$C0F
 dn ___,0,$000
 dn D_6,1,$C0F
 dn ___,0,$000
 dn F_6,1,$C0F
 dn ___,0,$000
 dn G_6,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn G_6,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn G_6,1,$C02
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn G_6,1,$C00
 dn ___,0,$000
 dn F_6,1,$C0F
 dn E_6,1,$C0F
 dn C#6,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A_5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A_5,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn F_6,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000

P21:
 dn D_6,1,$C0B
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn D_6,1,$C06
 dn ___,0,$000
 dn E_6,1,$C0B
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn E_6,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn F_6,1,$C0B
 dn G_6,1,$C0B
 dn A_6,1,$C0B
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A_6,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A_6,1,$C02
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn F_6,1,$C0B
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn G_6,1,$C0B
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn G_6,1,$C06
 dn ___,0,$000
 dn E_6,1,$C0B
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn C_6,1,$C0B
 dn ___,0,$000
 dn F_6,1,$C0B
 dn ___,0,$000
 dn E_6,1,$C0B
 dn ___,0,$000
 dn E_6,1,$C06
 dn ___,0,$000
 dn E_6,1,$C06
 dn ___,0,$000
 dn C#6,1,$C0B
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn C#6,1,$C06
 dn ___,0,$000
 dn E_5,1,$C0B
 dn ___,0,$000
 dn A_5,1,$C0B
 dn ___,0,$000
 dn G_5,1,$C0B
 dn ___,0,$000

P30:
 dn D_6,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn D_6,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn D_6,1,$C02
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn C_6,1,$C0F
 dn ___,0,$000
 dn A#5,1,$C0F
 dn ___,0,$000
 dn A_5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn D_5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A#5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A_5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn G_5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn G_5,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn G_5,1,$C02
 dn ___,0,$000
 dn E_5,1,$C0F
 dn ___,0,$000
 dn D_5,1,$C0F
 dn ___,0,$000
 dn E_5,1,$C0F
 dn ___,0,$000
 dn F_5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn F_5,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn E_5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn C_6,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000

P31:
 dn A_5,1,$C0F
 dn ___,0,$000
 dn F_5,1,$C0F
 dn ___,0,$000
 dn D_5,1,$C0F
 dn ___,0,$000
 dn A#5,1,$C0F
 dn ___,0,$000
 dn A#5,1,$C07
 dn ___,0,$000
 dn A_5,1,$C0F
 dn ___,0,$000
 dn A_5,1,$C07
 dn ___,0,$000
 dn A#5,1,$C0F
 dn ___,0,$000
 dn C_6,1,$C0F
 dn ___,0,$000
 dn C_6,1,$C07
 dn ___,0,$000
 dn C_6,1,$C06
 dn ___,0,$000
 dn D_6,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn D_6,1,$C06
 dn ___,0,$000
 dn A_5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A#5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A#5,1,$C06
 dn ___,0,$000
 dn A#5,1,$C02
 dn ___,0,$000
 dn A_5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A_5,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn G_5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn G_5,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A_5,1,$C0F
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000
 dn A_5,1,$C06
 dn ___,0,$000
 dn ___,0,$000
 dn ___,0,$000

duty_instruments:
itSquareinst1: db 8,64,245,128

wave_instruments:

noise_instruments:

routines:

waves: