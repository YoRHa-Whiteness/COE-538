;*****************************************************************
;* This stationery serves as the framework for a                 *
;* user application (single file, absolute assembly application) *
;* For a more comprehensive program that                         *
;* demonstrates the more advanced functionality of this          *
;* processor, please see the demonstration applications          *
;* located in the examples subdirectory of the                   *
;* Freescale CodeWarrior for the HC12 Program directory          *
;*****************************************************************
;Created by Vincent To 500824873
; export symbols
            XDEF Entry, _Startup            ; export 'Entry' symbol
            ABSENTRY Entry                  ; for absolute assembly: mark this as application entry point

; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 

;*****************************************************************
;* Motor Control and Using the Hardware Timer                    *
;*****************************************************************

; Definitions
OneSec          EQU   23                        ; 1 second delay (at 23Hz)
TwoSec          EQU   46                        ; 2 second delay (at 23Hz)
                                
LCD_DAT         EQU PORTB                       ; LCD data port, bits - PB7,...,PB0
LCD_CNTR        EQU PTJ                         ; LCD control port, bits - PJ6(RS),PJ7(E)
LCD_E           EQU $80                         ; LCD E-signal pin
LCD_RS          EQU $40                         ; LCD RS-signal pin

; Variable/data section
                ORG   $3850
TOF_COUNTER     RMB   1                         ; The timer, incremented at 23Hz
AT_DEMO         RMB   1                         ; The alarm time for this demo

; Code section
                ORG $4000
Entry:
_Startup:
                LDS   #$4000                    ; initialize the stack pointer
                JSR   initLCD                   ; initialize LCD
                JSR   clrLCD                    ; clear LCD & home cursor
                JSR   ENABLE_TOF                ; Jump to TOF initialization
                CLI                             ; Enable global interrupt

                LDAA  #'A'                      ; Display A (for 1 sec)
                JSR   putcLCD                   
                
                LDAA  TOF_COUNTER               ; Initialize the alarm time
                ADDA  #OneSec                   ; by adding on the 1 sec delay
                STAA  AT_DEMO                   ; and save it in the alarm
CHK_DELAY_1     LDAA  TOF_COUNTER               ; If the current time
                CMPA  AT_DEMO                   ; equals the alarm time
                BEQ   A1                        ; then display B
                BRA   CHK_DELAY_1               ; and check the alarm again
                
A1              LDAA  #'B'                      ;  Display B (for 2 sec)
                JSR   putcLCD                   
                
                LDAA  AT_DEMO                   ; Initialize the alarm time
                ADDA  #TwoSec                   ; by adding on the 2 sec delay
                STAA  AT_DEMO                   ; and save it in the alarm
CHK_DELAY_2     LDAA  TOF_COUNTER               ; If the current time
                CMPA  AT_DEMO                   ; equals the alarm time
                BEQ   A2                        ; then display C
                BRA   CHK_DELAY_2               ; and check the alarm again
                
A2              LDAA  #'C'                      ; Display C (forever)
                JSR   putcLCD                   
                SWI

;subroutine section

;Initialization of the LCD                      (same as lab 3)
initLCD         BSET DDRB,%11111111             ; configure pins PB7,...,PB0 for output
                BSET DDRJ,%11000000             ; configure pins PJ7(E), PJ6(RS) for output
                LDY  #2000                      ; wait for LCD to be ready
                JSR  del_50us                   
                LDAA #$28                       ; set 4-bit data, 2-line display
                JSR  cmd2LCD                    
                LDAA #$0C                       ; display on, cursor off, blinking off
                JSR  cmd2LCD                    
                LDAA #$06                       ; move cursor right after entering a char.
                JSR  cmd2LCD                    
                RTS

;Clear display and home cursor
clrLCD          LDAA #$01                       ; clear cursor and return to home position
                JSR  cmd2LCD                    
                LDY  #40                        ; wait until "clear cursor" finishes
                JSR  del_50us                   
                RTS

;([Y] x 50us)-delay subroutine. E-clk=41,67ns.             
del_50us:       PSHX                            ;2 E-clk
eloop: 	        LDX  #71                        ;2 E-clk -
iloop: 	        PSHA                            ;2 E-clk  |
                PULA                            ;3 E-clk  |
                PSHA                            ;2 E-clk  | 50us
                PULA                            ;3 E-clk  |
                NOP                             ;1 E-clk  |
                NOP                             ;1 E-clk  |
                DBNE X,iloop                    ;3 E-clk -
                DBNE Y,eloop                    ;3 E-clk
                PULX                            ;3 E-clk
                RTS                             ;5 E-clk

;Send a command in accumulator A to the LCD    
cmd2LCD:        BCLR LCD_CNTR,LCD_RS            ; select the LCD Instruction Register (IR)
                JSR  dataMov                    ; send data to IR
      	        RTS

;Output a NULL-terminated string pointed to by X 
putsLCD         LDAA 1,X+                       ; Obtain one char from the string
                BEQ  donePS                     ; reach NULL char.
                JSR  putcLCD
                BRA  putsLCD
donePS 	        RTS

;Output character in accumulator in A to LCD 
putcLCD         BSET LCD_CNTR,LCD_RS            ; select the LCD Data register (DR)
                JSR  dataMov                    ; send data to DR
                RTS

;Send data to the LCD IR or DR depening on RS    
dataMov         BSET LCD_CNTR,LCD_E             ; pull the LCD E-signal high
                STAA LCD_DAT                    ; send the upper 4 bits of data to LCD
                BCLR LCD_CNTR,LCD_E             ; pull the LCD E-signal low to complete the write oper.
                LSLA                            ; match the lower 4 bits with the LCD data pins
                LSLA                            
                LSLA                            
                LSLA                            
                BSET LCD_CNTR,LCD_E             ; pull the LCD E signal high
                STAA LCD_DAT                    ; send the lower 4 bits of data to LCD
                BCLR LCD_CNTR,LCD_E             ; pull the LCD E-signal low to complete the write oper.
                LDY  #1                         ; delay to complete internal operation
                JSR  del_50us                   
            	RTS
            	
;Enable Timer Overflow Flag                     (same as appendix B)              
ENABLE_TOF      LDAA  #%10000000
                STAA  TSCR1                     ; Enable TCNT
                STAA  TFLG2                     ; Clear TOF
                LDAA  #%10000100                ; Enable TOI and select prescale factor equal to 16
                STAA  TSCR2
                RTS

;Interupt Service Routine          
TOF_ISR         INC   TOF_COUNTER
                LDAA  #%10000000                ; Clear
                STAA  TFLG2                     ; TOF
                RTI

;*******************************************************************
;*                 Interrupt Vectors                               *
;*******************************************************************
            ORG   $FFFE
            DC.W  Entry                         ; Reset Vector
            
            ORG   $FFDE
            DC.W  TOF_ISR                       ; Timer Overflow Interrupt Vector
