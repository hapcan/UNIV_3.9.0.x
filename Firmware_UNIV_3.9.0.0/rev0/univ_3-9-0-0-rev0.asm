;==============================================================================
;   HAPCAN - Home Automation Project Firmware (http://hapcan.com)
;   Copyright (C) 2017 hapcan.com
;
;   This program is free software: you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, either version 3 of the License, or
;   (at your option) any later version.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program.  If not, see <http://www.gnu.org/licenses/>.
;==============================================================================
;   Filename:              univ_3-9-0-0.asm
;   Associated diagram:    univ_3-9-0-x.sch
;   Author:                Jacek Siwilo                          
;   Note:                  10 Open Collector Outputs
;==============================================================================
;   Revision History
;   Rev:  Date:     Details:
;   0     06.2017   Initial version
;==============================================================================
;===  FIRMWARE DEFINITIONS  =================================================== 
;==============================================================================
    #define    ATYPE    .9                            ;application type [0-255]
    #define    AVERS    .0                         ;application version [0-255]
    #define    FVERS    .0                            ;firmware version [0-255]

    #define    FREV     .0                         ;firmware revision [0-65536]
;==============================================================================
;===  NEEDED FILES  ===========================================================
;==============================================================================
    LIST P=18F26K80                              ;directive to define processor
    #include <P18F26K80.INC>           ;processor specific variable definitions
    #include "univ_3-9-0-0-rev0.inc"                         ;project variables
INCLUDEDFILES   code  
    #include "univ3-routines-rev8.inc"                     ;UNIV 3 CPU routines
    #include "univ3-I2C-rev1.inc"                                 ;I2C routines
;==============================================================================
;===  FIRMWARE CHECKSUM  ======================================================
;==============================================================================
FIRMCHKSM   code    0x001000
    DB      0x64, 0xC9, 0x71, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF            
;==============================================================================
;===  FIRMWARE ID  ============================================================
;==============================================================================
FIRMID      code    0x001010
    DB      0x30, 0x00, 0x03,ATYPE,AVERS,FVERS,FREV>>8,FREV
;            |     |     |     |     |     |     |_____|_____ firmware revision
;            |     |     |     |     |     |__________________ firmware version
;            |     |     |     |     |_____________________ application version
;            |     |     |     |______________________________ application type
;            |     |     |________________________________ hardware version '3'
;            |_____|______________________________________ hardware type 'UNIV'
;==============================================================================
;===  MOVED VECTORS  ==========================================================
;==============================================================================
;PROGRAM RESET VECTOR
FIRMRESET   code    0x1020
        goto    Main
;PROGRAM HIGH PRIORITY INTERRUPT VECTOR
FIRMHIGHINT code    0x1030
        call    HighInterrupt
        retfie
;PROGRAM LOW PRIORITY INTERRUPT VECTOR
FIRMLOWINT  code    0x1040
        call    LowInterrupt
        retfie

;==============================================================================
;===  FIRMWARE STARTS  ========================================================
;==============================================================================
FIRMSTART   code    0x001050
;------------------------------------------------------------------------------
;---  LOW PRIORITY INTERRUPT  -------------------------------------------------
;------------------------------------------------------------------------------
LowInterrupt
        movff   STATUS,STATUS_LOW           ;save STATUS register
        movff   WREG,WREG_LOW               ;save working register
        movff   BSR,BSR_LOW                 ;save BSR register
        movff   FSR0L,FSR0L_LOW             ;save other registers used in high int
        movff   FSR0H,FSR0H_LOW
        movff   FSR1L,FSR1L_LOW
        movff   FSR1H,FSR1H_LOW

    ;main firmware ready flag
        banksel FIRMREADY
        btfss   FIRMREADY,0
        bra     ExitLowInterrupt            ;main firmware is not ready yet
    ;CAN buffer
        banksel CANFULL
        btfsc   CANFULL,0                   ;check if CAN received anything
        call    CANInterrupt                ;proceed with CAN interrupt

ExitLowInterrupt
        movff   BSR_LOW,BSR                 ;restore BSR register
        movff   WREG_LOW,WREG               ;restore working register
        movff   STATUS_LOW,STATUS           ;restore STATUS register
        movff   FSR0L_LOW,FSR0L             ;restore other registers used in high int
        movff   FSR0H_LOW,FSR0H
        movff   FSR1L_LOW,FSR1L
        movff   FSR1H_LOW,FSR1H
    return

;------------------------------------------------------------------------------
;---  HIGH PRIORITY INTERRUPT  ------------------------------------------------
;------------------------------------------------------------------------------
HighInterrupt
        movff   STATUS,STATUS_HIGH          ;save STATUS register
        movff   WREG,WREG_HIGH              ;save working register
        movff   BSR,BSR_HIGH                ;save BSR register
        movff   FSR0L,FSR0L_HIGH            ;save other registers used in high int
        movff   FSR0H,FSR0H_HIGH
        movff   FSR1L,FSR1L_HIGH
        movff   FSR1H,FSR1H_HIGH

    ;main firmware ready flag
        banksel FIRMREADY
        btfss   FIRMREADY,0
        bra     ExitHighInterrupt           ;main firmware is not ready yet
    ;Timer0
        btfsc   INTCON,TMR0IF               ;Timer0 interrupt? (1000ms)
        rcall   Timer0Interrupt
    ;Timer2    
        btfsc   PIR1,TMR2IF                 ;Timer2 interrupt? (20ms)
        rcall   Timer2Interrupt

ExitHighInterrupt
        movff   BSR_HIGH,BSR                ;restore BSR register
        movff   WREG_HIGH,WREG              ;restore working register
        movff   STATUS_HIGH,STATUS          ;restore STATUS register
        movff   FSR0L_HIGH,FSR0L            ;restore other registers used in high int
        movff   FSR0H_HIGH,FSR0H
        movff   FSR1L_HIGH,FSR1L
        movff   FSR1H_HIGH,FSR1H
    return

;------------------------------------------------------------------------------
; Routine:          CAN INTERRUPT
;------------------------------------------------------------------------------
; Overview:         Checks CAN message for response and RTR and saves to FIFO
;------------------------------------------------------------------------------
CANInterrupt
        banksel CANFRAME2
        btfsc   CANFRAME2,0                 ;response message?
    return                                  ;yes, so ignore it and exit
        btfsc   CANFRAME2,1                 ;RTR (Remote Transmit Request)?
    return                                  ;yes, so ignore it and exit
        call    Copy_RXB_RXFIFOIN           ;copies received message to CAN RX FIFO input buffer
        call    WriteToCanRxFIFO            ;saves message to FIFO
    return

;------------------------------------------------------------------------------
; Routine:          TIMER 0 INTERRUPT
;------------------------------------------------------------------------------
; Overview:         1000ms periodical interrupt
;------------------------------------------------------------------------------
Timer0Interrupt:
        call    Timer0Initialization8MHz    ;restart 1000ms Timer   
        call    UpdateUpTime                ;counts time from restart
        call    UpdateTransmitTimer         ;increment transmit timer (seconds after last transmission)
        banksel TIMER0_1000ms
        setf    TIMER0_1000ms               ;timer 0 interrupt occurred flag
    return

;------------------------------------------------------------------------------
; Routine:          TIMER 2 INTERRUPT
;------------------------------------------------------------------------------
; Overview:         20ms periodical interrupt
;------------------------------------------------------------------------------
Timer2Interrupt
        rcall   Timer2Initialization8MHz    ;restart timer
        banksel TIMER2_20ms
        setf    TIMER2_20ms                 ;timer 2 interrupt occurred flag
    return
;-------------------------------
Timer2Initialization8MHz
        movlb   0xF
        bcf     PMD1,TMR2MD                 ;enable timer 2
        movlw   0x3F          
        movwf   TMR2                        ;set 20ms (19.999500)
        movlw   b'01001111'                 ;start timer, prescaler=16, postscaler=10
        movwf   T2CON
        bsf     IPR1,TMR2IP                 ;high priority for interrupt
        bcf     PIR1,TMR2IF                 ;clear timer's flag
        bsf     PIE1,TMR2IE                 ;interrupt on
    return

;==============================================================================
;===  MAIN PROGRAM  ===========================================================
;==============================================================================
Main:
    ;disable global interrupts for startup
        call    DisAllInt                   ;disable all interrupt
    ;firmware initialization
        rcall   PortInitialization          ;prepare processor ports
        call    GeneralInitialization       ;read eeprom config, clear other registers
        call    FIFOInitialization          ;prepare FIFO buffers
        call    OutputPowerUpStates         ;set output power up states
        call    Timer0Initialization8MHz    ;Timer 0 initialization for 1s periodical interrupt 
        call    Timer2Initialization8MHz    ;Timer 2 initialization for 20ms periodical interrupt
    ;firmware ready
        banksel FIRMREADY
        bsf     FIRMREADY,0                 ;set flag "firmware started and ready for interrupts"
    ;enable global interrupts
        call    EnAllInt                    ;enable all interrupts

;-------------------------------
Loop:                                       ;main loop
        clrwdt                              ;clear Watchdog timer
        call    ReceiveProcedure            ;check if any msg in RX FIFO and if so - process the msg
        call    TransmitProcedure           ;check if any msg in TX FIFO and if so - transmit it
        rcall   OnceA20ms                   ;do routines only after 20ms interrupt 
        rcall   OnceA1000ms                 ;do routines only after 1000ms interrupt
    bra     Loop

;-------------------------------
OnceA20ms                                   ;procedures executed once per 20ms (flag set in interrupt)
        banksel TIMER2_20ms
        tstfsz  TIMER2_20ms                 ;flag set?
        bra     $ + 4
    return                                  ;no, so exit
        call    SetOutputs                  ;set new output states when needed  
        banksel TIMER2_20ms
        clrf    TIMER2_20ms
    return
;-------------------------------
OnceA1000ms                                 ;procedures executed once per 1000ms (flag set in interrupt)
        banksel TIMER0_1000ms
        tstfsz  TIMER0_1000ms               ;flag set?
        bra     $ + 4
    return                                  ;no, so exit
        call    UpdateDelayTimers           ;updates channel timers 
        call    SaveSateToEeprom            ;save output states into eeprom memory when needed
        call    UpdateHealthRegs            ;saves health maximums to eeprom
        banksel TIMER0_1000ms
        clrf    TIMER0_1000ms
    return


;==============================================================================
;===  FIRMWARE ROUTINES  ======================================================
;==============================================================================
;------------------------------------------------------------------------------
; Routine:          PORT INITIALIZATION
;------------------------------------------------------------------------------
; Overview:         It sets processor pins. All unused pins should be set as
;                   outputs and driven low
;------------------------------------------------------------------------------
PortInitialization                          ;default all pins set as analog (portA,B) or digital (portB,C) inputs 
    ;PORT A
        banksel ANCON0                      ;select memory bank
        ;0-digital, 1-analog input
        movlw   b'00000011'                 ;(x,x,x,AN4,AN3,AN2,AN1-boot_mode,AN0-volt)
        movwf   ANCON0
        ;output level
        clrf    LATA                        ;all low
        ;0-output, 1-input
        movlw   b'00000011'                 ;all outputs except, bit<1>-boot_mode, bit<0>-volt
        movwf   TRISA        
    ;PORT B
        ;0-digital, 1-analog input
        movlw   b'00000000'                 ;(x,x,x,x,x,AN10,AN9,AN8)
        movwf   ANCON1
        ;output level
        clrf    LATB                        ;all low
        ;0-output, 1-input
        movlw   b'00001000'                 ;all output except CANRX
        movwf   TRISB
    ;PORT C
        ;output level
        clrf    LATC                        ;all low
        ;0-output, 1-input
        movlw   b'00000000'                 ;all output 
        movwf   TRISC
    return

;------------------------------------------------------------------------------
; Routine:          NODE STATUS
;------------------------------------------------------------------------------
; Overview:         It prepares status messages when status request was
;                   received
;------------------------------------------------------------------------------
NodeStatusRequest
        banksel TXFIFOIN0
        movlw   0x01                        ;this is K1
        movwf   TXFIFOIN6
        btfsc   OutputAStates,0             ;is output off?
        bra     $ + 6                       ;no, so set TXFIFOIN7
        clrf    TXFIFOIN7                   ;yes, so clear TXFIFOIN7
        bra     $ + 4
        setf    TXFIFOIN7
        movff   Instr1Ch1,TXFIFOIN9         ;info what instruction is waiting for execution
        movff   TimerCh1,TXFIFOIN11         ;value of channel timer
        rcall   SendOutputStatus
        ;------------------
        movlw   0x02                        ;this is K2
        movwf   TXFIFOIN6
        btfsc   OutputAStates,1             
        bra     $ + 6                   
        clrf    TXFIFOIN7
        bra     $ + 4
        setf    TXFIFOIN7
        movff   Instr1Ch2,TXFIFOIN9          
        movff   TimerCh2,TXFIFOIN11         
        rcall   SendOutputStatus
        ;------------------
        movlw   0x03                        ;this is K3
        movwf   TXFIFOIN6
        btfsc   OutputAStates,2         
        bra     $ + 6                  
        clrf    TXFIFOIN7               
        bra     $ + 4
        setf    TXFIFOIN7
        movff   Instr1Ch3,TXFIFOIN9                           
        movff   TimerCh3,TXFIFOIN11       
        rcall   SendOutputStatus
        ;------------------
        movlw   0x04                        ;this is K4
        movwf   TXFIFOIN6
        btfsc   OutputAStates,3              
        bra     $ + 6                    
        clrf    TXFIFOIN7                 
        bra     $ + 4
        setf    TXFIFOIN7
        movff   Instr1Ch4,TXFIFOIN9                         
        movff   TimerCh4,TXFIFOIN11       
        rcall   SendOutputStatus
        ;------------------
        movlw   0x05                        ;this is K5
        movwf   TXFIFOIN6
        btfsc   OutputAStates,4             
        bra     $ + 6                  
        clrf    TXFIFOIN7                
        bra     $ + 4
        setf    TXFIFOIN7
        movff   Instr1Ch5,TXFIFOIN9                           
        movff   TimerCh5,TXFIFOIN11        
        rcall   SendOutputStatus
        ;------------------
        movlw   0x06                        ;this is K6
        movwf   TXFIFOIN6
        btfsc   OutputAStates,5           
        bra     $ + 6                     
        clrf    TXFIFOIN7                 
        bra     $ + 4
        setf    TXFIFOIN7
        movff   Instr1Ch6,TXFIFOIN9                     
        movff   TimerCh6,TXFIFOIN11     
        rcall   SendOutputStatus
        ;------------------
        movlw   0x07                        ;this is K7
        movwf   TXFIFOIN6
        btfsc   OutputAStates,6           
        bra     $ + 6                     
        clrf    TXFIFOIN7                 
        bra     $ + 4
        setf    TXFIFOIN7
        movff   Instr1Ch7,TXFIFOIN9                     
        movff   TimerCh7,TXFIFOIN11     
        rcall   SendOutputStatus
        ;------------------
        movlw   0x08                        ;this is K8
        movwf   TXFIFOIN6
        btfsc   OutputAStates,7           
        bra     $ + 6                     
        clrf    TXFIFOIN7                 
        bra     $ + 4
        setf    TXFIFOIN7
        movff   Instr1Ch8,TXFIFOIN9                     
        movff   TimerCh8,TXFIFOIN11     
        rcall   SendOutputStatus
        ;------------------
        movlw   0x09                        ;this is K9
        movwf   TXFIFOIN6
        btfsc   OutputBStates,0           
        bra     $ + 6                     
        clrf    TXFIFOIN7                 
        bra     $ + 4
        setf    TXFIFOIN7
        movff   Instr1Ch9,TXFIFOIN9                     
        movff   TimerCh9,TXFIFOIN11     
        rcall   SendOutputStatus
        ;------------------
        movlw   0x0A                        ;this is K10
        movwf   TXFIFOIN6
        btfsc   OutputBStates,1           
        bra     $ + 6                     
        clrf    TXFIFOIN7                 
        bra     $ + 4
        setf    TXFIFOIN7
        movff   Instr1Ch10,TXFIFOIN9                     
        movff   TimerCh10,TXFIFOIN11     
        rcall   SendOutputStatus
    return

SendOutputStatus
        movlw   0x30                        ;set output frame
        movwf   TXFIFOIN0
        movlw   0x90
        movwf   TXFIFOIN1
        bsf     TXFIFOIN1,0                 ;response bit
        movff   NODENR,TXFIFOIN2            ;node id
        movff   GROUPNR,TXFIFOIN3
        setf    TXFIFOIN4                   ;unused
        setf    TXFIFOIN5                   ;unused
        setf    TXFIFOIN8                   ;unused
        setf    TXFIFOIN10                  ;unused
        call    WriteToCanTxFIFO
    return

;------------------------------------------------------------------------------
; Routine:          DO INSTRUCTION
;------------------------------------------------------------------------------
; Overview:         Executes instruction immediately or sets timer for later
;                   execution
;------------------------------------------------------------------------------
DoInstructionRequest
        banksel INSTR1

;Check if timer is needed
        movff   INSTR4,TIMER                ;timer is in INSTR4 for this firmware
        tstfsz  TIMER                       ;is timer = 0?
        bra     $ + 8                       ;no
        call    DoInstructionNow            ;yes
    return
        call    DoInstructionLater          ;save instruction for later execution
    return

;-------------------------------
;Recognize instruction
DoInstructionNow
        movlw   0x00                        ;instruction 00?
        xorwf   INSTR1,W
        bz      Instr00
        movlw   0x01                        ;instruction 01?
        xorwf   INSTR1,W
        bz      Instr01
        movlw   0x02                        ;instruction 02?
        xorwf   INSTR1,W
        bz      Instr02
    bra     ExitDoInstructionNow            ;exit if unknown instruction

;-------------------------------
;Instruction execution
Instr00                                     ;turn off
        movf    INSTR2,W                    ;get mask of channels 1-8 to change
        comf    WREG                        ;modify mask
        andwf   OutputAStatesNew,F
        movf    INSTR3,W                    ;get mask of channels 9-10 to change
        comf    WREG                        ;modify mask
        andwf   OutputBStatesNew,F
        bra     ExitDoInstructionNow 
Instr01                                     ;turn on
        movf    INSTR2,W                    ;get mask of channels 1-8 to change
        iorwf   OutputAStatesNew,F
        movf    INSTR3,W                    ;get mask of channels 9-10 to change
        iorwf   OutputBStatesNew,F
        bra     ExitDoInstructionNow 
Instr02                                     ;toggle
        movf    INSTR2,W                    ;get mask of channels 1-8 to change
        xorwf   OutputAStatesNew,F
        movf    INSTR3,W                    ;get mask of channels 9-10 to change
        xorwf   OutputBStatesNew,F
        bra     ExitDoInstructionNow 

ExitDoInstructionNow
        setf    INSTR1                      ;clear instruction
        clrf    TIMER                       ;clear timer
        call    DoInstructionLater          ;clear waiting instruction in channels that just been used in instruction
    return                        

;------------------------------------------------------------------------------
; Routine:          DO INSTRUCTION LATER
;------------------------------------------------------------------------------
; Overview:         It saves instruction for particular channel for later
;                   execution
;------------------------------------------------------------------------------
DoInstructionLater
        call    SetTimer                    ;update SUBTIMER1 & SUBTIMER2 registers
        ;identify channels
        banksel INSTR2
        btfsc   INSTR2,0                    ;channel 1
        call    SetChanel1
        btfsc   INSTR2,1                    ;channel 2
        call    SetChanel2
        btfsc   INSTR2,2                    ;channel 3
        call    SetChanel3
        btfsc   INSTR2,3                    ;channel 4
        call    SetChanel4
        btfsc   INSTR2,4                    ;channel 5
        call    SetChanel5
        btfsc   INSTR2,5                    ;channel 6
        call    SetChanel6
        btfsc   INSTR2,6                    ;channel 7
        call    SetChanel7
        btfsc   INSTR2,7                    ;channel 8
        call    SetChanel8
        btfsc   INSTR3,0                    ;channel 9
        call    SetChanel9
        btfsc   INSTR3,1                    ;channel 10
        call    SetChanel10
ExitDoInstructionLater
    return

;-------------------------------
SetChanel1
        movff   INSTR1,Instr1Ch1            ;copy registers
        movlw   b'00000001'
        movff   WREG,Instr2Ch1
        movlw   b'00000000'
        movff   WREG,Instr3Ch1
        movff   TIMER,TimerCh1
        movff   SUBTIMER1,SubTmr1Ch1
        movff   SUBTIMER2,SubTmr2Ch1
    return
SetChanel2
        movff   INSTR1,Instr1Ch2
        movlw   b'00000010'
        movff   WREG,Instr2Ch2
        movlw   b'00000000'
        movff   WREG,Instr3Ch2
        movff   TIMER,TimerCh2
        movff   SUBTIMER1,SubTmr1Ch2
        movff   SUBTIMER2,SubTmr2Ch2
    return
SetChanel3
        movff   INSTR1,Instr1Ch3
        movlw   b'00000100'
        movff   WREG,Instr2Ch3
        movlw   b'00000000'
        movff   WREG,Instr3Ch3
        movff   TIMER,TimerCh3
        movff   SUBTIMER1,SubTmr1Ch3
        movff   SUBTIMER2,SubTmr2Ch3
    return
SetChanel4
        movff   INSTR1,Instr1Ch4
        movlw   b'00001000'
        movff   WREG,Instr2Ch4
        movlw   b'00000000'
        movff   WREG,Instr3Ch4
        movff   TIMER,TimerCh4
        movff   SUBTIMER1,SubTmr1Ch4
        movff   SUBTIMER2,SubTmr2Ch4
    return
SetChanel5
        movff   INSTR1,Instr1Ch5
        movlw   b'00010000'
        movff   WREG,Instr2Ch5
        movlw   b'00000000'
        movff   WREG,Instr3Ch5
        movff   TIMER,TimerCh5
        movff   SUBTIMER1,SubTmr1Ch5
        movff   SUBTIMER2,SubTmr2Ch5
    return
SetChanel6
        movff   INSTR1,Instr1Ch6
        movlw   b'00100000'
        movff   WREG,Instr2Ch6
        movlw   b'00000000'
        movff   WREG,Instr3Ch6
        movff   TIMER,TimerCh6
        movff   SUBTIMER1,SubTmr1Ch6
        movff   SUBTIMER2,SubTmr2Ch6
    return
SetChanel7
        movff   INSTR1,Instr1Ch7
        movlw   b'01000000'
        movff   WREG,Instr2Ch7
        movlw   b'00000000'
        movff   WREG,Instr3Ch7
        movff   TIMER,TimerCh7
        movff   SUBTIMER1,SubTmr1Ch7
        movff   SUBTIMER2,SubTmr2Ch7
    return
SetChanel8
        movff   INSTR1,Instr1Ch8
        movlw   b'10000000'
        movff   WREG,Instr2Ch8
        movlw   b'00000000'
        movff   WREG,Instr3Ch8
        movff   TIMER,TimerCh8
        movff   SUBTIMER1,SubTmr1Ch8
        movff   SUBTIMER2,SubTmr2Ch8
    return
SetChanel9
        movff   INSTR1,Instr1Ch9
        movlw   b'00000000'
        movff   WREG,Instr2Ch9
        movlw   b'00000001'
        movff   WREG,Instr3Ch9
        movff   TIMER,TimerCh9
        movff   SUBTIMER1,SubTmr1Ch9
        movff   SUBTIMER2,SubTmr2Ch9
    return
SetChanel10
        movff   INSTR1,Instr1Ch10
        movlw   b'00000000'
        movff   WREG,Instr2Ch10
        movlw   b'00000010'
        movff   WREG,Instr3Ch10
        movff   TIMER,TimerCh10
        movff   SUBTIMER1,SubTmr1Ch10
        movff   SUBTIMER2,SubTmr2Ch10
    return

;------------------------------------------------------------------------------
; Routine:          OUTPUT POWER UP STATES
;------------------------------------------------------------------------------
; Overview:         Sets power up states according to configuration
;------------------------------------------------------------------------------
OutputPowerUpStates
        banksel E_OUTASOURCESTATE               ;if bit <x>='1' then power up state from "last saved"; if bit <x>='0 then power up states from "set power up values"
    ;channels 1-8
        movff   E_OUTASETSTATE,OutputAStatesNew ;take "set power up states" from CONFIG
        comf    E_OUTASOURCESTATE,W             ;take bits that will be taken from "last saved" - these bits are zeroes now in WREG 
        andwf   OutputAStatesNew,F,ACCESS       ;clear bits that will be taken from "last saved"
        movf    E_OUTASOURCESTATE,W             ;take bits that will be taken from "last saved" - these bits are ones now in WREG         
        andwf   E_OUTASAVEDSTATE,W              ;remove unwanted bits
        iorwf   OutputAStatesNew,F,ACCESS       ;take bits from last saved
 ;       comf    OutputAStatesNew,W                    
 ;       movwf   OutputAStates                   ;complement OutputStatesNew and move to OutputStates, to toggle all outputs at the beginning so their states can be known
clrf OutputAStates
    ;channels 9-10
        movff   E_OUTBSETSTATE,OutputBStatesNew
        comf    E_OUTBSOURCESTATE,W
        andwf   OutputBStatesNew,F,ACCESS
        movf    E_OUTBSOURCESTATE,W        
        andwf   E_OUTBSAVEDSTATE,W
        iorwf   OutputBStatesNew,F,ACCESS
;        comf    OutputBStatesNew,W                    
;        movwf   OutputBStates
clrf OutputBStates
    return

;------------------------------------------------------------------------------
; Routine:          SET OUTPUTS
;------------------------------------------------------------------------------
; Overview:         It sets monostable outputs according to OutputStatesNew reg.
;                   Only one output is set at a time.
;------------------------------------------------------------------------------
SetOutputs
        banksel OutputAStates
SetOutputsCh1
        movf    OutputAStatesNew,W          ;new state
        xorwf   OutputAStates,W             ;actual state
        btfss   WREG,0                      ;K1 changed?
        bra     SetOutputsCh2               ;no
        bcf     OutputAStates,0             ;output goes OFF
        btfsc   OutputAStatesNew,0          ;should go off?
        bsf     OutputAStates,0             ;no, so output goes ON
        call    OutputAStatesCh1            ;send new states
        rcall   EepromToSave                ;indicate that new state needs to be saved in eeprom
        bra     ExitSetOutputs              ;only one output turned a time
SetOutputsCh2
        movf    OutputAStatesNew,W          ;K2
        xorwf   OutputAStates,W
        btfss   WREG,1
        bra     SetOutputsCh3
        bcf     OutputAStates,1
        btfsc   OutputAStatesNew,1
        bsf     OutputAStates,1
        call    OutputAStatesCh2
        rcall   EepromToSave
        bra     ExitSetOutputs
SetOutputsCh3
        movf    OutputAStatesNew,W          ;K3
        xorwf   OutputAStates,W
        btfss   WREG,2
        bra     SetOutputsCh4
        bcf     OutputAStates,2
        btfsc   OutputAStatesNew,2
        bsf     OutputAStates,2
        call    OutputAStatesCh3
        rcall   EepromToSave
        bra     ExitSetOutputs
SetOutputsCh4
        movf    OutputAStatesNew,W          ;K4
        xorwf   OutputAStates,W
        btfss   WREG,3
        bra     SetOutputsCh5
        bcf     OutputAStates,3
        btfsc   OutputAStatesNew,3
        bsf     OutputAStates,3
        call    OutputAStatesCh4
        rcall   EepromToSave
        bra     ExitSetOutputs
SetOutputsCh5
        movf    OutputAStatesNew,W          ;K5
        xorwf   OutputAStates,W
        btfss   WREG,4
        bra     SetOutputsCh6
        bcf     OutputAStates,4
        btfsc   OutputAStatesNew,4
        bsf     OutputAStates,4
        call    OutputAStatesCh5
        rcall   EepromToSave
        bra     ExitSetOutputs
SetOutputsCh6
        movf    OutputAStatesNew,W          ;K6
        xorwf   OutputAStates,W
        btfss   WREG,5
        bra     SetOutputsCh7
        bcf     OutputAStates,5
        btfsc   OutputAStatesNew,5
        bsf     OutputAStates,5
        call    OutputAStatesCh6
        rcall   EepromToSave
        bra     ExitSetOutputs
SetOutputsCh7
        movf    OutputAStatesNew,W          ;K7
        xorwf   OutputAStates,W
        btfss   WREG,6
        bra     SetOutputsCh8
        bcf     OutputAStates,6
        btfsc   OutputAStatesNew,6
        bsf     OutputAStates,6
        call    OutputAStatesCh7
        rcall   EepromToSave
        bra     ExitSetOutputs
SetOutputsCh8
        movf    OutputAStatesNew,W          ;K8
        xorwf   OutputAStates,W
        btfss   WREG,7
        bra     SetOutputsCh9
        bcf     OutputAStates,7
        btfsc   OutputAStatesNew,7
        bsf     OutputAStates,7
        call    OutputAStatesCh8
        rcall   EepromToSave
        bra     ExitSetOutputs
SetOutputsCh9
        movf    OutputBStatesNew,W          ;K9
        xorwf   OutputBStates,W
        btfss   WREG,0
        bra     SetOutputsCh10
        bcf     OutputBStates,0
        btfsc   OutputBStatesNew,0
        bsf     OutputBStates,0
        call    OutputAStatesCh9
        rcall   EepromToSave
        bra     ExitSetOutputs
SetOutputsCh10
        movf    OutputBStatesNew,W          ;K10
        xorwf   OutputBStates,W
        btfss   WREG,1
        bra     ExitSetOutputs
        bcf     OutputBStates,1
        btfsc   OutputBStatesNew,1
        bsf     OutputBStates,1
        call    OutputAStatesCh10
        rcall   EepromToSave
        bra     ExitSetOutputs
ExitSetOutputs
        rcall   IOIC_SetOutputs             ;send state to expander via I2C
    return

;----------
IOIC_SetOutputs
        call    I2C_Recovery8MHz            ;make sure slave doesn't lock up i2c bus
        call    I2C_MasterInitialization8MHz    ;prepare i2c bus
    ;initialise expander
        call    I2C_WaitForIdle             ;wait till module is idle
        call    I2C_SendStart
        movlw   b'01000000'                 ;slave address + WRITE bit
        call    I2C_SendByte
        movlw   0x00                        ;address pointer (Port Direction Reg)   
        call    I2C_SendByte
        movlw   b'00000000'                 ;IODIRA, set portA as output
        call    I2C_SendByte
        movlw   b'00000000'                 ;IODIRB, set portB as output
        call    I2C_SendByte
        call    I2C_SendStop
    ;set outputs
        call    I2C_WaitForIdle             ;wait till module is idle
        call    I2C_SendStart
        movlw   b'01000000'                 ;slave address + WRITE bit
        call    I2C_SendByte
        movlw   0x14                        ;address pointer (LATA reg)   
        call    I2C_SendByte
        movf    OutputAStates,W             ;LATA, set portA
        call    I2C_SendByte
        movf    OutputBStates,W             ;LATB, set portB
        call    I2C_SendByte
        call    I2C_SendStop
    ;disable MSSP module
        banksel PMD0
        bsf     PMD0,SSPMD                  ;disable MSSP module
    return

;----------
EepromToSave                                ;indicate that save to eeprom nedded
        banksel EEPROMTIMER
        movlw   0x06                        ;wait 6s before saving to eeprom
        movwf   EEPROMTIMER
    return

;------------------------------------------------------------------------------
; Routine:          SEND OUTPUT STATES
;------------------------------------------------------------------------------
; Overview:         Sends output new state after executing instruction
;------------------------------------------------------------------------------
OutputAStatesCh1                            ;transmit state of K1
        banksel TXFIFOIN0
        movlw   0x01                        ;"K1"
        movwf   TXFIFOIN6
        clrf    TXFIFOIN7                   ;"0x00 - output is OFF"
        btfsc   OutputAStates,0             ;K1 off?
        setf    TXFIFOIN7                   ;no, "0xFF - output is ON"        
        movff   Instr1Ch1,TXFIFOIN9         ;INSTR1 - waiting instruction
        movff   TimerCh1,TXFIFOIN11         ;TIMER
        rcall   SendOutputState
    return
OutputAStatesCh2                            ;transmit state of K2
        banksel TXFIFOIN0
        movlw   0x02                    
        movwf   TXFIFOIN6
        clrf    TXFIFOIN7                
        btfsc   OutputAStates,1        
        setf    TXFIFOIN7                    
        movff   Instr1Ch2,TXFIFOIN9        
        movff   TimerCh2,TXFIFOIN11        
        rcall   SendOutputState
    return
OutputAStatesCh3                            ;transmit state of K3
        banksel TXFIFOIN0
        movlw   0x03                      
        movwf   TXFIFOIN6
        clrf    TXFIFOIN7                
        btfsc   OutputAStates,2            
        setf    TXFIFOIN7                        
        movff   Instr1Ch3,TXFIFOIN9        
        movff   TimerCh3,TXFIFOIN11        
        rcall   SendOutputState
    return
OutputAStatesCh4                            ;transmit state of K4
        banksel TXFIFOIN0
        movlw   0x04                    
        movwf   TXFIFOIN6
        clrf    TXFIFOIN7                
        btfsc   OutputAStates,3            
        setf    TXFIFOIN7                        
        movff   Instr1Ch4,TXFIFOIN9            
        movff   TimerCh4,TXFIFOIN11        
        rcall   SendOutputState
    return
OutputAStatesCh5                            ;transmit state of K5
        banksel TXFIFOIN0
        movlw   0x05                      
        movwf   TXFIFOIN6
        clrf    TXFIFOIN7                
        btfsc   OutputAStates,4            
        setf    TXFIFOIN7                        
        movff   Instr1Ch5,TXFIFOIN9        
        movff   TimerCh5,TXFIFOIN11       
        rcall   SendOutputState
    return
OutputAStatesCh6                            ;transmit state of K6
        banksel TXFIFOIN0
        movlw   0x06                      
        movwf   TXFIFOIN6
        clrf    TXFIFOIN7                
        btfsc   OutputAStates,5            
        setf    TXFIFOIN7                        
        movff   Instr1Ch6,TXFIFOIN9        
        movff   TimerCh6,TXFIFOIN11       
        rcall   SendOutputState
    return
OutputAStatesCh7                            ;transmit state of K7
        banksel TXFIFOIN0
        movlw   0x07                      
        movwf   TXFIFOIN6
        clrf    TXFIFOIN7                
        btfsc   OutputAStates,6            
        setf    TXFIFOIN7                        
        movff   Instr1Ch7,TXFIFOIN9        
        movff   TimerCh7,TXFIFOIN11       
        rcall   SendOutputState
    return
OutputAStatesCh8                            ;transmit state of K8
        banksel TXFIFOIN0
        movlw   0x08
        movwf   TXFIFOIN6
        clrf    TXFIFOIN7                
        btfsc   OutputAStates,7            
        setf    TXFIFOIN7                        
        movff   Instr1Ch8,TXFIFOIN9        
        movff   TimerCh8,TXFIFOIN11       
        rcall   SendOutputState
    return
OutputAStatesCh9                            ;transmit state of K9
        banksel TXFIFOIN0
        movlw   0x09
        movwf   TXFIFOIN6
        clrf    TXFIFOIN7                
        btfsc   OutputBStates,0            
        setf    TXFIFOIN7                        
        movff   Instr1Ch9,TXFIFOIN9        
        movff   TimerCh9,TXFIFOIN11       
        rcall   SendOutputState
    return
OutputAStatesCh10                            ;transmit state of K10
        banksel TXFIFOIN0
        movlw   0x0A
        movwf   TXFIFOIN6
        clrf    TXFIFOIN7                
        btfsc   OutputBStates,1            
        setf    TXFIFOIN7                        
        movff   Instr1Ch10,TXFIFOIN9        
        movff   TimerCh10,TXFIFOIN11       
        rcall   SendOutputState
    return

SendOutputState
        movlw   0x30                        ;set output frame
        movwf   TXFIFOIN0
        movlw   0x90
        movwf   TXFIFOIN1
        movff   NODENR,TXFIFOIN2            ;node id
        movff   GROUPNR,TXFIFOIN3
        setf    TXFIFOIN4                   ;unused
        setf    TXFIFOIN5                   ;unused
        setf    TXFIFOIN8                   ;unused
        setf    TXFIFOIN10                  ;unused
        call    WriteToCanTxFIFO
    ;node can respond to its own message
        bcf     INTCON,GIEL                 ;disable low priority intr to make sure RXFIFO buffer is not overwritten
        call    Copy_TXFIFOIN_RXFIFOIN
        call    WriteToCanRxFIFO
        bsf     INTCON,GIEL                 ;enable back interrupt
    return

;------------------------------------------------------------------------------
; Routine:          SAVE STATES TO EEPROM
;------------------------------------------------------------------------------
; Overview:         It saves current output states into EEPROM memory
;------------------------------------------------------------------------------
SaveSateToEeprom            
        banksel EEPROMTIMER
    ;wait 6s before saving
        tstfsz  EEPROMTIMER
        decfsz  EEPROMTIMER
        bra     ExitSaveSateToEeprom
    ;save to eeprom
        banksel E_OUTASAVEDSTATE 
        clrf    EEADRH                      ;point at high address
        ;channels 1-8
        movf    E_OUTASAVEDSTATE,W          ;values the same?
        xorwf   OutputAStates,W
        bz      $ + .16                     ;yes, so don't save
        movff   OutputAStates,E_OUTASAVEDSTATE ;update E_OUTASAVEDSTATE register
        movlw   low E_OUTASAVEDSTATE        ;point at low address    
        movwf   EEADR
        movf    OutputAStates,W             ;set data for EepromSaveWREG routine
        call    EepromSaveWREG
        ;channels 9-10
        movf    E_OUTBSAVEDSTATE,W          ;values the same?
        xorwf   OutputBStates,W
        bz      $ + .16                     ;yes, so don't save
        movff   OutputBStates,E_OUTBSAVEDSTATE ;update E_OUTBSAVEDSTATE register
        movlw   low E_OUTBSAVEDSTATE        ;point at low address    
        movwf   EEADR
        movf    OutputBStates,W             ;set data for EepromSaveWREG routine
        call    EepromSaveWREG
ExitSaveSateToEeprom
    return

;==============================================================================
;===  END  OF  PROGRAM  =======================================================
;==============================================================================
    END