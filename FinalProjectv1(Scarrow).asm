; =============================================================================
; HIGH NOON - Wild West Reaction Time Game
; LC-3 Assembly
; =============================================================================
; ADDRESSING RULES:
;   LD/ST/LEA/BR  9-bit  -> data within +/-255 words of instruction
;   JSR           11-bit -> target within +/-1023 words
;   JSRR Rn       16-bit -> anywhere in memory (used for all JSR calls)
;
; KB_POLL:
;   Non-blocking keyboard read implemented as a plain subroutine.
;   Called via LD R5 / JSRR R5 like all other subroutines.
;   Returns R0 = char if key ready, R0 = 0 if no key.
;   No privilege mode or trap vector table required.
;
; GAME FLOW:
;   Title -> [loop] Ready -> RandomDelay -> DRAW! -> ReactionLoop -> Score
;   ReactionLoop animates the outlaw drawing frame-by-frame.
;   Press any key before the outlaw fires to survive.
;   Too slow = dead.
; =============================================================================

.ORIG x3000

; =============================================================================
; MAIN
; =============================================================================
MAIN
    LD   R6, STACK_BASE

    LD   R5, ADDR_PTITLE        ; title screen + wait for key
    JSRR R5

GAME_LOOP
    LD   R5, ADDR_PREADY
    JSRR R5

    LD   R5, ADDR_RDELAY        ; suspense delay; R0 = 1 if player drew early
    JSRR R5
    ADD  R0, R0, #0             ; set condition codes (JSRR doesn't)
    BRp  SKIP_ACTION            ; cheater -> skip DRAW! and reaction loop

    LD   R5, ADDR_PDRAW         ; flush buffer, print DRAW! banner
    JSRR R5

    LD   R5, ADDR_RLOOP         ; animated reaction loop (sets PLAYER_ALIVE)
    JSRR R5

SKIP_ACTION
    LD   R5, ADDR_PSCORE        ; print outcome (checks CHEATER first)
    JSRR R5

    LD   R5, ADDR_AGAIN         ; play again? -> R0 = 1 or 0
    JSRR R5
    ADD  R0, R0, #0             ; set condition codes on R0 (JSRR doesn't)
    BRp  GAME_LOOP

    LD   R5, ADDR_PBYE
    JSRR R5
    HALT

; ---- jump table (all within 255 words of MAIN) ------------------------------
STACK_BASE    .FILL x3F00
ADDR_PTITLE   .FILL PRINT_TITLE
ADDR_PREADY   .FILL PRINT_READY
ADDR_RDELAY   .FILL RANDOM_DELAY
ADDR_PDRAW    .FILL PRINT_DRAW
ADDR_RLOOP    .FILL REACTION_LOOP
ADDR_PSCORE   .FILL PRINT_SCORE
ADDR_AGAIN    .FILL ASK_PLAY_AGAIN
ADDR_PBYE     .FILL PRINT_GOODBYE

; =============================================================================
; SUBROUTINE: KB_POLL
;   Non-blocking keyboard read.  Called via LD R5 / JSRR R5.
;   Returns: R0 = character if a key is ready, R0 = 0 otherwise.
;   All other registers unchanged.
; =============================================================================
KB_POLL
    LDI  R0, KBP_SR            ; read keyboard status register
    BRzp KBP_NONE              ; bit 15 clear -> no key ready
    LDI  R0, KBP_DR            ; bit 15 set  -> read the character
    RET
KBP_NONE
    AND  R0, R0, #0            ; return 0 (no key)
    RET

KBP_SR .FILL xFE00
KBP_DR .FILL xFE02

; =============================================================================
; SUBROUTINE: PRINT_TITLE
;   Clear screen, ASCII art, wait for any key to begin.
; =============================================================================
PRINT_TITLE
    ST   R7, PT_R7
    ST   R0, PT_R0

    LEA  R0, STR_CLEAR
    LD   R5, PT_PSTR
    JSRR R5

    LEA  R0, STR_TITLE
    LD   R5, PT_PSTR
    JSRR R5

