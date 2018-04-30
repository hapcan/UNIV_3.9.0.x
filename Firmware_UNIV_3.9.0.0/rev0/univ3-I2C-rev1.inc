    LIST
;==============================================================================
;   HAPCAN - Home Automation Project Firmware (http://hapcan.com)
;   Copyright (C) 2013 hapcan.com
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
;   Filename:           univ3_I2C-revX.inc
;   Associated diagram: none
;   Author:             Jacek Siwilo   
;   Description         UNIV 3 CPU I2C bus routines
;==============================================================================                   
;   Revision History
;   Rev:  Date:     Details:
;   0     11.2013   Original version
;   1     12.2017   Routines for 8MHz and 32MHz clock
;==============================================================================


;------------------------------------------------------------------------------
; Routine:          I2C MASTER INITIALIZATION
;------------------------------------------------------------------------------
; Overview:         Inits I2C with 100kHz clock for 8MHz or 32MHz
;    Input:         none
;   Output:         none
;------------------------------------------------------------------------------
I2C_MasterInitialization32MHz
        banksel PMD0
        bcf     PMD0,SSPMD                  ;enable MSSP module
        bsf     TRISC,3                     ;SCL pin as input
        bsf     TRISC,4                     ;SDA pin as input
        movlw   .79                         ;100kHz clock
        movwf   SSPADD
        movlw   b'10000000'                 ;disable SLEW control
        movwf   SSPSTAT
        movlw   b'00101000'                 ;enable master i2c
        movwf   SSPCON1
    return

I2C_MasterInitialization8MHz
        banksel PMD0
        bcf     PMD0,SSPMD                  ;enable MSSP module
        bsf     TRISC,3                     ;SCL pin as input
        bsf     TRISC,4                     ;SDA pin as input
        movlw   .19                         ;100kHz clock
        movwf   SSPADD
        movlw   b'10000000'                 ;disable SLEW control
        movwf   SSPSTAT
        movlw   b'00101000'                 ;enable master i2c
        movwf   SSPCON1
    return

;------------------------------------------------------------------------------
; Routine:          I2C RECOVERY
;------------------------------------------------------------------------------
; Overview:         Performs I2C recovery procedure. Needed when i2c is locked 
;                   up by the slave device. I2C MSSP module initialization must
;                   be used after that. It clocks at 100kHz frequency with
;                   32MHz or 8MHz crystal.
;    Input:         none
;   Output:         none
;------------------------------------------------------------------------------
I2C_Recovery32MHz
    ;disable I2C module
        banksel SSPCON1
        bcf     SSPCON1,SSPEN               ;enable SDA and SCL as I/O pins
    ;idle
        bsf     TRISC,3                     ;SCL high
        bsf     TRISC,4                     ;SDA high
        bcf     LATC,3                      ;SCL pin latch low
        bcf     LATC,4                      ;SDA pin latch low
    ;start
        rcall   I2C_5us
        bcf     TRISC,4                     ;SDA low
    ;9 bits
        rcall   I2C_5us
        bcf     TRISC,3                     ;SCL low
        rcall   I2C_5us
        bsf     TRISC,4                     ;SDA high
        movlw   .9
        rcall   I2C_5us                     ;(1bit)
        bsf     TRISC,3                     ;SCL high
        rcall   I2C_5us
        bcf     TRISC,3                     ;SCL low
        decfsz  WREG                        ;9 bits sent?
        bra     $ - .10                     ;not yet
    ;restart
        rcall   I2C_5us
        bsf     TRISC,3                     ;SCL high
        rcall   I2C_5us
        bcf     TRISC,4                     ;SDA low
    ;stop
        rcall   I2C_5us
        bsf     TRISC,4                     ;SDA high
    return
;-------------
I2C_5us
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
    return
;-------------

I2C_Recovery8MHz
    ;disable I2C module
        banksel SSPCON1
        bcf     SSPCON1,SSPEN               ;enable SDA and SCL as I/O pins
    ;idle
        bsf     TRISC,3                     ;SCL high
        bsf     TRISC,4                     ;SDA high
        bcf     LATC,3                      ;SCL pin latch low
        bcf     LATC,4                      ;SDA pin latch low
    ;start
        rcall   I2C_5us_8MHz
        bcf     TRISC,4                     ;SDA low
    ;9 bits
        rcall   I2C_5us_8MHz
        bcf     TRISC,3                     ;SCL low
        rcall   I2C_5us_8MHz
        bsf     TRISC,4                     ;SDA high
        movlw   .9
        rcall   I2C_5us_8MHz                ;(1bit)
        bsf     TRISC,3                     ;SCL high
        rcall   I2C_5us_8MHz
        bcf     TRISC,3                     ;SCL low
        decfsz  WREG                        ;9 bits sent?
        bra     $ - .10                     ;not yet
    ;restart
        rcall   I2C_5us_8MHz
        bsf     TRISC,3                     ;SCL high
        rcall   I2C_5us_8MHz
        bcf     TRISC,4                     ;SDA low
    ;stop
        rcall   I2C_5us_8MHz
        bsf     TRISC,4                     ;SDA high
    return
;-------------
I2C_5us_8MHz
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
    return

;==============================================================================
;==============================================================================
;       I 2 C   M A S T E R   T R A N S M I T   M O D E                        
;==============================================================================
;==============================================================================

;------------------------------------------------------------------------------
; Routine:          I2C WAIT FOR IDLE
;------------------------------------------------------------------------------
; Overview:         Makes sure the MSSP module is no busy, or waits if it is
;    Input:         none
;   Output:         none
;------------------------------------------------------------------------------
I2C_WaitForIdle
        btfsc   SSPSTAT,R_W                 ;test if transmit is in progress
        bra     $ - 2                       ;module busy, so wait
        movf    SSPCON2,W                   ;get copy of SSPCON2 for status bits
        andlw   0x1F                        ;mask out non-status bits
        btfss   STATUS,Z                    ;test for zero state, if Z set, bus is idle
        bra     $ - 6                       ;bus is busy so test bits again
    return

;------------------------------------------------------------------------------
; Routine:          I2C SEND START
;------------------------------------------------------------------------------
; Overview:         Sends start condition and waits for end
;    Input:         none
;   Output:         START bit on I2C
;------------------------------------------------------------------------------
I2C_SendStart     
        bsf     SSPCON2,SEN                 ;send start bit
        btfsc   SSPCON2,SEN                 ;has start been sent?
        bra     $ - 2                       ;no
    return

;------------------------------------------------------------------------------
; Routine:          I2C SEND REPEATED START
;------------------------------------------------------------------------------
; Overview:         Sends repeated start condition and waits for end
;    Input:         none
;   Output:         RESTART bit on I2C
;------------------------------------------------------------------------------
I2C_SendReStart     
        bsf     SSPCON2,RSEN                ;send repeated start bit
        btfsc   SSPCON2,RSEN                ;has repeated start been sent?
        bra     $ - 2                       ;no
    return

;------------------------------------------------------------------------------
; Routine:          I2C SEND STOP
;------------------------------------------------------------------------------
; Overview:         Sends stop condition and waits for end
;    Input:         none
;   Output:         STOP bit on I2C
;------------------------------------------------------------------------------
I2C_SendStop     
        bsf     SSPCON2,PEN                 ;send start bit
        btfsc   SSPCON2,PEN                 ;has stop been sent?
        bra     $ - 2                       ;no
    return

;------------------------------------------------------------------------------
; Routine:          I2C SEND BYTE AND WAIT FOR ACK
;------------------------------------------------------------------------------
; Overview:         Sends WREG byte and waits for ACK from slave device
;    Input:         WREG register to be transmitted
;   Output:         WREG = 0 if ACK was received from slave
;                   WREG = 1 if ACK wasn't received from slave
;------------------------------------------------------------------------------
I2C_SendByte     
        bcf     PIR1,SSPIF                  ;clear interrupt flag
        movwf   SSPBUF                      ;move date to buffer
        btfsc   SSPSTAT,BF                  ;has bufer shiffed?
        bra     $ - 2                       ;no
        btfss   PIR1,SSPIF                  ;ninth bit received?
        bra     $ - 2                       ;no
        btfsc   SSPCON2,ACKSTAT             ;ACK received?
    retlw   0x01                            ;no, so exit with error
    retlw   0x00                            ;yes



;==============================================================================
;==============================================================================
;       I 2 C   M A S T E R   R E C E I V E   M O D E                        
;==============================================================================
;==============================================================================

;------------------------------------------------------------------------------
; Routine:          I2C RECEIVE BYTE AND SEND ACK
;------------------------------------------------------------------------------
; Overview:         Receives byte, saves into WREG and sends ACK
;    Input:         none
;   Output:         WREG with received byte
;------------------------------------------------------------------------------
I2C_ReceiveByte_andACK  
        ;receive byte
        bsf     SSPCON2,RCEN                ;enable receive mode
        btfsc   SSPCON2,RCEN                ;8 bits read?
        bra     $ - 2                       ;not yet 
        movf    SSPBUF,W                    ;move buffer to WREG
        ;send ACK
        bcf     SSPCON2,ACKDT               ;ACK (acknowledge) bit
        bsf     SSPCON2,ACKEN               ;send sequence
        btfsc   SSPCON2,ACKEN               ;has ACKDT bit been sent yet?
        bra     $ - 2                       ;no
    return

;------------------------------------------------------------------------------
; Routine:          I2C RECEIVE BYTE AND SEND STOP
;------------------------------------------------------------------------------
; Overview:         Receives byte, saves into WREG and sends STOP
;    Input:         none
;   Output:         WREG with received byte
;------------------------------------------------------------------------------
I2C_ReceiveByte_andStop     
        ;receive byte
        bsf     SSPCON2,RCEN                ;enable receive mode
        btfsc   SSPCON2,RCEN                ;8 bits read?
        bra     $ - 2                       ;not yet 
        movf    SSPBUF,W                    ;move buffer to WREG
        ;send NACK
        bsf     SSPCON2,ACKDT               ;NACK (not acknowledge) bit
        bsf     SSPCON2,ACKEN               ;send sequence
        btfsc   SSPCON2,ACKEN               ;has ACKDT bit been sent yet?
        bra     $ - 2                       ;no
        ;send stop bit
        rcall   I2C_SendStop
    return

;------------------------------------------------------------------------------
