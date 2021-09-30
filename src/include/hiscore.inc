;***************************************

;*                                     *

;*  HISCORE.INC                        *

;*                                     *

;*  Copyright H. Mulder, 1999          *

;*                                     *

;*  This file accompanies HISCORE.Z80. *

;*                                     *

;***************************************



EXPORT ResetHiScore

EXPORT AddHiScore

EXPORT AddBCHiScore

EXPORT CpHiScore



;* Change this value to in- or decrease the maximum size of your HiScores *



; This is 8 to make seeking the speed-based hiscores easier, though it's
;  possible someone may actually hit 8 digits. We only show the full 8 digits
;  on the status screen. The battle screen only shows the lower 7.
DEF HISCORE_LENGTH EQU 8             ; Default is 8





;* End of HISCORE.INC *