PT_WAIT
    LDI  R0, PT_KBSR
    BRzp PT_WAIT
    LDI  R0, PT_KBDR            ; consume the keypress

    LD   R0, PT_R0
    LD   R7, PT_R7
    RET

PT_R7   .BLKW 1
PT_R0   .BLKW 1
PT_KBSR .FILL xFE00
PT_KBDR .FILL xFE02
PT_PSTR .FILL PRINT_STR

STR_CLEAR
    .STRINGZ "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"

STR_TITLE
    .STRINGZ "============================================================\n        H I G H   N O O N\n        A Wild West Reaction Time Game\n============================================================\n\n           |     |\n          [=====]      _\n           |   |      |_|  <-- you\n           *   *\n\n  The sun beats down on the dusty street.\n  Your hand hovers near your iron.\n\n  When you see  >>> DRAW! <<<  press ANY KEY before\n  the outlaw fires.  Too slow and you die.\n\n  Press any key to begin...\n\n"

; =============================================================================
; SUBROUTINE: PRINT_READY
;   Suspense screen between rounds.
; =============================================================================
PRINT_READY
    ST   R7, PRY_R7
    ST   R0, PRY_R0

    LEA  R0, STR_READY
    LD   R5, PRY_PSTR
    JSRR R5

    LD   R0, PRY_R0
    LD   R7, PRY_R7
    RET

PRY_R7   .BLKW 1
PRY_R0   .BLKW 1
PRY_PSTR .FILL PRINT_STR

STR_READY
    .STRINGZ "\n------------------------------------------------------------\n  *  tumbleweed rolls by...  *\n\n        .    .    .    Keep your hand steady...\n\n"

; =============================================================================
; SUBROUTINE: PRINT_DRAW
;   1) Flush keyboard buffer (discard any presses made during the delay)
;   2) Print DRAW! banner
;   Flushing here means the reaction loop starts clean.
; =============================================================================
PRINT_DRAW
    ST   R7, PDR_R7
    ST   R0, PDR_R0

PDR_FLUSH
    LDI  R0, PDR_KBSR           ; check for buffered keypress
    BRzp PDR_FLUSH_DONE
    LDI  R0, PDR_KBDR           ; discard it
    BR   PDR_FLUSH
PDR_FLUSH_DONE

    LEA  R0, STR_DRAW
    LD   R5, PDR_PSTR
    JSRR R5

    LD   R0, PDR_R0
    LD   R7, PDR_R7
    RET

PDR_R7   .BLKW 1
PDR_R0   .BLKW 1
PDR_KBSR .FILL xFE00
PDR_KBDR .FILL xFE02
PDR_PSTR .FILL PRINT_STR

STR_DRAW
    .STRINGZ "\n  +---------------------------------------------------------+\n  |                                                         |\n  |      * * * * *    D R A W !    * * * * *               |\n  |                                                         |\n  +---------------------------------------------------------+\n\n"

; =============================================================================
; SUBROUTINE: REACTION_LOOP
;   Animates the outlaw drawing his gun frame by frame.
;   Between each frame it calls KB_POLL via JSRR to check for a keypress.
;   If the player presses any key before the last frame: PLAYER_ALIVE = 1
;   If all frames expire with no keypress:              PLAYER_ALIVE = 0
;
;   Sets: PLAYER_ALIVE (1 = survived, 0 = dead)
;         PLAYER_FRAME (frame 0-2 when key was pressed; only valid if alive)
;
;   Animation frames (3 survive + 1 death):
;     Frame 0:  ( o ) |_|   hand twitches...
;     Frame 1:  ( o ) |_/   reaching for iron...
;     Frame 2:  ( o ) [=/   DRAWING!!!
;     Death:    ( o ) [==>  *BANG!*
;
;   Uses R3 as frame counter. R5 as JSRR scratch (not saved by convention).
; =============================================================================
REACTION_LOOP
    ST   R7, RL_R7
    ST   R0, RL_R0
    ST   R1, RL_R1
    ST   R2, RL_R2
    ST   R3, RL_R3

    AND  R3, R3, #0             ; R3 = frame counter = 0

RL_FRAME
    LD   R5, RL_KBPOLL          ; non-blocking keyboard check
    JSRR R5                     ; KB_POLL -> R0 = char or 0
    ADD  R0, R0, #0             ; set condition codes on R0
    BRnp RL_PRESSED             ; nonzero char = key pressed

    ; No key yet.  Check if we have exhausted all frames.
    LD   R1, RL_MAX_FRAMES
    NOT  R1, R1
    ADD  R1, R1, #1             ; R1 = -MAX_FRAMES
    ADD  R1, R3, R1             ; R1 = frame - MAX_FRAMES
    BRz  RL_DEAD                ; reached limit -> dead

    ; Print the animation frame for R3
    LEA  R1, RL_FTABLE          ; base of frame address table
    ADD  R1, R1, R3             ; R1 = &table[frame]
    LDR  R0, R1, #0             ; R0 = address of frame string
    LD   R5, RL_PSTR
    JSRR R5

    ; Busy-wait delay between frames (gives player time to react)
    LD   R1, RL_OUTER
RL_OLOOP
    LD   R2, RL_INNER
RL_ILOOP
    ADD  R2, R2, #-1
    BRnp RL_ILOOP
    ADD  R1, R1, #-1
    BRnp RL_OLOOP

    ADD  R3, R3, #1             ; advance frame
    BR   RL_FRAME

RL_PRESSED
    ; Player hit a key in time!
    AND  R0, R0, #0
    ADD  R0, R0, #1
    ST   R0, PLAYER_ALIVE       ; alive = 1
    ST   R3, PLAYER_FRAME       ; save frame number for scoring
    BR   RL_DONE

RL_DEAD
    ; Print death animation frame
    LEA  R0, STR_OUTLAW_DEAD
    LD   R5, RL_PSTR
    JSRR R5
    AND  R0, R0, #0
    ST   R0, PLAYER_ALIVE       ; alive = 0

RL_DONE
    LD   R0, RL_R0
    LD   R1, RL_R1
    LD   R2, RL_R2
    LD   R3, RL_R3
    LD   R7, RL_R7
    RET

RL_R7          .BLKW 1
RL_R0          .BLKW 1
RL_R1          .BLKW 1
RL_R2          .BLKW 1
RL_R3          .BLKW 1
RL_PSTR        .FILL PRINT_STR
RL_KBPOLL      .FILL KB_POLL
RL_MAX_FRAMES  .FILL #3         ; frames 0,1,2 = survive window; hitting 3 = dead
RL_OUTER       .FILL #60        ; tune these two to adjust frame speed (was 150)
RL_INNER       .FILL #200

; Frame address table (indexed by frame number 0-2)
RL_FTABLE
    .FILL STR_FRAME0
    .FILL STR_FRAME1
    .FILL STR_FRAME2

; Shared outcome flags (read by PRINT_SCORE)
PLAYER_ALIVE .BLKW 1
PLAYER_FRAME .BLKW 1
CHEATER      .BLKW 1            ; 1 = player drew before DRAW! (set by RANDOM_DELAY)

STR_FRAME0
    .STRINGZ "  ( o ) |_|   ...hand twitches...\n"
STR_FRAME1
    .STRINGZ "  ( o ) |_/   ...reaching for iron...\n"
STR_FRAME2
    .STRINGZ "  ( o ) [=/   THE OUTLAW DRAWS!\n"
STR_OUTLAW_DEAD
    .STRINGZ "  ( o ) [==>  *BANG!*  The outlaw fires first!\n\n"

; =============================================================================
; SUBROUTINE: PRINT_SCORE
;   Reads PLAYER_ALIVE and PLAYER_FRAME, prints the outcome.
;   Alive scoring (by frame pressed):
;     Frame 0 -> LIGHTNING FAST  (reacted before outlaw even moved)
;     Frame 1 -> Quick Draw      (reacted as outlaw reached)
;     Frame 2 -> Just in time    (reacted as outlaw drew)
;   Dead -> epitaph message
; =============================================================================
PRINT_SCORE
    ST   R7, PSC_R7
    ST   R0, PSC_R0
    ST   R1, PSC_R1

    LD   R1, CHEATER            ; check cheat flag first
    BRp  PSC_CHEATED

    LD   R1, PLAYER_ALIVE
    BRz  PSC_DEAD               ; alive = 0 -> dead path

    ; --- ALIVE ---
    LEA  R0, STR_BANG
    LD   R5, PSC_PSTR
    JSRR R5

    LD   R1, PLAYER_FRAME

    BRz  PSC_FAST               ; frame 0

    ADD  R1, R1, #-1
    BRz  PSC_MEDIUM             ; frame 1

    ; frame 2 (just in time)
    LEA  R0, STR_CLOSE
    LD   R5, PSC_PSTR
    JSRR R5
    BR   PSC_DONE

PSC_FAST
    LEA  R0, STR_FAST
    LD   R5, PSC_PSTR
    JSRR R5
    BR   PSC_DONE

PSC_MEDIUM
    LEA  R0, STR_MEDIUM
    LD   R5, PSC_PSTR
    JSRR R5
    BR   PSC_DONE

    ; --- DEAD ---
PSC_DEAD
    LEA  R0, STR_EPITAPH
    LD   R5, PSC_PSTR
    JSRR R5
    BR   PSC_DONE

    ; --- CHEATED (drew too early) ---
PSC_CHEATED
    LEA  R0, STR_CHEAT_SCORE
    LD   R5, PSC_PSTR
    JSRR R5

PSC_DONE
    LD   R0, PSC_R0
    LD   R1, PSC_R1
    LD   R7, PSC_R7
    RET

PSC_R7   .BLKW 1
PSC_R0   .BLKW 1
PSC_R1   .BLKW 1
PSC_PSTR .FILL PRINT_STR

STR_BANG
    .STRINGZ "\n  [BANG!]\n\n  "
STR_FAST
    .STRINGZ "LIGHTNING FAST! You drew before the outlaw blinked!\n\n"
STR_MEDIUM
    .STRINGZ "Quick Draw! You got 'em!\n\n"
STR_CLOSE
    .STRINGZ "Just in time... that was way too close, partner.\n\n"
STR_EPITAPH
    .STRINGZ "  ...They'll be buryin' you at sundown, cowboy.\n\n"
STR_CHEAT_SCORE
    .STRINGZ "\n  [CLICK... BANG!]\n\n  You shot your own boot, cowboy.\n  No outlaw needed -- you done it to yourself.\n\n"

; =============================================================================
; SUBROUTINE: ASK_PLAY_AGAIN
;   Prompts y/n, returns R0 = 1 for y/Y, R0 = 0 otherwise.
; =============================================================================
ASK_PLAY_AGAIN
    ST   R7, AP_R7
    ST   R1, AP_R1

    LEA  R0, STR_AGAIN
    LD   R5, AP_PSTR
    JSRR R5

AP_WAIT
    LDI  R1, AP_KBSR
    BRzp AP_WAIT
    LDI  R0, AP_KBDR            ; R0 = key pressed
    ST   R0, AP_KEY
    OUT                         ; echo character
    AND  R0, R0, #0
    ADD  R0, R0, #10            ; newline (ASCII 10)
    OUT

    LD   R0, AP_KEY

    LD   R1, AP_Y_LOW
    NOT  R1, R1
    ADD  R1, R1, #1
    ADD  R1, R0, R1
    BRz  AP_YES

    LD   R1, AP_Y_UP
    NOT  R1, R1
    ADD  R1, R1, #1
    ADD  R1, R0, R1
    BRz  AP_YES

    AND  R0, R0, #0             ; return 0 (no)
    BR   AP_DONE

AP_YES
    AND  R0, R0, #0
    ADD  R0, R0, #1             ; return 1 (yes)

AP_DONE
    LD   R1, AP_R1
    LD   R7, AP_R7
    RET

AP_R7    .BLKW 1
AP_R1    .BLKW 1
AP_KEY   .BLKW 1
AP_KBSR  .FILL xFE00
AP_KBDR  .FILL xFE02
AP_Y_LOW .FILL x79              ; 'y'
AP_Y_UP  .FILL x59              ; 'Y'
AP_PSTR  .FILL PRINT_STR

STR_AGAIN .STRINGZ "\n  Play again? (y/n): "

; =============================================================================
; SUBROUTINE: RANDOM_DELAY
;   Variable-length suspense wait before DRAW!  Prints 3-6 random "suspense"
;   lines (rolling tumbleweeds, pounding heart, sweat, etc.) with a busy-wait
;   between each one. Some lines are deliberately worded to tempt the player
;   into reacting early.
;
;   EARLY-PRESS DETECTION:
;     After each sub-delay, KB_POLL is called.  If a key was pressed:
;       - Print a "you twitched!" notice
;       - Set CHEATER = 1 (read later by PRINT_SCORE)
;       - Exit early
;     If no key was pressed during the entire delay, CHEATER stays 0.
;
;   RETURNS: R0 = 1 if player drew early, R0 = 0 otherwise.
;            (R0 is NOT saved/restored -- it carries the return value.)
;
;   Uses RD_SEED for pseudo-random line count (3-6) and table offset (0-7).
; =============================================================================
RANDOM_DELAY
    ST   R7, RD_R7
    ST   R1, RD_R1
    ST   R2, RD_R2
    ST   R3, RD_R3
    ST   R4, RD_R4

    ; --- clear cheat flag for this round ---
    AND  R0, R0, #0
    STI  R0, RD_CHEATER_PTR     ; CHEATER = 0

    ; --- flush any stale keypress left over from previous prompt ---
    LD   R5, RD_KBPOLL
    JSRR R5                     ; discard return value

    ; --- update seed (shift-register) ---
    LD   R0, RD_SEED
    ADD  R0, R0, R0             ; shift left
    ADD  R0, R0, #1             ; keep nonzero
    ST   R0, RD_SEED

    ; --- pick number of lines to show: 3 + (seed & 3)  =  3 to 6 lines ---
    LD   R1, RD_MASK_LINES      ; #3
    AND  R4, R0, R1             ; R4 = seed & 3   (0..3)
    ADD  R4, R4, #3             ; R4 = 3..6

    ; --- pick starting offset into suspense table: seed & 7 ---
    LD   R1, RD_MASK_TABLE      ; #7
    AND  R3, R0, R1             ; R3 = 0..7

RD_LINE_LOOP
    ; print suspense line at RD_TABLE[R3]
    LEA  R1, RD_TABLE
    ADD  R1, R1, R3
    LDR  R0, R1, #0             ; R0 = address of string
    LD   R5, RD_PSTR
    JSRR R5

    ; sub-delay between lines
    LD   R0, RD_SUB_OUTER
RD_SUB_OL
    ADD  R0, R0, #-1
    BRz  RD_SUB_DONE
    LD   R2, RD_SUB_INNER
RD_SUB_IL
    ADD  R2, R2, #-1
    BRnp RD_SUB_IL
    BR   RD_SUB_OL
RD_SUB_DONE

    ; --- CHECK FOR EARLY KEYPRESS ---
    LD   R5, RD_KBPOLL
    JSRR R5                     ; R0 = char if pressed, 0 otherwise
    ADD  R0, R0, #0             ; set condition codes on R0
    BRnp RD_CHEATED             ; nonzero -> player drew early!

    ; advance line index, wrap at 8
    ADD  R3, R3, #1
    LD   R1, RD_MASK_TABLE      ; #7
    AND  R3, R3, R1

    ; decrement line counter, loop if more lines remaining
    ADD  R4, R4, #-1
    BRp  RD_LINE_LOOP

    ; --- normal exit: no early press ---
    AND  R0, R0, #0             ; return R0 = 0
    BR   RD_DONE

RD_CHEATED
    ; Print "you twitched" notice mid-suspense
    LEA  R0, STR_TWITCH
    LD   R5, RD_PSTR
    JSRR R5

    ; Set CHEATER = 1 for PRINT_SCORE to read
    AND  R0, R0, #0
    ADD  R0, R0, #1
    STI  R0, RD_CHEATER_PTR
    ; R0 still = 1, becomes the return value

RD_DONE
    LD   R1, RD_R1
    LD   R2, RD_R2
    LD   R3, RD_R3
    LD   R4, RD_R4
    LD   R7, RD_R7
    RET

RD_R7          .BLKW 1
RD_R1          .BLKW 1
RD_R2          .BLKW 1
RD_R3          .BLKW 1
RD_R4          .BLKW 1
RD_SEED        .FILL xACE1
RD_PSTR        .FILL PRINT_STR
RD_KBPOLL      .FILL KB_POLL
RD_CHEATER_PTR .FILL CHEATER
RD_MASK_LINES  .FILL #3         ; mask for "0..3 -> 3..6 lines"
RD_MASK_TABLE  .FILL #7         ; mask for "0..7 table index"
RD_SUB_OUTER   .FILL #80        ; per-line outer-loop count
RD_SUB_INNER   .FILL #1500      ; per-line inner-loop iterations

STR_TWITCH .STRINGZ "\n  *** Whoa partner -- you drew TOO EARLY! ***\n"

; suspense line address table (8 entries, indexed 0-7)
RD_TABLE
    .FILL STR_SUS_0
    .FILL STR_SUS_1
    .FILL STR_SUS_2
    .FILL STR_SUS_3
    .FILL STR_SUS_4
    .FILL STR_SUS_5
    .FILL STR_SUS_6
    .FILL STR_SUS_7

STR_SUS_0  .STRINGZ "  *  tumbleweed rolls past...  *\n"
STR_SUS_1  .STRINGZ "  the wind howls down the canyon...\n"
STR_SUS_2  .STRINGZ "  your heart pounds in your ears...\n"
STR_SUS_3  .STRINGZ "  the outlaw's eyes narrow...\n"
STR_SUS_4  .STRINGZ "  sweat drips from your hatband...\n"
STR_SUS_5  .STRINGZ "  a hawk circles overhead...\n"
STR_SUS_6  .STRINGZ "  the saloon doors creak shut...\n"
STR_SUS_7  .STRINGZ "  was that... a twitch??\n"

; =============================================================================
; SUBROUTINE: PRINT_GOODBYE
; =============================================================================
PRINT_GOODBYE
    ST   R7, PG_R7
    ST   R0, PG_R0

    LEA  R0, STR_BYE
    LD   R5, PG_PSTR
    JSRR R5

    LD   R0, PG_R0
    LD   R7, PG_R7
    RET

PG_R7   .BLKW 1
PG_R0   .BLKW 1
PG_PSTR .FILL PRINT_STR

STR_BYE
    .STRINGZ "\n  You holster your iron and ride off into the sunset.\n  Ride on, cowboy.\n\n============================================================\n\n"

; =============================================================================
; SUBROUTINE: PRINT_STR
;   Prints null-terminated string whose address is in R0.
;   Clobbers R0 and R1.  Called via JSRR (no range limit needed).
; =============================================================================
PRINT_STR
    ST   R7, PS_R7
PS_LOOP
    LDR  R1, R0, #0             ; load char from [R0]
    BRz  PS_DONE                ; null terminator -> done
    ST   R0, PS_PTR
    ADD  R0, R1, #0             ; move char to R0
    OUT
    LD   R0, PS_PTR
    ADD  R0, R0, #1
    BR   PS_LOOP
PS_DONE
    LD   R7, PS_R7
    RET

PS_R7  .BLKW 1
PS_PTR .BLKW 1

.END
